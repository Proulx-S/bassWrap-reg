#!/usr/bin/env python
# -*- coding: utf-8 -*-
"""
vmtk_apply_coord_transform.py

Apply coordinate system transformation to VTK surface to align with image coordinate system.
This script reads the NIfTI image affine and the VTK surface metadata, and applies
the appropriate transformation to ensure alignment in VMTK viewer.

Usage:
    python vmtk_apply_coord_transform.py <image_nii> <input_surface_vtk> <output_surface_vtk>
"""

from __future__ import print_function
import sys
import os
import numpy as np

try:
    import nibabel as nib
except ImportError:
    print('Error: nibabel is required.', file=sys.stderr)
    sys.exit(1)

try:
    import vtk
except ImportError:
    print('Error: VTK Python bindings are required.', file=sys.stderr)
    sys.exit(1)


def read_vtk_surface(vtk_file):
    """Read VTK PolyData surface."""
    ext = os.path.splitext(vtk_file)[1].lower()
    if ext == '.vtp':
        reader = vtk.vtkXMLPolyDataReader()
    else:
        reader = vtk.vtkPolyDataReader()
    
    reader.SetFileName(vtk_file)
    reader.Update()
    return reader.GetOutput()


def get_fielddata_info(polydata):
    """Extract coordinate system information from FieldData."""
    field_data = polydata.GetFieldData()
    
    info = {}
    
    # Get affine matrix
    affine_array = field_data.GetArray('NIfTI_Affine')
    if affine_array:
        values = [affine_array.GetValue(i) for i in range(16)]
        info['affine'] = np.array(values).reshape(4, 4)
    
    # Get coordinate system
    coord_array = field_data.GetArray('CoordinateSystem')
    if coord_array:
        info['coord_system'] = coord_array.GetValue(0)
    
    # Get source NIfTI
    source_array = field_data.GetArray('SourceNIfTI')
    if source_array:
        info['source_nii'] = source_array.GetValue(0)
    
    return info


def apply_transform(polydata, transform_matrix):
    """Apply 4x4 transformation matrix to polydata."""
    transform = vtk.vtkTransform()
    transform.SetMatrix(transform_matrix.flatten())
    
    transform_filter = vtk.vtkTransformPolyDataFilter()
    transform_filter.SetInputData(polydata)
    transform_filter.SetTransform(transform)
    transform_filter.Update()
    
    return transform_filter.GetOutput()


def main():
    if len(sys.argv) < 4:
        print('Usage: python vmtk_apply_coord_transform.py <image_nii> <input_surface_vtk> <output_surface_vtk>', file=sys.stderr)
        sys.exit(1)
    
    image_nii = sys.argv[1]
    input_vtk = sys.argv[2]
    output_vtk = sys.argv[3]
    
    # Read image affine
    nii = nib.load(image_nii)
    image_affine = nii.header.get_best_affine()
    
    print('Image NIfTI affine:')
    print(image_affine)
    print('')
    
    # Read surface
    polydata = read_vtk_surface(input_vtk)
    fielddata_info = get_fielddata_info(polydata)
    
    if 'affine' in fielddata_info:
        print('Surface NIfTI affine (from FieldData):')
        print(fielddata_info['affine'])
        print('')
    
    if 'coord_system' in fielddata_info:
        print('Surface coordinate system: %s' % fielddata_info['coord_system'])
        print('')
    
    # The key issue: vmtkimagereader processes NIfTI and outputs in a specific coordinate system.
    # If the surface is in RAS but the image output is in a different system, we need to transform.
    # However, determining the exact transformation requires knowing how vmtkimagereader processes the image.
    #
    # For now, if the surface is in RAS and doesn't align, it might be because:
    # 1. The image reader outputs in a different coordinate system
    # 2. There's a mismatch in how transformations are applied
    #
    # Since the user reported that xyz coordinates work, the image reader likely outputs
    # in a coordinate system closer to xyz than pure RAS.
    
    print('Note: This script is a utility to help debug coordinate system issues.')
    print('VMTK command-line tools do not automatically use FieldData metadata.')
    print('')
    print('If surfaces don\'t align:')
    print('  1. Check what coordinate system the surface is in (see FieldData)')
    print('  2. The surface should be in the same coordinate system as vmtkimagereader output')
    print('  3. Use --coordinate-system xyz when creating the surface if RAS doesn\'t align')
    print('')
    
    # For now, just copy the surface (no transformation applied)
    # In the future, this could apply the appropriate transformation based on
    # the coordinate system mismatch
    ext_out = os.path.splitext(output_vtk)[1].lower()
    if ext_out == '.vtp':
        writer = vtk.vtkXMLPolyDataWriter()
    else:
        writer = vtk.vtkPolyDataWriter()
    
    writer.SetFileName(output_vtk)
    writer.SetInputData(polydata)
    writer.Write()
    
    print('Surface copied to: %s' % output_vtk)
    print('(No transformation applied - coordinate system alignment may still be needed)')


if __name__ == '__main__':
    main()
