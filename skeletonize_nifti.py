#!/usr/bin/env python
# -*- coding: utf-8 -*-
"""
skeletonize_nifti.py

Skeletonize a binary NIfTI volume using scikit-image's skeletonize function.

Usage:
    python skeletonize_nifti.py <input_nii> <output_nii> [--method METHOD]

Arguments:
    input_nii  - Input binary NIfTI file (non-zero = foreground)
    output_nii - Output skeletonized NIfTI file
    --method   - Skeletonization method: 'zhang' (default) or 'lee'
                 Lee's method is designed for 3D images and is automatically
                 selected for 3D volumes.

This script uses scikit-image's skeletonize function which reduces binary
objects to 1 pixel wide representations while preserving connectivity.
"""

from __future__ import print_function
import os
import sys
import argparse
import numpy as np

# Try to import nibabel, provide helpful error if not available
try:
    import nibabel as nib
except ImportError:
    print('Error: nibabel is required but not installed.', file=sys.stderr)
    print('Install with: pip install nibabel', file=sys.stderr)
    print('Or use a Python environment that includes nibabel (e.g., Neurodesk container)', file=sys.stderr)
    sys.exit(1)


def skeletonize_volume(input_nii, output_nii, method='zhang'):
    """Skeletonize a binary NIfTI volume using scikit-image."""
    try:
        from skimage.morphology import skeletonize
    except ImportError:
        raise RuntimeError('scikit-image not found. Install with: pip install scikit-image')

    # Load NIfTI file
    nii = nib.load(input_nii)
    data = nii.get_fdata()
    affine = nii.affine
    header = nii.header

    # Convert to binary (non-zero = foreground)
    binary = (data > 0).astype(bool)

    # Determine if 3D (more than 2 dimensions with size > 1)
    is_3d = len(binary.shape) == 3 and all(s > 1 for s in binary.shape)

    # For 3D volumes, use Lee's method (designed for 3D)
    # For 2D, use specified method (default: zhang)
    if is_3d:
        if method == 'zhang':
            print('Note: 3D volume detected. Using Lee method (recommended for 3D) instead of Zhang.')
        actual_method = 'lee'
    else:
        actual_method = method

    print('Skeletonizing using %s method...' % actual_method)
    print('Input shape: %s' % str(binary.shape))
    print('Foreground voxels: %d' % np.sum(binary))

    # Perform skeletonization
    skeleton = skeletonize(binary, method=actual_method)

    print('Skeleton voxels: %d' % np.sum(skeleton))
    print('Reduction: %.1f%%' % (100.0 * (1.0 - np.sum(skeleton) / max(1, np.sum(binary)))))

    # Keep skeleton as binary (0/1) - don't convert to original data type
    skeleton_data = skeleton.astype(np.uint8)

    # Save skeletonized volume
    skeleton_nii = nib.Nifti1Image(skeleton_data, affine, header)
    nib.save(skeleton_nii, output_nii)
    print('Saved skeletonized volume to: %s' % output_nii)


def main():
    parser = argparse.ArgumentParser(description='Skeletonize binary NIfTI volume using scikit-image')
    parser.add_argument('input_nii', help='Input binary NIfTI file')
    parser.add_argument('output_nii', help='Output skeletonized NIfTI file')
    parser.add_argument('--method', choices=['zhang', 'lee'], default='zhang',
                        help='Skeletonization method (default: zhang, auto-switches to lee for 3D)')

    args = parser.parse_args()

    if not os.path.exists(args.input_nii):
        print('Error: Input file not found: %s' % args.input_nii, file=sys.stderr)
        sys.exit(1)

    # Ensure output directory exists
    output_dir = os.path.dirname(args.output_nii)
    if output_dir and not os.path.exists(output_dir):
        os.makedirs(output_dir)

    try:
        skeletonize_volume(args.input_nii, args.output_nii, args.method)
    except Exception as e:
        print('Error: %s' % str(e), file=sys.stderr)
        sys.exit(1)


if __name__ == '__main__':
    main()
