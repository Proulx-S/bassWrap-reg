#!/usr/bin/env python
# -*- coding: utf-8 -*-
"""
vmtk_activetubes.py

Refine centerlines using vmtkactivetubes to fit vessel tube model to intensity image.

This script uses vmtkactivetubes to refine initial centerlines by fitting them
to the intensity image, creating a more accurate vessel tube model.

Usage:
    python vmtk_activetubes.py <intensity_nii> <initial_centerline_vtk> <output_vtk> [--iterations 100] [--potentialweight 1.0] [--stiffnessweight 1.0]
"""

from __future__ import print_function
import sys
import os
import argparse
import tempfile
import subprocess

try:
    import nibabel as nib
except ImportError:
    print('Error: nibabel is required. Install with: pip install nibabel', file=sys.stderr)
    print('Or use a Neurodesk container with nibabel (e.g., nipype/1.8.3)', file=sys.stderr)
    sys.exit(1)

try:
    import vtk
except ImportError:
    print('Error: VTK Python bindings are required but not installed.', file=sys.stderr)
    print('Install with: pip install vtk', file=sys.stderr)
    print('Or use a Python environment that includes VTK.', file=sys.stderr)
    sys.exit(1)


def nifti_to_vtk_image(nii_path, vti_path):
    """Convert NIfTI image to VTK ImageData format using vmtkimagereader.
    
    Args:
        nii_path: Path to input NIfTI file
        vti_path: Path to output VTK ImageData file (.vti)
    """
    try:
        # Try using vmtk Python bindings first
        from vmtk import vmtkscripts
        
        # Read NIfTI using nibabel
        nii = nib.load(nii_path)
        image_data = nii.get_fdata()
        affine = nii.header.get_best_affine()
        
        # Create VTK ImageData
        vtk_image = vtk.vtkImageData()
        dims = image_data.shape
        vtk_image.SetDimensions(dims[2], dims[1], dims[0])  # VTK uses (z, y, x) ordering
        vtk_image.SetSpacing(1.0, 1.0, 1.0)  # Will be set properly by vmtk
        vtk_image.SetOrigin(0.0, 0.0, 0.0)
        
        # Convert numpy array to VTK array
        flat_image = image_data.flatten(order='F')  # Fortran order for VTK
        vtk_array = vtk.vtkFloatArray()
        vtk_array.SetNumberOfComponents(1)
        vtk_array.SetNumberOfTuples(flat_image.size)
        for i in range(flat_image.size):
            vtk_array.SetValue(i, float(flat_image[i]))
        
        vtk_image.GetPointData().SetScalars(vtk_array)
        
        # Use vmtkimagereader/writer for proper coordinate system handling
        # For now, use command-line approach which is more reliable
        # This is a fallback - ideally we'd use Python bindings
        print('Note: Using command-line vmtkimagereader for coordinate system compatibility')
        return False
        
    except ImportError:
        # Fall back to command-line approach
        return False


def run_vmtk_activetubes(intensity_vti, initial_centerline_vtk, output_vtk, 
                         iterations=100, potentialweight=1.0, stiffnessweight=1.0):
    """Run vmtkactivetubes using command-line interface.
    
    Args:
        intensity_vti: Path to VTK ImageData file (intensity image)
        initial_centerline_vtk: Path to initial centerline VTK PolyData file
        output_vtk: Path to output refined centerline VTK file
        iterations: Number of iterations (default: 100)
        potentialweight: Potential weight parameter (default: 1.0)
        stiffnessweight: Stiffness weight parameter (default: 1.0)
    """
    # Build command
    cmd = [
        'vmtkactivetubes',
        '-imagefile', intensity_vti,
        '-ifile', initial_centerline_vtk,
        '-iterations', str(iterations),
        '-potentialweight', str(potentialweight),
        '-stiffnessweight', str(stiffnessweight),
        '-ofile', output_vtk
    ]
    
    print('Running vmtkactivetubes...')
    print('Command: %s' % ' '.join(cmd))
    
    try:
        result = subprocess.run(cmd, capture_output=True, text=True, check=True)
        if result.stdout:
            print(result.stdout)
        return True
    except subprocess.CalledProcessError as e:
        print('Error: vmtkactivetubes failed', file=sys.stderr)
        if e.stdout:
            print(e.stdout, file=sys.stderr)
        if e.stderr:
            print(e.stderr, file=sys.stderr)
        return False
    except FileNotFoundError:
        print('Error: vmtkactivetubes command not found. Make sure VMTK is installed and in PATH.', file=sys.stderr)
        return False


def main():
    parser = argparse.ArgumentParser(
        description='Refine centerlines using vmtkactivetubes to fit vessel tube model'
    )
    parser.add_argument('intensity_nii', help='Input intensity NIfTI image')
    parser.add_argument('initial_centerline_vtk', help='Input initial centerline VTK PolyData file')
    parser.add_argument('output_vtk', help='Output refined centerline VTK PolyData file')
    parser.add_argument(
        '--iterations', type=int, default=100,
        help='Number of iterations (default: 100)'
    )
    parser.add_argument(
        '--potentialweight', type=float, default=1.0,
        help='Potential weight parameter (default: 1.0)'
    )
    parser.add_argument(
        '--stiffnessweight', type=float, default=1.0,
        help='Stiffness weight parameter (default: 1.0)'
    )
    
    args = parser.parse_args()
    
    # Check input files
    if not os.path.exists(args.intensity_nii):
        print('Error: Intensity image not found: %s' % args.intensity_nii, file=sys.stderr)
        sys.exit(1)
    
    if not os.path.exists(args.initial_centerline_vtk):
        print('Error: Initial centerline not found: %s' % args.initial_centerline_vtk, file=sys.stderr)
        sys.exit(1)
    
    # Ensure output directory exists
    output_dir = os.path.dirname(args.output_vtk)
    if output_dir and not os.path.exists(output_dir):
        os.makedirs(output_dir)
    
    # Convert NIfTI to VTK ImageData format
    # Use temporary file in same directory as output for easier cleanup
    if output_dir:
        temp_dir = output_dir
    else:
        temp_dir = os.path.dirname(os.path.abspath(args.output_vtk))
    
    intensity_vti = os.path.join(temp_dir, 'intensity_temp.vti')
    
    print('Converting NIfTI to VTK ImageData format...')
    print('  Input: %s' % args.intensity_nii)
    print('  Output: %s' % intensity_vti)
    
    # Use vmtkimagereader command-line tool for conversion
    cmd = [
        'vmtkimagereader',
        '-ifile', args.intensity_nii,
        '--pipe',
        'vmtkimagewriter',
        '-ofile', intensity_vti
    ]
    
    try:
        result = subprocess.run(cmd, capture_output=True, text=True, check=True)
        if result.stdout:
            print(result.stdout)
    except subprocess.CalledProcessError as e:
        print('Error: Failed to convert NIfTI to VTK ImageData', file=sys.stderr)
        if e.stdout:
            print(e.stdout, file=sys.stderr)
        if e.stderr:
            print(e.stderr, file=sys.stderr)
        sys.exit(1)
    except FileNotFoundError:
        print('Error: vmtkimagereader command not found. Make sure VMTK is installed and in PATH.', file=sys.stderr)
        sys.exit(1)
    
    if not os.path.exists(intensity_vti):
        print('Error: VTK ImageData file was not created: %s' % intensity_vti, file=sys.stderr)
        sys.exit(1)
    
    # Run vmtkactivetubes
    success = run_vmtk_activetubes(
        intensity_vti,
        args.initial_centerline_vtk,
        args.output_vtk,
        iterations=args.iterations,
        potentialweight=args.potentialweight,
        stiffnessweight=args.stiffnessweight
    )
    
    if not success:
        # Clean up temporary file
        if os.path.exists(intensity_vti):
            os.remove(intensity_vti)
        sys.exit(1)
    
    # Verify output was created
    if not os.path.exists(args.output_vtk):
        print('Error: Output centerline file was not created: %s' % args.output_vtk, file=sys.stderr)
        if os.path.exists(intensity_vti):
            os.remove(intensity_vti)
        sys.exit(1)
    
    file_info = os.stat(args.output_vtk)
    if file_info.st_size == 0:
        print('Error: Output centerline file is empty: %s' % args.output_vtk, file=sys.stderr)
        if os.path.exists(intensity_vti):
            os.remove(intensity_vti)
        sys.exit(1)
    
    # Clean up temporary file
    if os.path.exists(intensity_vti):
        os.remove(intensity_vti)
    
    print('Success! Refined centerline saved to: %s' % args.output_vtk)
    print('  File size: %d bytes' % file_info.st_size)


if __name__ == '__main__':
    main()
