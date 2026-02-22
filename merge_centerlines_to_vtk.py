#!/usr/bin/env python
# -*- coding: utf-8 -*-
"""
merge_centerlines_to_vtk.py

Merge multiple vessel centerline VTK files into a single VTK file. Transforms each
centerline from vessel-image voxel space to physical (RAS) and appends. Output is
in scanner RAS (mm). For correct overlay in vmtk_viewVolAndSurf without source_nii,
call vmtk_viewVolAndSurf(volume_nii, surface_vtk, 0, reference_nii) so the surface
is aligned to the volume, or run vmtk_align_surface_to_image once on the combined file.

vmtkactivetubes outputs centerlines in the image (voxel) space of -imagefile;
each vessel crop has a different origin, so we apply vessel_affine to get scanner RAS.

Voxel order: NIfTI affine expects (i, j, k). VTK/ITK may output (x,y,z) as (k,j,i).
Use --voxel-order kji if the result looks too thin in the slice direction.

Usage:
    python merge_centerlines_to_vtk.py --reference ref.nii.gz --output combined.vtk \\
        [--voxel-order ijk|kji] --centerlines c1.vtk ... --niftis n1.nii.gz ...

Dependencies: VTK, nibabel.
"""

from __future__ import print_function
import argparse
import os
import sys
import numpy as np

try:
    import vtk
except ImportError:
    print('Error: VTK Python bindings are required.', file=sys.stderr)
    sys.exit(1)

try:
    import nibabel as nib
except ImportError:
    print('Error: nibabel is required.', file=sys.stderr)
    sys.exit(1)


def get_affine_from_nifti(nii_path):
    """Return 4x4 affine (voxel to RAS) from NIfTI."""
    nii = nib.load(nii_path)
    return np.asarray(nii.header.get_best_affine(), dtype=np.float64)


def voxel_to_ras(polydata, vessel_affine, voxel_order='kji'):
    """
    Transform polydata points from vessel voxel space to physical (RAS). In place.
    voxel_order: 'ijk' -> use (p0, p1, p2) as (i,j,k); 'kji' -> use (p2, p1, p0) as (i,j,k).
    """
    vessel_affine = np.asarray(vessel_affine, dtype=np.float64)
    npts = polydata.GetNumberOfPoints()
    points = polydata.GetPoints()
    for i in range(npts):
        p = points.GetPoint(i)
        if voxel_order == 'kji':
            # VTK/ITK often use (z,y,x) = (k,j,i) vs NIfTI (i,j,k)
            ijk = np.array([p[2], p[1], p[0], 1.0], dtype=np.float64)
        else:
            ijk = np.array([p[0], p[1], p[2], 1.0], dtype=np.float64)
        p_ras = (vessel_affine @ ijk)[:3]
        points.SetPoint(i, p_ras[0], p_ras[1], p_ras[2])
    polydata.SetPoints(points)


def read_polydata(path):
    """Read VTK or VTP PolyData."""
    ext = os.path.splitext(path)[1].lower()
    if ext == '.vtp':
        reader = vtk.vtkXMLPolyDataReader()
    else:
        reader = vtk.vtkPolyDataReader()
    reader.SetFileName(path)
    reader.Update()
    return reader.GetOutput()


def write_polydata(polydata, path):
    """Write PolyData to VTK or VTP."""
    ext = os.path.splitext(path)[1].lower()
    if ext == '.vtp':
        writer = vtk.vtkXMLPolyDataWriter()
    else:
        writer = vtk.vtkPolyDataWriter()
    writer.SetFileName(path)
    writer.SetInputData(polydata)
    writer.Write()


def main():
    parser = argparse.ArgumentParser(
        description='Merge vessel centerline VTKs into one VTK; output in scanner RAS (mm).'
    )
    parser.add_argument(
        '--reference', '-r', required=True,
        help='Reference NIfTI path (validated only); output is in RAS, use 4-arg vmtk_viewVolAndSurf for overlay.'
    )
    parser.add_argument(
        '--output', '-o', required=True,
        help='Output combined centerline VTK path.'
    )
    parser.add_argument(
        '--centerlines', '-c', nargs='+', required=True,
        help='Paths to centerline VTK files (one per vessel).'
    )
    parser.add_argument(
        '--niftis', '-n', nargs='+', required=True,
        help='Paths to vessel NIfTI files (same order as centerlines; used for voxel->RAS).'
    )
    parser.add_argument(
        '--voxel-order', choices=('ijk', 'kji'), default='kji',
        help='Order of VTK point (x,y,z) as NIfTI voxel (i,j,k). Default kji (fixes thin slice).'
    )
    args = parser.parse_args()

    if len(args.centerlines) != len(args.niftis):
        print(
            'Error: Number of centerlines (%d) must match number of niftis (%d).' % (
                len(args.centerlines), len(args.niftis)
            ),
            file=sys.stderr
        )
        sys.exit(1)

    if not os.path.exists(args.reference):
        print('Error: Reference NIfTI not found: %s' % args.reference, file=sys.stderr)
        sys.exit(1)

    append_filter = vtk.vtkAppendPolyData()

    for cl_path, nii_path in zip(args.centerlines, args.niftis):
        if not os.path.exists(cl_path):
            print('Error: Centerline not found: %s' % cl_path, file=sys.stderr)
            sys.exit(1)
        if not os.path.exists(nii_path):
            print('Error: NIfTI not found: %s' % nii_path, file=sys.stderr)
            sys.exit(1)
        vessel_affine = get_affine_from_nifti(nii_path)
        polydata = read_polydata(cl_path)
        voxel_to_ras(polydata, vessel_affine, voxel_order=args.voxel_order)
        append_filter.AddInputData(polydata)

    append_filter.Update()
    combined = append_filter.GetOutput()

    out_dir = os.path.dirname(args.output)
    if out_dir and not os.path.isdir(out_dir):
        os.makedirs(out_dir)

    write_polydata(combined, args.output)
    print('Wrote combined centerlines: %s (%d points, %d cells)' % (
        args.output, combined.GetNumberOfPoints(), combined.GetNumberOfCells()
    ))


if __name__ == '__main__':
    main()
