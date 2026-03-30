# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Overview

This repository contains a single Bash script (`takeout-merge`) that merges multiple Google Takeout archives into a single compressed `.tar.xz` file.

## Usage

```bash
# Run in the directory containing Google Takeout archives
./takeout-merge [output_name]
# Default output name is "Takeout" if not specified
```

Supported archive formats: `takeout-*.zip`, `takeout-*.tgz`, `takeout-*.tar.gz`

Output: `<output_name>-<YYYY-MM-DD>.tar.xz` in the current directory

## Dependencies

- `bash`
- `xz` (for compression — install via `sudo apt install xz-utils` on Debian/Ubuntu)
- `rsync` (for merging extracted content)
- `unzip` (for `.zip` archives)
- `tar` (for `.tgz`/`.tar.gz` archives)

## Script Behavior

1. Finds all matching archives in the current directory (sorted)
2. Extracts the date from the first archive's filename (format: `takeout-YYYYMMDD-*`)
3. Extracts each archive into a temp dir (`./tmp`), then rsyncs into `./Takeout/`
4. Creates a `.tar.xz` with maximum compression (`xz -9e -T0`) at lowest process priority (`nice -n 19`)
5. Leaves the merged `./Takeout/` directory in place after completion; cleans up only the temp extraction dir
