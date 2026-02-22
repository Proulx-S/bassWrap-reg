#!/usr/bin/env python
# -*- coding: utf-8 -*-
"""
merge_centerlines_coord_tests.py

Produce five VTK files from the same merged centerline geometry, each in a different
coordinate space. Use with two-arg vmtk_viewVolAndSurf(volume_nii, test_k.vtk) to
inspect overlay and determine which space the viewer expects.

Same inputs as merge_centerlines_to_vtk.py: reference, centerlines, niftis, voxel-order.
Output: --output-dir must contain the five test VTKs (test_1_ras.vtk, ...).

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
    voxel_order: 'ijk' -> (p0,p1,p2) as (i,j,k); 'kji' -> (p2,p1,p0) as (i,j,k).
    """
    vessel_affine = np.asarray(vessel_affine, dtype=np.float64)
    npts = polydata.GetNumberOfPoints()
    points = polydata.GetPoints()
    for i in range(npts):
        p = points.GetPoint(i)
        if voxel_order == 'kji':
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


def polydata_from_points_and_template(points_nx3, template_polydata):
    """Build new PolyData with given points and same topology as template (lines/cells)."""
    npts = points_nx3.shape[0]
    pts = vtk.vtkPoints()
    pts.SetNumberOfPoints(npts)
    for i in range(npts):
        pts.SetPoint(i, points_nx3[i, 0], points_nx3[i, 1], points_nx3[i, 2])
    out = vtk.vtkPolyData()
    out.SetPoints(pts)
    out.SetLines(template_polydata.GetLines())
    return out


def transform_points_ras_to_volume_display(points_ras, vol_affine):
    """Same as vmtk_align_surface_to_image: display = inv(R) @ (ras - t)."""
    R = vol_affine[:3, :3]
    t = vol_affine[:3, 3]
    invR = np.linalg.inv(R)
    return (points_ras - t[np.newaxis, :]) @ invR.T


def main():
    parser = argparse.ArgumentParser(
        description='Write five centerline VTKs in different coordinate spaces for overlay tests.'
    )
    parser.add_argument(
        '--reference', '-r', required=True,
        help='Reference NIfTI path (used for ref_affine and ref display/voxel transforms).'
    )
    parser.add_argument(
        '--output-dir', '-o', required=True,
        help='Directory where the five test VTK files will be written.'
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
        help='Order of VTK point (x,y,z) as NIfTI voxel (i,j,k). Default kji.'
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

    # Build combined centerline in RAS (same as merge_centerlines_to_vtk)
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
    npts = combined.GetNumberOfPoints()
    points_ras = np.array([combined.GetPoint(i) for i in range(npts)], dtype=np.float64)

    ref_affine = get_affine_from_nifti(args.reference)
    R_ref = ref_affine[:3, :3]
    t_ref = ref_affine[:3, 3]
    ref_affine_inv = np.linalg.inv(ref_affine)

    os.makedirs(args.output_dir, exist_ok=True)

    # Test 1: RAS (no transform)
    out1 = polydata_from_points_and_template(points_ras, combined)
    write_polydata(out1, os.path.join(args.output_dir, 'test_1_ras.vtk'))
    print('Wrote test_1_ras.vtk')

    # Test 2: ref display = inv(R_ref) @ (ras - t_ref)
    points_display = transform_points_ras_to_volume_display(points_ras, ref_affine)
    out2 = polydata_from_points_and_template(points_display, combined)
    write_polydata(out2, os.path.join(args.output_dir, 'test_2_ref_display.vtk'))
    print('Wrote test_2_ref_display.vtk')

    # Test 3: ref voxel indices = inv(ref_affine) @ [ras; 1]
    ones = np.ones((npts, 1), dtype=np.float64)
    ras_h = np.hstack([points_ras, ones])  # N x 4
    points_ref_voxel = (ref_affine_inv @ ras_h.T).T[:, :3]
    out3 = polydata_from_points_and_template(points_ref_voxel, combined)
    write_polydata(out3, os.path.join(args.output_dir, 'test_3_ref_voxel.vtk'))
    print('Wrote test_3_ref_voxel.vtk')

    # Test 4: LPS = (-x_ras, -y_ras, z_ras)
    points_lps = points_ras.copy()
    points_lps[:, 0] = -points_ras[:, 0]
    points_lps[:, 1] = -points_ras[:, 1]
    out4 = polydata_from_points_and_template(points_lps, combined)
    write_polydata(out4, os.path.join(args.output_dir, 'test_4_lps.vtk'))
    print('Wrote test_4_lps.vtk')

    # Test 5: RAS minus ref origin (translation only)
    points_ras_origin = points_ras - t_ref[np.newaxis, :]
    out5 = polydata_from_points_and_template(points_ras_origin, combined)
    write_polydata(out5, os.path.join(args.output_dir, 'test_5_ras_minus_ref_origin.vtk'))
    print('Wrote test_5_ras_minus_ref_origin.vtk')

    print('Coord tests done. View each with: vmtk_viewVolAndSurf(fTofRef, fullfile(baseDir,''coord_tests'',''test_X_<name>.vtk''))')


if __name__ == '__main__':
    main()
