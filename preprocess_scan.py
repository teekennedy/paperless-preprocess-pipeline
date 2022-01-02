#!/usr/bin/env python3
# Preprocessor for scanned grayscale images. Can automatically detect if page
# is empty and
import cv2 as cv
import math
import sys

# Threshold of page area that must be covered by blobs for page to be
# considered contentful (non-blank)
CONTENTFUL_PAGE_THRESHOLD = 1e-4

if len(sys.argv) != 3:
    print(f"Usage {sys.argv[0]} input_path output_path")
    sys.exit(1)


def is_blank_page(img, threshold=CONTENTFUL_PAGE_THRESHOLD) -> bool:
    """
    Returns True if the page is believed to be empty.
    """
    params = cv.SimpleBlobDetector_Params()

    # Turn off all filters
    params.filterByArea = False
    params.filterByCircularity = False
    params.filterByConvexity = False
    params.filterByInertia = False

    # Create a detector with the parameters
    detector = cv.SimpleBlobDetector_create(params)

    # Detect blobs in image
    keypoints = detector.detect(img)
    # Compute percentage of image that has content
    percent_content = sum(math.pi * kp.size for kp in keypoints) / img.size
    print(f"Page is at least {percent_content * 100:0.4f}% content")
    return percent_content > threshold


in_path = sys.argv[1]
out_path = sys.argv[2]

img_in = cv.imread(sys.argv[1], 0)

smooth = cv.bilateralFilter(img_in, -1, 10, 10)
_, img_out = cv.threshold(smooth, 0, 255, cv.THRESH_BINARY + cv.THRESH_OTSU)

if is_blank_page(img_out):
    print("Page is blank, not outputting anything")
else:
    print(f"Page has content, writing to {out_path}")
    cv.imwrite(out_path, img_out)
