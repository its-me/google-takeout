# google-takeout

Bash scripts for backing up Google Takeout archives to Backblaze B2 and Google Drive.

## Scripts

| Script | Purpose |
|---|---|
| `takeout` | Full backup/restore pipeline |
| `takeout-merge` | Merge multiple Takeout archives into one compressed `.tar.xz` |
| `takeout-upload` | Upload an encrypted archive to both remotes and verify checksums |
| `takeout-retention` | Enforce retention policy on remote storage |

## How it works

**Backup** (`takeout b`):
1. Merges all `takeout-*.zip/tgz/tar.gz` files in the current directory into a single `.tar.xz`
2. Encrypts it with [age](https://age-encryption.org/) (key fetched from 1Password)
3. Uploads to Backblaze B2 and Google Drive in parallel
4. Verifies SHA-1 checksums on both remotes
5. Applies retention policy

**Restore** (`takeout r <file>`):
1. Decrypts the `.age` file
2. Extracts the archive

**Retention policy** (`takeout-retention`): keeps a backup if it is among the 10 most recent _or_ its date falls on the 1st or 16th of any month. Everything else is deleted.

## Dependencies

- `bash`, `xz`, `rsync`, `unzip`, `tar` — merge
- `rage` — age encryption
- `rclone` — cloud upload
- `sha1sum` — checksum verification
- `atool` — restore extraction
- `op` (1Password CLI) — age key retrieval

## Environment variables

| Variable | Used by | Description |
|---|---|---|
| `TAKEOUT_AGE_KEY` | `takeout` | Age key file name (or 1Password document name) |
| `ONEPASSWORD_SERVICE_ACCOUNT_TOKEN` | `takeout` | 1Password service account token |
| `TAKEOUT_RCLONE_B2_REMOTE_NAME` | `takeout`, `takeout-upload`, `takeout-retention` | rclone remote name for Backblaze B2 |
| `TAKEOUT_RCLONE_B2_REMOTE_BUCKET` | `takeout`, `takeout-upload`, `takeout-retention` | B2 bucket name |
| `TAKEOUT_RCLONE_DRIVE_REMOTE_NAME` | `takeout`, `takeout-upload`, `takeout-retention` | rclone remote name for Google Drive |
| `TAKEOUT_RCLONE_DRIVE_REMOTE_DIR` | `takeout`, `takeout-upload`, `takeout-retention` | Directory on Google Drive |
| `TAKEOUT_RETENTION_KEEP_LAST` | `takeout-retention` | Number of most recent backups to keep (default: 10) |

## Usage

### takeout

```bash
# Backup
takeout b

# Restore
takeout r <file.tar.xz.age>
```

### takeout-merge

Run in the directory containing your Takeout archives:

```bash
takeout-merge [output_name]
```

Produces `<output_name>-<YYYY-MM-DD>.tar.xz` (default output name: `Takeout`).

### takeout-upload

```bash
takeout-upload <file.tar.xz.age>
```

### takeout-retention

```bash
takeout-retention [--dry-run|-n] [b2|drive]
```

Omit the remote argument to run on both. Only the env vars for the selected remote are required.

## License

MIT
