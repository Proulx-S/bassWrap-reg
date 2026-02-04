#!/usr/bin/env python
# -*- coding: utf-8 -*-
"""
vtk_add_nifti_metadata.py

Add NIfTI coordinate system metadata to a VTK PolyData file.
Use this for surfaces created from a NIfTI (e.g. by vmtk_surfFromSeg / marching cubes)
so that downstream tools know the surface points are in that NIfTI's physical (RAS) space.

Usage:
    python vtk_add_nifti_metadata.py <surface_vtk> <source_nifti> [output_vtk]

If output_vtk is omitted, overwrites surface_vtk.
"""

from __future__ import print_function
import sys
import os

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


def add_nifti_metadata_to_vtk(surface_vtk, source_nii, output_vtk=None):
    """Add NIfTI_Affine, CoordinateSystem, and SourceNIfTI to VTK FieldData.
    
    The surface geometry is unchanged; points are assumed to be in the source
    NIfTI's physical (RAS) space (e.g. marching cubes output).
    """
    if output_vtk is None:
        output_vtk = surface_vtk
    
    nii = nib.load(source_nii)
    affine = nii.header.get_best_affine()
    
    ext = os.path.splitext(surface_vtk)[1].lower()
    if ext == '.vtp':
        reader = vtk.vtkXMLPolyDataReader()
    else:
        reader = vtk.vtkPolyDataReader()
    
    reader.SetFileName(surface_vtk)
    reader.Update()
    polydata = reader.GetOutput()
    
    field_data = polydata.GetFieldData()
    
    # NIfTI_Affine (4x4, row-major)
    affine_array = vtk.vtkDoubleArray()
    affine_array.SetName('NIfTI_Affine')
    affine_array.SetNumberOfComponents(16)
    affine_array.SetNumberOfTuples(1)
    for i in range(16):
        affine_array.SetValue(i, affine.flatten(order='C')[i])
    field_data.AddArray(affine_array)
    
    # CoordinateSystem
    coord_array = vtk.vtkStringArray()
    coord_array.SetName('CoordinateSystem')
    coord_array.SetNumberOfValues(1)
    coord_array.SetValue(0, 'RAS')
    field_data.AddArray(coord_array)
    
    # SourceNIfTI (absolute path for reproducibility)
    source_path = os.path.abspath(source_nii)
    source_array = vtk.vtkStringArray()
    source_array.SetName('SourceNIfTI')
    source_array.SetNumberOfValues(1)
    source_array.SetValue(0, source_path)
    field_data.AddArray(source_array)
    
    ext_out = os.path.splitext(output_vtk)[1].lower()
    if ext_out == '.vtp':
        writer = vtk.vtkXMLPolyDataWriter()
    else:
        writer = vtk.vtkPolyDataWriter()
    
    writer.SetFileName(output_vtk)
    writer.SetInputData(polydata)
    writer.Write()
    
    return output_vtk


if __name__ == '__main__':
    if len(sys.argv) < 3:
        print('Usage: python vtk_add_nifti_metadata.py <surface_vtk> <source_nifti> [output_vtk]', file=sys.stderr)
        sys.exit(1)
    
    surface_vtk = sys.argv[1]
    source_nii = sys.argv[2]
    output_vtk = sys.argv[3] if len(sys.argv) > 3 else None
    
    if not os.path.exists(surface_vtk):
        print('Error: Surface file not found: %s' % surface_vtk, file=sys.stderr)
        sys.exit(1)
    if not os.path.exists(source_nii):
        print('Error: NIfTI file not found: %s' % source_nii, file=sys.stderr)
        sys.exit(1)
    
    out = add_nifti_metadata_to_vtk(surface_vtk, source_nii, output_vtk)
    print('Added NIfTI metadata; wrote: %s' % out)
