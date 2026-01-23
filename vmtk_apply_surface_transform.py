#!/usr/bin/env python
# -*- coding: utf-8 -*-
"""
vmtk_apply_surface_transform.py

Apply coordinate system transformation to VTK surface based on metadata stored in FieldData
or transformation matrices from vmtkimagereader.

This script can be used in VMTK pipelines to ensure surfaces align with images.
"""

from __future__ import print_function
import sys
import os
import numpy as np

try:
    import vtk
except ImportError:
    print('Error: VTK Python bindings are required but not installed.', file=sys.stderr)
    sys.exit(1)


def get_affine_from_fielddata(polydata):
    """Extract NIfTI affine matrix from VTK PolyData FieldData.
    
    Args:
        polydata: vtkPolyData object
    
    Returns:
        4x4 numpy array (affine matrix) or None if not found
    """
    field_data = polydata.GetFieldData()
    affine_array = field_data.GetArray('NIfTI_Affine')
    
    if affine_array is None:
        return None
    
    # Read 16 values and reshape to 4x4
    values = [affine_array.GetValue(i) for i in range(16)]
    affine = np.array(values).reshape(4, 4)
    
    return affine


def apply_transform_to_polydata(polydata, transform_matrix):
    """Apply 4x4 transformation matrix to vtkPolyData.
    
    Args:
        polydata: vtkPolyData object
        transform_matrix: 4x4 numpy array (transformation matrix)
    
    Returns:
        Transformed vtkPolyData
    """
    # Create VTK transform
    transform = vtk.vtkTransform()
    transform.SetMatrix(transform_matrix.flatten())
    
    # Apply transform
    transform_filter = vtk.vtkTransformPolyDataFilter()
    transform_filter.SetInputData(polydata)
    transform_filter.SetTransform(transform)
    transform_filter.Update()
    
    return transform_filter.GetOutput()


if __name__ == '__main__':
    if len(sys.argv) < 3:
        print('Usage: python vmtk_apply_surface_transform.py <input_vtk> <output_vtk> [transform_matrix_file]', file=sys.stderr)
        print('  If transform_matrix_file is provided, it should contain a 4x4 matrix (16 values, space-separated)', file=sys.stderr)
        sys.exit(1)
    
    input_vtk = sys.argv[1]
    output_vtk = sys.argv[2]
    
    # Read input VTK file
    ext = os.path.splitext(input_vtk)[1].lower()
    if ext == '.vtp':
        reader = vtk.vtkXMLPolyDataReader()
    else:
        reader = vtk.vtkPolyDataReader()
    
    reader.SetFileName(input_vtk)
    reader.Update()
    polydata = reader.GetOutput()
    
    # Get transformation matrix
    transform_matrix = None
    
    if len(sys.argv) >= 4:
        # Read from file
        matrix_file = sys.argv[3]
        try:
            with open(matrix_file, 'r') as f:
                values = [float(x) for x in f.read().split()]
                if len(values) == 16:
                    transform_matrix = np.array(values).reshape(4, 4)
        except Exception as e:
            print('Error reading transform matrix file: %s' % e, file=sys.stderr)
            sys.exit(1)
    else:
        # Try to get from FieldData
        transform_matrix = get_affine_from_fielddata(polydata)
        if transform_matrix is not None:
            print('Found NIfTI_Affine in FieldData')
        else:
            print('No transformation matrix found in FieldData and no matrix file provided', file=sys.stderr)
            sys.exit(1)
    
    # Apply transformation
    transformed_polydata = apply_transform_to_polydata(polydata, transform_matrix)
    
    # Write output
    ext_out = os.path.splitext(output_vtk)[1].lower()
    if ext_out == '.vtp':
        writer = vtk.vtkXMLPolyDataWriter()
    else:
        writer = vtk.vtkPolyDataWriter()
    
    writer.SetFileName(output_vtk)
    writer.SetInputData(transformed_polydata)
    writer.Write()
    
    print('Applied transformation and wrote: %s' % output_vtk)
