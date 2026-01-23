#!/usr/bin/env python
# -*- coding: utf-8 -*-
"""
auto_crop_nifti.py

Automatically crop a NIfTI volume to the bounding box of non-zero voxels,
preserving spatial coordinates by updating the affine matrix.

Usage:
    python auto_crop_nifti.py <input_nii> <output_nii> [--threshold THRESHOLD]

Arguments:
    input_nii   - Input NIfTI file
    output_nii  - Output cropped NIfTI file
    --threshold - Threshold for non-zero detection (default: 0, i.e., any non-zero value)

This script finds the bounding box of non-zero voxels and crops the volume
while correctly updating the affine matrix to preserve spatial coordinates.
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

# Try to import ANTsPy for established cropping tool
try:
    import ants
    ANTsPy_AVAILABLE = True
except ImportError:
    ANTsPy_AVAILABLE = False


def auto_crop_volume(input_nii, output_nii, threshold=0):
    """
    Automatically crop a NIfTI volume to bounding box of non-zero voxels.
    
    Parameters:
    -----------
    input_nii : str
        Path to input NIfTI file
    output_nii : str
        Path to output cropped NIfTI file
    threshold : float
        Threshold for non-zero detection (default: 0)
    
    The affine matrix is updated to preserve spatial coordinates correctly.
    Uses ANTsPy's crop_image if available, otherwise falls back to nibabel-based implementation.
    """
    # Try to use ANTsPy's established crop_image function if available
    if ANTsPy_AVAILABLE:
        try:
            print('Using ANTsPy crop_image (established tool)...')
            # Load image with ANTsPy
            img = ants.image_read(input_nii)
            
            # crop_image automatically determines bounding box when label_image=None
            # It uses get_mask() internally to estimate the bounding box
            cropped_img = ants.crop_image(img, label_image=None, label=1)
            
            # Save cropped image
            ants.image_write(cropped_img, output_nii)
            
            # Get bounding box information from the cropped image
            # We need to compute the original bounding box for the indices file
            # Load original to compute bbox
            nii_orig = nib.load(input_nii)
            data_orig = nii_orig.get_fdata()
            mask = np.abs(data_orig) > threshold
            
            if np.any(mask):
                coords = np.argwhere(mask)
                min_coords = coords.min(axis=0)
                max_coords = coords.max(axis=0)
            else:
                min_coords = np.array([0, 0, 0])
                max_coords = np.array([0, 0, 0])
            
            # Get cropped data shape for reporting
            nii_cropped = nib.load(output_nii)
            cropped_data = nii_cropped.get_fdata()
            
            print('Input shape: %s' % str(data_orig.shape))
            print('Cropped shape: %s' % str(cropped_data.shape))
            print('Bounding box:')
            for i, dim_name in enumerate(['x', 'y', 'z', 't'][:len(min_coords)]):
                print('  %s: [%d, %d] (size: %d)' % (dim_name, min_coords[i], max_coords[i], max_coords[i] - min_coords[i] + 1))
            print('Size reduction: %.1f%%' % (100.0 * (1.0 - cropped_data.size / data_orig.size)))
            
            # Save bounding box indices (same format as nibabel version)
            indices_file = output_nii.replace('.nii.gz', '_bbox_indices.txt').replace('.nii', '_bbox_indices.txt')
            with open(indices_file, 'w') as f:
                f.write('# Bounding box indices in original image coordinates (0-indexed)\n')
                f.write('# Format: dimension min max\n')
                dim_names = ['x', 'y', 'z', 't']
                for i in range(len(min_coords)):
                    f.write('%s %d %d\n' % (dim_names[i] if i < len(dim_names) else 'dim%d' % i, 
                                            int(min_coords[i]), int(max_coords[i])))
                f.write('# Original image shape: %s\n' % str(data_orig.shape))
                f.write('# Cropped image shape: %s\n' % str(cropped_data.shape))
            
            print('Saved cropped volume to: %s' % output_nii)
            print('Saved bounding box indices to: %s' % indices_file)
            print('Bounding box indices (min, max):')
            for i, dim_name in enumerate(['x', 'y', 'z', 't'][:len(min_coords)]):
                print('  %s: [%d, %d]' % (dim_name, int(min_coords[i]), int(max_coords[i])))
            print('Spatial coordinates preserved correctly (via ANTsPy).')
            return
            
        except Exception as e:
            print('Warning: ANTsPy crop_image failed, falling back to nibabel implementation.', file=sys.stderr)
            print('  Error: %s' % str(e), file=sys.stderr)
            # Fall through to nibabel implementation
    
    # Fallback to nibabel-based implementation
    # Load NIfTI file
    nii = nib.load(input_nii)
    data = nii.get_fdata()
    affine = nii.affine.copy()  # Make a copy to modify
    header = nii.header.copy()
    
    print('Input shape: %s' % str(data.shape))
    print('Input data range: [%.4f, %.4f]' % (np.min(data), np.max(data)))
    
    # Find bounding box of non-zero voxels
    # For multi-dimensional data, find where any value exceeds threshold
    mask = np.abs(data) > threshold
    
    if not np.any(mask):
        print('Warning: No voxels exceed threshold %.4f. Output will be empty.' % threshold, file=sys.stderr)
        # Create minimal output
        cropped_data = np.zeros((1, 1, 1), dtype=data.dtype)
        # Update affine to center of original volume
        center_vox = np.array([s // 2 for s in data.shape])
        center_ras = affine[:3, :3] @ center_vox + affine[:3, 3]
        new_affine = affine.copy()
        new_affine[:3, 3] = center_ras
        min_coords = np.array([0, 0, 0])
        max_coords = np.array([0, 0, 0])
    else:
        # Find bounding box indices
        coords = np.argwhere(mask)
        if len(coords) == 0:
            raise RuntimeError('No non-zero voxels found')
        
        # Get min/max for each dimension
        min_coords = coords.min(axis=0)
        max_coords = coords.max(axis=0)
        
        # Handle multi-dimensional case (e.g., 4D volumes)
        # Create slice tuple for cropping
        crop_slices = tuple(slice(min_coords[i], max_coords[i] + 1) for i in range(len(min_coords)))
        
        # Crop the data
        cropped_data = data[crop_slices]
        
        print('Bounding box:')
        for i, dim_name in enumerate(['x', 'y', 'z', 't'][:len(min_coords)]):
            print('  %s: [%d, %d] (size: %d)' % (dim_name, min_coords[i], max_coords[i], max_coords[i] - min_coords[i] + 1))
        
        print('Cropped shape: %s' % str(cropped_data.shape))
        print('Size reduction: %.1f%%' % (100.0 * (1.0 - cropped_data.size / data.size)))
        
        # Update affine matrix to account for cropping
        # The translation part needs to be adjusted by the crop offset
        # affine[:3, 3] is the translation in RAS space
        # We need to add the offset in voxel space transformed to RAS space
        crop_offset = min_coords[:3]  # Only use first 3 dimensions for spatial transform
        
        # Transform crop offset from voxel space to RAS space
        # The offset in RAS = affine[:3, :3] @ crop_offset
        ras_offset = affine[:3, :3] @ crop_offset
        
        # Update translation: new_translation = old_translation + offset
        new_affine = affine.copy()
        new_affine[:3, 3] = affine[:3, 3] + ras_offset
    
    # Preserve data type
    if cropped_data.dtype != data.dtype:
        # Try to preserve original dtype, but may need to cast
        try:
            cropped_data = cropped_data.astype(data.dtype)
        except (ValueError, OverflowError):
            print('Warning: Could not preserve original dtype %s, using %s' % 
                  (data.dtype, cropped_data.dtype), file=sys.stderr)
    
    # Create and save cropped volume
    cropped_nii = nib.Nifti1Image(cropped_data, new_affine, header)
    nib.save(cropped_nii, output_nii)
    
    # Save bounding box indices to a text file
    indices_file = output_nii.replace('.nii.gz', '_bbox_indices.txt').replace('.nii', '_bbox_indices.txt')
    with open(indices_file, 'w') as f:
        f.write('# Bounding box indices in original image coordinates (0-indexed)\n')
        f.write('# Format: dimension min max\n')
        dim_names = ['x', 'y', 'z', 't']
        for i in range(len(min_coords)):
            f.write('%s %d %d\n' % (dim_names[i] if i < len(dim_names) else 'dim%d' % i, 
                                    int(min_coords[i]), int(max_coords[i])))
        f.write('# Original image shape: %s\n' % str(data.shape))
        f.write('# Cropped image shape: %s\n' % str(cropped_data.shape))
    
    print('Saved cropped volume to: %s' % output_nii)
    print('Saved bounding box indices to: %s' % indices_file)
    print('Bounding box indices (min, max):')
    for i, dim_name in enumerate(['x', 'y', 'z', 't'][:len(min_coords)]):
        print('  %s: [%d, %d]' % (dim_name, int(min_coords[i]), int(max_coords[i])))
    print('Spatial coordinates preserved correctly.')


def main():
    parser = argparse.ArgumentParser(
        description='Automatically crop NIfTI volume to bounding box of non-zero voxels',
        formatter_class=argparse.RawDescriptionHelpFormatter,
        epilog="""
Examples:
  # Crop to non-zero voxels (default threshold = 0)
  python auto_crop_nifti.py input.nii.gz output_cropped.nii.gz
  
  # Crop with custom threshold
  python auto_crop_nifti.py input.nii.gz output_cropped.nii.gz --threshold 0.1
        """
    )
    parser.add_argument('input_nii', help='Input NIfTI file')
    parser.add_argument('output_nii', help='Output cropped NIfTI file')
    parser.add_argument('--threshold', type=float, default=0.0,
                        help='Threshold for non-zero detection (default: 0.0)')
    
    args = parser.parse_args()
    
    if not os.path.exists(args.input_nii):
        print('Error: Input file not found: %s' % args.input_nii, file=sys.stderr)
        sys.exit(1)
    
    # Ensure output directory exists
    output_dir = os.path.dirname(args.output_nii)
    if output_dir and not os.path.exists(output_dir):
        os.makedirs(output_dir)
    
    try:
        auto_crop_volume(args.input_nii, args.output_nii, args.threshold)
    except Exception as e:
        print('Error: %s' % str(e), file=sys.stderr)
        import traceback
        traceback.print_exc()
        sys.exit(1)


if __name__ == '__main__':
    main()
