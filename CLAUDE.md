# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Overview

This repository contains four Bash scripts for managing Google Takeout archives:

- **`takeout`** — full backup/restore pipeline: merge, encrypt (age), upload via rclone union remote, verify checksums on each upstream, apply retention
- **`takeout-merge`** — merges multiple Google Takeout archives into a single compressed `.tar.xz` file
- **`takeout-upload`** — uploads an encrypted archive to an rclone remote and verifies the SHA-1 checksum
- **`takeout-retention`** — enforces retention policy on the rclone remote: keeps the 10 most recent backups plus any backup created on the 1st or 16th of any month

## Usage

### takeout

```bash
# Backup: merge → encrypt → upload via union remote → verify checksums on each upstream → retention
./takeout b

# Restore: decrypt → extract
./takeout r <encrypted_file.tar.xz.age>
```

### takeout-merge

```bash
# Run in the directory containing Google Takeout archives
./takeout-merge [output_name]
# Default output name is "Takeout" if not specified
```

Supported archive formats: `takeout-*.zip`, `takeout-*.tgz`, `takeout-*.tar.gz`

Output: `<output_name>-<YYYY-MM-DD>.tar.xz` in the current directory

### takeout-upload

```bash
takeout-upload <encrypted_file.tar.xz.age>
```

### takeout-retention

```bash
takeout-retention [--dry-run|-n]
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
- `rclone` (upload via union remote)
- `sha1sum` (checksum verification)
- `atool` (for restore extraction)
- 1Password CLI (`op`) — used by `rage` wrapper to fetch the age key

### takeout-upload
- `rclone`
- `sha1sum`

### takeout-retention
- `rclone`

## Environment Variables

| Variable | Used by | Description |
|---|---|---|
| `TAKEOUT_AGE_KEY` | `takeout` | Name of the age key file (or 1Password document name) |
| `TAKEOUT_RETENTION_KEEP_LAST` | `takeout-retention` | Number of most recent backups to always keep (default: 10) |
| `TAKEOUT_RCLONE_UNION_REMOTE_NAME` | `takeout-upload`, `takeout-retention` | rclone union remote name; upstreams encode their own paths |
| `ONEPASSWORD_SERVICE_ACCOUNT_TOKEN` | `takeout` | 1Password service account token (passed to `rage`) |

## Script Behavior

### takeout b
1. Runs `takeout-merge` to produce a `.tar.xz` archive
2. Encrypts the archive with `rage` using the age key (fetched from 1Password if not local)
3. Calls `takeout-upload` to upload and verify
4. Runs `takeout-retention` to apply retention policy

### takeout r
1. Decrypts the `.age` file with `rage`
2. Extracts the resulting archive with `atool`

### takeout-merge
1. Finds all matching archives in the current directory (sorted)
2. Extracts the date from the first archive's filename (format: `takeout-YYYYMMDD-*`)
3. Extracts each archive into a temp dir (`./tmp`), then rsyncs into `./<output_name>-<YYYY-MM-DD>/`
4. Creates a `.tar.xz` with maximum compression (`xz -9e -T0`) at lowest process priority (`nice -n 19`)
5. Leaves the merged `./<output_name>-<YYYY-MM-DD>/` directory in place after completion; cleans up only the temp extraction dir

### takeout-upload
1. Computes local SHA-1 of the encrypted file
2. Uploads via rclone to `$TAKEOUT_RCLONE_UNION_REMOTE_NAME:` (the union remote fans out to all configured upstreams)
3. Reads the union's upstreams from `rclone config show` and verifies the SHA-1 checksum against each upstream individually

### takeout-retention
1. Lists all `*.tar.xz.age` files on the remote, sorted newest-first by filename date
2. Keeps a file if it meets either rule:
   - It is among the 10 most recent backups (1st/16th files count toward the 10)
   - Its filename date falls on the 1st or 16th of any month
3. Deletes everything else; `--dry-run` prints what would be deleted without acting
