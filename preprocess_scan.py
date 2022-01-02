#!/usr/bin/env python3
# Preprocessor for scanned grayscale images. Can automatically detect if page
# is empty and
import cv2 as cv
import math
import numpy as np
import sys
import os

# Threshold of page area that must be covered by blobs for page to be
# considered contentful (non-blank)
CONTENTFUL_PAGE_THRESHOLD = 1e-4


def smoothen_raw_scan(img):
    """
    Enhances the given raw scanned image by applying edge-preserving smoothing
    to reduce noise.
    """
    return cv.bilateralFilter(img, -1, 10, 10)


def crop_document(img):
    """
    Returns a new image, cropped and rotated to include just the document.
    """
    threshold_img = apply_threshold(img)
    contours, _ = cv.findContours(threshold_img, cv.RETR_LIST, cv.CHAIN_APPROX_SIMPLE)
    largest_area = 0
    largest_rect = None

    for contour in contours:
        rect = cv.minAreaRect(contour)
        width, height = rect[1]
        rect_area = width * height

        if rect_area > largest_area:
            largest_area = rect_area
            largest_rect = rect

    if largest_rect is None:
        raise RuntimeError("Could not find any contours in image. Is it blank?")

    src_points = cv.boxPoints(largest_rect)
    # get width and height of the detected rectangle
    width = int(largest_rect[1][0])
    height = int(largest_rect[1][1])

    # coordinate of the points in box points after the rectangle has been
    # straightened
    dst_points = np.array(
        [[0, height - 1], [0, 0], [width - 1, 0], [width - 1, height - 1]],
        dtype="float32",
    )

    # get perspective transformation matrix
    transform_mat = cv.getPerspectiveTransform(src_points, dst_points)

    # warp the rotated rectangle to get the straightened rectangle
    cropped = cv.warpPerspective(
        img,
        transform_mat,
        (width, height),
        # Bilinear interpolation
        flags=cv.INTER_LINEAR,
        # If the cropped image includes areas outside of the original, fill with white.
        borderMode=cv.BORDER_CONSTANT,
        borderValue=[255, 255, 255],
    )

    return cropped


def apply_threshold(img):
    """
    Applies the otsu thresholding algorithm to increase contrast and convert
    image to black and white.
    """
    threshold, img_out = cv.threshold(img, 0, 255, cv.THRESH_BINARY + cv.THRESH_OTSU)
    print("Otsu algorithm determined threshold value of", threshold)
    return img_out


def is_blank_page(img, threshold=CONTENTFUL_PAGE_THRESHOLD) -> bool:
    """
    Returns True if the page is believed to be blank. Expects a black and white
    thresholded image.
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
    return percent_content < threshold


def main():
    if len(sys.argv) != 3:
        print(f"Usage {sys.argv[0]} input_path output_path")
        sys.exit(1)

    in_path = sys.argv[1]
    out_path = sys.argv[2]

    img_in = cv.imread(in_path, 0)

    img_smooth = smoothen_raw_scan(img_in)
    img_cropped = crop_document(img_smooth)
    img_out = apply_threshold(img_cropped)

    debug_mode = os.environ.get("DEBUG_MODE")
    if debug_mode == "show":
        cv.imshow("0: input", img_in)
        cv.imshow("1: smoothed", img_smooth)
        cv.imshow("2: cropped", img_cropped)
        cv.imshow("3: thresholded", img_out)
        cv.waitKey(0)
    elif debug_mode == "save":
        cv.imwrite("0_input.png", img_in)
        cv.imwrite("1_smoothed.png", img_smooth)
        cv.imwrite("2_cropped.png", img_cropped)
        cv.imwrite("3_thresholded.png", img_out)

    if is_blank_page(img_out):
        print("Page is blank, not outputting anything")
    else:
        print(f"Page has content, writing to {out_path}")
        cv.imwrite(out_path, img_out)


if __name__ == "__main__":
    main()
