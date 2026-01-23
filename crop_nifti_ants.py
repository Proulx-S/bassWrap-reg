#!/usr/bin/env python
# -*- coding: utf-8 -*-
"""
crop_nifti_ants.py

Simple wrapper for ANTsPy's crop_image function to automatically crop
a NIfTI volume to the bounding box of non-zero voxels.

Usage:
    python crop_nifti_ants.py <input_nii> <output_nii>

Arguments:
    input_nii  - Input NIfTI file
    output_nii - Output cropped NIfTI file

This script uses ANTsPy's established crop_image function which automatically
determines the bounding box and preserves spatial coordinates.
"""

from __future__ import print_function
import sys
import ants

if len(sys.argv) < 3:
    print('Usage: python crop_nifti_ants.py <input_nii> <output_nii>', file=sys.stderr)
    sys.exit(1)

input_nii = sys.argv[1]
output_nii = sys.argv[2]

# Load image with ANTsPy
img = ants.image_read(input_nii)

# Crop to bounding box (label_image=None means automatic detection)
cropped_img = ants.crop_image(img, label_image=None, label=1)

# Save cropped image
ants.image_write(cropped_img, output_nii)

print('Cropped volume saved to: %s' % output_nii)
