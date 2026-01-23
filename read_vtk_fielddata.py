#!/usr/bin/env python
# -*- coding: utf-8 -*-
"""
read_vtk_fielddata.py

Read and display FieldData metadata from a VTK PolyData file.
This is useful for debugging coordinate system information stored in VTK files.
"""

from __future__ import print_function
import sys
import os

try:
    import vtk
except ImportError:
    print('Error: VTK Python bindings are required but not installed.', file=sys.stderr)
    print('Install with: pip install vtk', file=sys.stderr)
    sys.exit(1)


def read_vtk_fielddata(vtk_file):
    """Read and display FieldData from VTK PolyData file.
    
    Args:
        vtk_file: Path to VTK file (.vtk or .vtp)
    
    Returns:
        Dictionary with FieldData arrays
    """
    # Read VTK file
    ext = os.path.splitext(vtk_file)[1].lower()
    if ext == '.vtp':
        reader = vtk.vtkXMLPolyDataReader()
    else:
        reader = vtk.vtkPolyDataReader()
    
    reader.SetFileName(vtk_file)
    reader.Update()
    polydata = reader.GetOutput()
    
    field_data = polydata.GetFieldData()
    n_arrays = field_data.GetNumberOfArrays()
    
    metadata = {}
    
    print('FieldData arrays in %s:' % vtk_file)
    print('  Number of arrays: %d' % n_arrays)
    print('')
    
    for i in range(n_arrays):
        array = field_data.GetArray(i)
        array_name = array.GetName()
        array_type = array.GetDataTypeAsString()
        n_components = array.GetNumberOfComponents()
        n_tuples = array.GetNumberOfTuples()
        
        print('  Array %d: %s' % (i, array_name))
        print('    Type: %s' % array_type)
        print('    Components: %d, Tuples: %d' % (n_components, n_tuples))
        
        if array_type == 'double' or array_type == 'float':
            # Numeric array
            values = []
            for j in range(n_components * n_tuples):
                values.append(array.GetValue(j))
            metadata[array_name] = values
            if array_name == 'NIfTI_Affine' and len(values) == 16:
                # Format as 4x4 matrix
                print('    Values (4x4 matrix):')
                for row in range(4):
                    print('      [%8.4f %8.4f %8.4f %8.4f]' % (
                        values[row*4], values[row*4+1], values[row*4+2], values[row*4+3]
                    ))
            else:
                print('    Values: %s' % str(values[:min(10, len(values))]))
        elif array_type == 'string':
            # String array
            values = []
            for j in range(n_tuples):
                values.append(array.GetValue(j))
            metadata[array_name] = values
            print('    Values: %s' % values)
        else:
            print('    Values: (type not displayed)')
        
        print('')
    
    return metadata


if __name__ == '__main__':
    if len(sys.argv) < 2:
        print('Usage: python read_vtk_fielddata.py <vtk_file>', file=sys.stderr)
        sys.exit(1)
    
    vtk_file = sys.argv[1]
    if not os.path.exists(vtk_file):
        print('Error: File not found: %s' % vtk_file, file=sys.stderr)
        sys.exit(1)
    
    metadata = read_vtk_fielddata(vtk_file)
    
    # Print summary
    if metadata:
        print('Summary:')
        for key, value in metadata.items():
            if key == 'NIfTI_Affine':
                print('  %s: 4x4 transformation matrix' % key)
            else:
                print('  %s: %s' % (key, value))
