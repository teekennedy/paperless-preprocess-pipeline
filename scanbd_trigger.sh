#!/usr/bin/env bash

set -euxo pipefail

echo "Action: $SCANBD_ACTION"

# The directory this script lives in
SCRIPT_DIR="$(dirname $(readlink -f ${BASH_SOURCE[0]:-${(%):-%x}}))"

# Paperless-ng's consume dir
PAPERLESS_CONSUME_DIR="$SCRIPT_DIR/consume"

# Output filename without extension
OUTPUT_BASENAME="$(date +%F_%T)"

# Scan preprocessor script path
PREPROCESSOR_SCRIPT="$SCRIPT_DIR/preprocess_scan.py"

# Virtualenv dir for preprocessing script dependencies
VENV_DIR="$SCRIPT_DIR/_venv"

# Scan mode. For s1300i this can be "Lineart" "Gray" or "Color"
SCAN_MODE="Gray"

# Scan format. Can be pnm, tiff, png or jpeg.
SCAN_FORMAT="pnm"

# Scan resolution in DPI
SCAN_RESOLUTION=300

# Base format string for files generated in this batch
BASE_FILE_FORMAT_STR="scan_${SCAN_MODE}_%03d"

# File format string for batch scans
SCAN_BATCH_FILE_FORMAT_STR="${BASE_FILE_FORMAT_STR}.${SCAN_FORMAT}"

# File format to save preprocessed files as. Can be any format supported by
# numpy that can be passed to unpaper
PREPROCESS_FORMAT="pbm"

# Unpaper input files format string
UNPAPER_INPUT_FILE_FORMAT_STR="${BASE_FILE_FORMAT_STR}.${PREPROCESS_FORMAT}"

# Unpaper output file format. Unpaper doesn't convert formats so the output
# format is the same as the input format.
UNPAPER_FORMAT=$PREPROCESS_FORMAT

# Unpaper output files format string
UNPAPER_OUTPUT_FILE_FORMAT_STR="${BASE_FILE_FORMAT_STR}.${UNPAPER_FORMAT}"

# Tiff format is of course tif
TIFF_FORMAT="tif"

# Create a temporary working directory
WORK_DIR="$(mktemp -d)"

# Create subdirectories
SCAN_DIR=$WORK_DIR/raw
PREPROCESS_DIR=$WORK_DIR/preprocessed
UNPAPER_DIR=$WORK_DIR/unpapered
TIFF_DIR=$WORK_DIR/tiffs
mkdir -p $SCAN_DIR $PREPROCESS_DIR $UNPAPER_DIR $TIFF_DIR

cleanup() {
  rm -rf $WORK_DIR
}

# Cleanup regardless of when or how script exits
trap cleanup EXIT

# Scan images in batch mode, which works with the scanners automatic document
# feed to scan a stack of documents. SCANBD_DEVICE is set by scanbd
scanimage \
  --device-name=$SCANBD_DEVICE \
  --source='ADF Duplex' \
  --mode=$SCAN_MODE \
  --resolution=$SCAN_RESOLUTION \
  --batch="$SCAN_DIR/$SCAN_BATCH_FILE_FORMAT_STR" \
  --format=$SCAN_FORMAT

# Preprocess images with opencv script
. $VENV_DIR/bin/activate
for raw_scan in $SCAN_DIR/*.$SCAN_FORMAT; do
  # Use the same filename for input and output, changing only the file extension
  python $PREPROCESSOR_SCRIPT $raw_scan $PREPROCESS_DIR/$(basename $raw_scan .$SCAN_FORMAT).$PREPROCESS_FORMAT
done

# Use unpaper to further process scans
unpaper -vv $PREPROCESS_DIR/$UNPAPER_INPUT_FILE_FORMAT_STR $UNPAPER_DIR/$UNPAPER_OUTPUT_FILE_FORMAT_STR

# Convert to tiff to be able to create a multi-page document
for unpapered_scan in $UNPAPER_DIR/*.$UNPAPER_FORMAT; do
  # Use the same filename for input and output, changing the directory and file extension
  ppm2tiff -R $SCAN_RESOLUTION $unpapered_scan $TIFF_DIR/$(basename $unpapered_scan .$UNPAPER_FORMAT).$TIFF_FORMAT
done

# Combine pages into single document for paperless to consume
# Use lzma2 compression at level 5, midway between fastest (1) and smallest (9)
tiffcp -c lzma:p5 $TIFF_DIR/*.$TIFF_FORMAT "$PAPERLESS_CONSUME_DIR/$OUTPUT_BASENAME.$TIFF_FORMAT"
