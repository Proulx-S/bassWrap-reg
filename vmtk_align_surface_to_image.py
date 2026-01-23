#!/usr/bin/env python
# -*- coding: utf-8 -*-
"""
vmtk_align_surface_to_image.py

VMTK script to align a surface to an image by applying coordinate system transformations.
This script reads the transformation matrices from vmtkimagereader and applies appropriate
transformations to ensure the surface aligns with the image.

Usage in VMTK pipeline:
    vmtkimagereader -ifile image.nii.gz \
    --pipe vmtksurfacereader -ifile surface.vtk \
    --pipe vmtk_align_surface_to_image \
    --pipe vmtkrenderer \
    --pipe vmtkimageviewer -i @vmtkimagereader.o -display 0 \
    --pipe vmtksurfaceviewer -i @vmtk_align_surface_to_image.o -display 1
"""

from __future__ import print_function
import sys
import numpy as np

try:
    import vtk
except ImportError:
    print('Error: VTK Python bindings are required.', file=sys.stderr)
    sys.exit(1)

try:
    from vmtk import vmtkscripts
except ImportError:
    print('Error: VMTK Python bindings are required.', file=sys.stderr)
    sys.exit(1)


def get_affine_from_fielddata(polydata):
    """Extract NIfTI affine matrix from VTK PolyData FieldData."""
    field_data = polydata.GetFieldData()
    affine_array = field_data.GetArray('NIfTI_Affine')
    
    if affine_array is None:
        return None
    
    values = [affine_array.GetValue(i) for i in range(16)]
    return np.array(values).reshape(4, 4)


def main():
    # This would be called as part of a VMTK pipeline
    # For now, this is a template that shows the approach
    
    print('vmtk_align_surface_to_image: This script should be integrated into VMTK pipeline')
    print('It would:')
    print('  1. Read transformation matrices from vmtkimagereader output')
    print('  2. Read surface from vmtksurfacereader output')
    print('  3. Check coordinate system metadata in surface FieldData')
    print('  4. Apply appropriate transformation to align surface with image')
    print('  5. Output transformed surface')


if __name__ == '__main__':
    main()
