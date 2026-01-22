#!/usr/bin/env python
# -*- coding: utf-8 -*-
"""
label_connected_components_nifti.py

Label connected components in a binary NIfTI volume using scikit-image.

Usage:
    python label_connected_components_nifti.py <input_nii> <output_nii> [--connectivity N]

Arguments:
    input_nii  - Input binary NIfTI file (non-zero = foreground)
    output_nii - Output labeled NIfTI file (voxel value = component index, sorted by size)
    --connectivity - Connectivity: 1 (face-only, 6 in 3D), 2 (face+edge, 18 in 3D), 
                     or 3 (full, 26 in 3D). Default: 3 (26-connectivity for 3D)

Output:
    Labeled NIfTI where each connected component is assigned an integer label.
    Components are sorted by size (largest = 1, second largest = 2, etc.).
    Background voxels remain 0.
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

# Try to import scikit-image
try:
    from skimage.measure import label, regionprops
except ImportError:
    print('Error: scikit-image is required but not installed.', file=sys.stderr)
    print('Install with: pip install scikit-image', file=sys.stderr)
    sys.exit(1)


def label_components(input_nii, output_nii, connectivity=3):
    """Label connected components in a binary NIfTI volume."""
    
    # Load NIfTI file
    nii = nib.load(input_nii)
    data = nii.get_fdata()
    affine = nii.affine
    header = nii.header

    # Convert to binary (non-zero = foreground)
    binary = (data > 0).astype(bool)

    print('Labeling connected components...')
    print('Input shape: %s' % str(binary.shape))
    print('Foreground voxels: %d' % np.sum(binary))
    print('Connectivity: %d (26-connectivity for 3D)' % connectivity if connectivity == 3 else 'Connectivity: %d' % connectivity)

    # Label connected components
    labeled = label(binary, connectivity=connectivity)

    # Get region properties and sort by size (area = number of voxels)
    props = regionprops(labeled)
    
    # Sort by area (number of voxels) in descending order
    props_sorted = sorted(props, key=lambda x: x.area, reverse=True)
    
    print('Number of components: %d' % len(props_sorted))
    if len(props_sorted) > 0:
        print('Largest component: %d voxels' % props_sorted[0].area)
        if len(props_sorted) > 1:
            print('Smallest component: %d voxels' % props_sorted[-1].area)

    # Create output labeled image with sorted indices
    # Component 0 = background, Component 1 = largest, Component 2 = second largest, etc.
    labeled_sorted = np.zeros_like(labeled, dtype=np.uint32)
    
    for new_label, prop in enumerate(props_sorted, start=1):
        # prop.label is the original label from scikit-image
        # new_label is the sorted index (1 = largest, 2 = second largest, etc.)
        labeled_sorted[labeled == prop.label] = new_label

    # Save labeled volume
    # Use uint32 to support many components
    labeled_nii = nib.Nifti1Image(labeled_sorted.astype(np.uint32), affine, header)
    nib.save(labeled_nii, output_nii)
    print('Saved labeled volume to: %s' % output_nii)
    print('Component indices: 0 (background), 1 (largest), 2 (second largest), ...')


def main():
    parser = argparse.ArgumentParser(description='Label connected components in binary NIfTI volume')
    parser.add_argument('input_nii', help='Input binary NIfTI file')
    parser.add_argument('output_nii', help='Output labeled NIfTI file')
    parser.add_argument('--connectivity', type=int, choices=[1, 2, 3], default=3,
                        help='Connectivity: 1 (6-connectivity), 2 (18-connectivity), 3 (26-connectivity, default)')

    args = parser.parse_args()

    if not os.path.exists(args.input_nii):
        print('Error: Input file not found: %s' % args.input_nii, file=sys.stderr)
        sys.exit(1)

    # Ensure output directory exists
    output_dir = os.path.dirname(args.output_nii)
    if output_dir and not os.path.exists(output_dir):
        os.makedirs(output_dir)

    try:
        label_components(args.input_nii, args.output_nii, args.connectivity)
    except Exception as e:
        print('Error: %s' % str(e), file=sys.stderr)
        import traceback
        traceback.print_exc()
        sys.exit(1)


if __name__ == '__main__':
    main()
