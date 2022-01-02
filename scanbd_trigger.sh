#!/usr/bin/env bash

set -euxo pipefail

# The directory this script lives in
SCRIPT_DIR="$(dirname $(readlink -f ${BASH_SOURCE[0]:-${(%):-%x}}))"

# Paperless-ng's consume dir
PAPERLESS_CONSUME_DIR="$SCRIPT_DIR/consume"

# Virtualenv dir for preprocessing script dependencies
VENV_DIR="$SCRIPT_DIR/_venv"

# Scan mode. For s1300i this can be "Lineart" "Gray" or "Color"
SCAN_MODE="Gray"

# Scan format. Can be pnm, tiff, png or jpeg.
SCAN_FORMAT="pnm"

# File format for batch scans
SCAN_BATCH_FILE_FORMAT="raw/scan_${SCAN_MODE}_%03d.${SCAN_FORMAT}"

# Create a temporary working directory
WORK_DIR="$(mktemp -d)"

# Create subdirectories
mkdir $WORK_DIR/raw $WORK_DIR/preprocessed $WORK_DIR/unpapered

cleanup() {
  rm -rf $WORK_DIR
}

# Cleanup regardless of when or how script exits
trap cleanup EXIT

# Scan images in batch mode, which works with the scanners automatic document
# feed to scan a stack of documents. SCANBD_DEVICE is set by scanbd
scanimage --device-name=$SCANBD_DEVICE \
  --source='ADF Duplex' \
  --mode=$SCAN_MODE \
  --batch="$WORK_DIR/$SCAN_BATCH_FILE_FORMAT" \
  --format=$SCAN_FORMAT

# Preprocess images with opencv script
. $VENV_DIR/bin/activate
