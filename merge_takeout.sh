#!/bin/bash

# Script to merge Google Takeout archives and create a single compressed archive
# Usage: Run this script in the folder containing your Google Takeout archives
#        ./merge_takeout.sh [output_name]

set -e  # Exit on error
set -o pipefail  # Exit on pipe failures

# Color codes for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Function to print colored messages
print_info() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Check if xz is installed
if ! command -v xz &> /dev/null; then
    print_error "xz is not installed. Please install it first."
    echo "Install with: sudo apt install xz-utils  # Debian/Ubuntu"
    exit 1
fi

OUTPUT_BASE="${1:-Takeout}"

WORK_DIR="./tmp"
EXTRACT_DIR="$WORK_DIR/extract"
MERGED_DIR="$WORK_DIR/merged"

# Create working directory in current folder
print_info "Creating working directory: $WORK_DIR"
mkdir -p "$MERGED_DIR"

# Find all takeout archives in current directory
print_info "Searching for Google Takeout archives in current directory"
ARCHIVES=($(find . -maxdepth 1 -type f \( -name "takeout-*.zip" -o -name "takeout-*.tgz" -o -name "takeout-*.tar.gz" \) | sort))
if [ ${#ARCHIVES[@]} -eq 0 ]; then
    print_error "No Google Takeout archives found in current directory"
    print_warning "Looking for files matching: takeout-*.zip, takeout-*.tgz, takeout-*.tar.gz"
    exit 1
fi

print_info "Found ${#ARCHIVES[@]} archive(s)"

# Extract date from first archive filename
# Expected format: takeout-20240115-123456.zip or similar
FIRST_ARCHIVE=$(basename "${ARCHIVES[0]}")
print_info "Extracting date from: $FIRST_ARCHIVE"

# Try to extract date in format YYYYMMDD or YYYY-MM-DD and convert to YYYY-MM-DD
if [[ "$FIRST_ARCHIVE" =~ takeout-([0-9]{4})([0-9]{2})([0-9]{2}) ]]; then
    TAKEOUT_DATE="${BASH_REMATCH[1]}-${BASH_REMATCH[2]}-${BASH_REMATCH[3]}"
elif [[ "$FIRST_ARCHIVE" =~ takeout-([0-9]{4}-[0-9]{2}-[0-9]{2}) ]]; then
    TAKEOUT_DATE="${BASH_REMATCH[1]}"
else
    print_warning "Could not extract date from filename, using current date"
    TAKEOUT_DATE=$(date +%Y-%m-%d)
fi

OUTPUT_NAME="${OUTPUT_BASE}-${TAKEOUT_DATE}"
print_info "Output name will be: $OUTPUT_NAME"

# Extract each archive
for archive in "${ARCHIVES[@]}"; do
    print_info "Extracting: $(basename "$archive")"

    # Create temp extraction directory
    mkdir -p "$EXTRACT_DIR"

    # Determine archive type and extract
    case "$archive" in
        *.zip)
            unzip -q -o "$archive" -d "$EXTRACT_DIR" || {
                print_error "Failed to extract $archive"
                exit 1
            }
            ;;
        *.tgz|*.tar.gz)
            tar -xzf "$archive" -C "$EXTRACT_DIR" || {
                print_error "Failed to extract $archive"
                exit 1
            }
            ;;
    esac
    
    # Move extracted content to merged directory
    # Google Takeout typically extracts to a "Takeout" folder
    if [ -d "$EXTRACT_DIR/Takeout" ]; then
        print_info "Merging content from Takeout folder"
        rsync -a "$EXTRACT_DIR/Takeout/" "$MERGED_DIR/"
    else
        print_info "Merging content (no Takeout subfolder found)"
        rsync -a "$EXTRACT_DIR/" "$MERGED_DIR/"
    fi
    
    # Clean up temp extraction
    rm -rf "$EXTRACT_DIR"
done

# Count merged files
FILE_COUNT=$(find "$MERGED_DIR" -type f | wc -l)
print_info "Merged $FILE_COUNT files into $MERGED_DIR"

# Create tar.xz archive with maximum compression
ARCHIVE_PATH="$PWD/${OUTPUT_NAME}.tar.xz"
print_info "Creating xz-compressed archive: $ARCHIVE_PATH"
print_info "Using xz compression: -9e (extreme) -T0 (all CPU cores)"
XZ_OPT="-9e -T0" tar -cJf "$ARCHIVE_PATH" -C "$MERGED_DIR" . || {
    print_error "Failed to create archive"
    exit 1
}

ARCHIVE_SIZE=$(du -h "$ARCHIVE_PATH" | cut -f1)
print_info "Archive created successfully (size: $ARCHIVE_SIZE)"

# Clean up working directory
print_info "Cleaning up temporary files"
rm -rf "$WORK_DIR"

# Final summary
echo ""
print_info "=== COMPLETION SUMMARY ==="
print_info "Merged archives: ${#ARCHIVES[@]}"
print_info "Total files: $FILE_COUNT"
print_info "Takeout date: $TAKEOUT_DATE"
print_info "Output file: $ARCHIVE_PATH"
echo ""
print_info "To extract:"
print_info "  tar -xJf $ARCHIVE_PATH"
