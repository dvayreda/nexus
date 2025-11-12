#!/bin/bash
# dd_full_image.sh - Creates a full system image of the primary disk.

# Define the source disk (assuming /dev/sda is the system disk)
SOURCE_DISK="/dev/sda"

# Define the output directory on the backup drive
OUTPUT_DIR="/mnt/backup/images"

# Ensure the output directory exists
mkdir -p "$OUTPUT_DIR"

# Define the output file path
OUT_FILE="$OUTPUT_DIR/nexus-$(date +%F).img.gz"

# Create the full disk image using dd and compress it with gzip
# Use bs=4M for better performance, conv=sync,noerror to handle read errors gracefully
sudo dd if="$SOURCE_DISK" bs=4M conv=sync,noerror status=progress | gzip > "$OUT_FILE"

