#!/usr/bin/env python
# -*- coding: utf-8 -*-
"""
vmtk_align_surface_to_image.py

Transform a VTK surface so it aligns with a volume when both are displayed by VMTK.
VMTK's image reader typically places the volume with origin (0,0,0) and uses spacing
(and possibly direction) from the NIfTI. Surface points are assumed to be in RAS
(physical space of the surface's source NIfTI). This script transforms surface points
into the same coordinate system the volume is displayed in, using the volume NIfTI's
affine.

Usage:
    python vmtk_align_surface_to_image.py <volume_nii> <surface_vtk> <output_surface_vtk> [source_nii]

Alignment is only performed when source_nii is passed. Stored spatial info (FieldData
SourceNIfTI) is NOT used by default; if present and source_nii was not passed, a
message is printed explaining how to have alignment applied by passing the source
NIfTI path as the 4th argument.

Dependencies: VTK is always required. nibabel is only required when source_nii is
passed (i.e. when alignment is requested).
"""

from __future__ import print_function
import sys
import os
import numpy as np

try:
    import vtk
except ImportError:
    print('Error: VTK Python bindings are required.', file=sys.stderr)
    sys.exit(1)


def get_affine_from_nifti(nii_file):
    """Return 4x4 affine (voxel to RAS) from NIfTI. Requires nibabel (imported lazily)."""
    import nibabel as nib
    nii = nib.load(nii_file)
    return nii.header.get_best_affine()


def get_affine_from_vtk_fielddata(polydata):
    """Return 4x4 affine from VTK FieldData or None."""
    fd = polydata.GetFieldData()
    arr = fd.GetArray('NIfTI_Affine')
    if arr is None:
        return None
    return np.array([arr.GetValue(i) for i in range(16)]).reshape(4, 4)


def get_source_nifti_from_vtk_fielddata(polydata):
    """Return SourceNIfTI path from VTK FieldData or None."""
    fd = polydata.GetFieldData()
    arr = fd.GetArray('SourceNIfTI')
    if arr is None:
        return None
    return arr.GetValue(0)


def read_polydata(path):
    ext = os.path.splitext(path)[1].lower()
    if ext == '.vtp':
        r = vtk.vtkXMLPolyDataReader()
    else:
        r = vtk.vtkPolyDataReader()
    r.SetFileName(path)
    r.Update()
    return r.GetOutput()


def write_polydata(polydata, path):
    ext = os.path.splitext(path)[1].lower()
    if ext == '.vtp':
        w = vtk.vtkXMLPolyDataWriter()
    else:
        w = vtk.vtkPolyDataWriter()
    w.SetFileName(path)
    w.SetInputData(polydata)
    w.Write()


def transform_points_ras_to_volume_display(points_ras, vol_affine):
    """
    Transform points from RAS to the coordinate system in which the volume
    is displayed by vmtkimagereader (origin 0, spacing/direction from NIfTI).
    Physical position of volume voxel v is vol_affine @ [vx, vy, vz, 1].
    Viewer typically shows that voxel at (vol_affine @ [v,1]) but with origin
    zeroed, so display coords are inv(R) @ (ras - t) = inv(R) @ (point_ras - t).
    """
    R = vol_affine[:3, :3]
    t = vol_affine[:3, 3]
    # point_ras = R @ v + t  =>  v = inv(R) @ (point_ras - t)
    # Display space used by viewer (when origin 0): same as "scaled voxel" space
    # so we want display = inv(R) @ (point_ras - t)
    invR = np.linalg.inv(R)
    points_display = (points_ras - t[np.newaxis, :]) @ invR.T
    return points_display


def _same_file(a, b):
    """True if paths refer to the same file (resolve symlinks, relative, etc.)."""
    if a is None or b is None:
        return False
    return os.path.normpath(os.path.abspath(a)) == os.path.normpath(os.path.abspath(b))


def align_surface_to_volume(volume_nii, surface_vtk, output_vtk, source_nii=None):
    """
    When source_nii is given: transform surface so it aligns with the volume
    (unless volume and source are the same file, then copy). When source_nii is
    not given: do not use FieldData; copy surface unchanged. If VTK has
    SourceNIfTI in FieldData and source_nii was not passed, print a message.
    """
    vol_affine = get_affine_from_nifti(volume_nii)
    polydata = read_polydata(surface_vtk)
    has_fielddata = get_source_nifti_from_vtk_fielddata(polydata) is not None

    # Use stored spatial info only when user explicitly passed source_nii
    if source_nii is None:
        if has_fielddata:
            print(
                'Note: This VTK has spatial metadata (SourceNIfTI in FieldData). '
                'Alignment to the volume was NOT applied by default. To have the '
                'mesh aligned when volume and mesh come from different NIfTIs, '
                'pass the source NIfTI path as the 4th argument (source_nii), e.g.:\n'
                '  vmtk_viewVolAndSurf(volume_nii, surface_vtk, printFlag, source_nii)',
                file=sys.stderr
            )
        write_polydata(polydata, output_vtk)
        return output_vtk

    surface_source = source_nii

    # If surface was created from the same NIfTI we're viewing, no transform needed
    if _same_file(volume_nii, surface_source):
        write_polydata(polydata, output_vtk)
        return output_vtk

    npts = polydata.GetNumberOfPoints()
    points_ras = np.array([polydata.GetPoint(i) for i in range(npts)])
    points_display = transform_points_ras_to_volume_display(points_ras, vol_affine)

    new_points = vtk.vtkPoints()
    for i in range(npts):
        new_points.InsertNextPoint(points_display[i, 0], points_display[i, 1], points_display[i, 2])
    polydata.SetPoints(new_points)
    write_polydata(polydata, output_vtk)
    return output_vtk


def main():
    if len(sys.argv) < 4:
        print('Usage: python vmtk_align_surface_to_image.py <volume_nii> <surface_vtk> <output_surface_vtk> [source_nii]', file=sys.stderr)
        sys.exit(1)
    
    volume_nii = sys.argv[1]
    surface_vtk = sys.argv[2]
    output_vtk = sys.argv[3]
    source_nii = sys.argv[4] if len(sys.argv) > 4 else None
    
    if not os.path.exists(volume_nii):
        print('Error: Volume file not found: %s' % volume_nii, file=sys.stderr)
        sys.exit(1)
    if not os.path.exists(surface_vtk):
        print('Error: Surface file not found: %s' % surface_vtk, file=sys.stderr)
        sys.exit(1)
    
    align_surface_to_volume(volume_nii, surface_vtk, output_vtk, source_nii)
    print('Aligned surface written to: %s' % output_vtk)


if __name__ == '__main__':
    main()
