# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Overview

This repository contains two Bash scripts for managing Google Takeout archives:

- **`takeout-merge`** — merges multiple Google Takeout archives into a single compressed `.tar.xz` file
- **`takeout`** — full backup/restore pipeline: merge, encrypt (age), upload to Backblaze B2 and Google Drive, verify checksums

## Usage

### takeout-merge

```bash
# Run in the directory containing Google Takeout archives
./takeout-merge [output_name]
# Default output name is "Takeout" if not specified
```

Supported archive formats: `takeout-*.zip`, `takeout-*.tgz`, `takeout-*.tar.gz`

Output: `<output_name>-<YYYY-MM-DD>.tar.xz` in the current directory

### takeout

```bash
# Backup: merge → encrypt → upload to B2 + Google Drive → verify checksums
./takeout b

# Restore: decrypt → extract
./takeout r <encrypted_file.tar.xz.age>
```

## Dependencies

### takeout-merge
- `bash`
- `xz` (for compression — install via `sudo apt install xz-utils` on Debian/Ubuntu)
- `rsync` (for merging extracted content)
- `unzip` (for `.zip` archives)
- `tar` (for `.tgz`/`.tar.gz` archives)

### takeout
All of the above, plus:
- `rage` (age encryption CLI)
- `rclone` (Google Drive upload)
- Backblaze B2 CLI (path set via `TAKEOUT_B2_CLIENT`)
- `jq` (JSON parsing for B2 response)
- `sha1sum` (checksum verification)
- `atool` (for restore extraction)
- 1Password CLI (`op`) — used by `rage` wrapper to fetch the age key

## Environment Variables (takeout b)

| Variable | Description |
|---|---|
| `TAKEOUT_AGE_KEY` | Name of the age key file (or 1Password document name) |
| `TAKEOUT_B2_CLIENT` | Path/command for the Backblaze B2 CLI |
| `TAKEOUT_B2_BUCKET` | B2 bucket name |
| `TAKEOUT_RCLONE_REMOTE_NAME` | rclone remote name for Google Drive |
| `TAKEOUT_RCLONE_REMOTE_DIR` | Directory on the remote to upload to |
| `ONEPASSWORD_SERVICE_ACCOUNT_TOKEN` | 1Password service account token (passed to `rage`) |

## Script Behavior

### takeout-merge
1. Finds all matching archives in the current directory (sorted)
2. Extracts the date from the first archive's filename (format: `takeout-YYYYMMDD-*`)
3. Extracts each archive into a temp dir (`./tmp`), then rsyncs into `./Takeout/`
4. Creates a `.tar.xz` with maximum compression (`xz -9e -T0`) at lowest process priority (`nice -n 19`)
5. Leaves the merged `./Takeout/` directory in place after completion; cleans up only the temp extraction dir

### takeout b
1. Runs `takeout-merge` to produce a `.tar.xz` archive
2. Encrypts the archive with `rage` using the age key (fetched from 1Password if not local)
3. Computes local SHA-1 of the encrypted file
4. Uploads to Backblaze B2 (sequential) and Google Drive via rclone (background)
5. Verifies SHA-1 checksums match on both remotes before reporting success

### takeout r
1. Decrypts the `.age` file with `rage`
2. Extracts the resulting archive with `atool`
