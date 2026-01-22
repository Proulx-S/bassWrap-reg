#!/usr/bin/env python
# -*- coding: utf-8 -*-
"""
slicer_extract_skeleton_to_vtk.py

Run inside 3D Slicer (--no-main-window --python-script) to:
  1. Load a binary mask NIfTI
  2. Run ExtractSkeleton (1D centerline, optional fullTree)
  3. Read the output points file
  4. Write a VTK PolyData centerline (.vtk or .vtp)

All coordinate handling is done by Slicer/ExtractSkeleton; this script
only formats points into VTK. No manual transform or vox2ras.

Usage (from shell):
  Slicer --no-splash --no-main-window --python-script /path/to/slicer_extract_skeleton_to_vtk.py -- INPUT_NII OUTPUT_VTK [--fullTree] [--numPoints N]

  On Linux without display, prefix with:  xvfb-run -a

Arguments:
  INPUT_NII   : Binary mask or skeleton NIfTI (non-zero = foreground)
  OUTPUT_VTK  : Output VTK PolyData file (.vtk or .vtp)
  --fullTree  : (optional) Include full skeleton tree; default: maximal center only
  --numPoints : (optional) Number of skeleton points (default: 100)
  --inCoordinates : (optional) 'ras' (default) or 'lps'. ExtractSkeleton outputs in the
    volume's coordinate system (typically RAS). Use 'ras' for no conversion. If centerlines
    are misaligned, try 'lps' to apply LPS→RAS conversion.
"""

from __future__ import print_function
import os
import sys
import tempfile


def _parse_points_file(path):
    """Read points from ExtractSkeleton --pointsFile output.
    Expects lines with at least 3 floats (x y z or x,y,z); extra columns ignored.
    Skips empty lines and header-like lines.
    """
    points = []
    try:
        # Use latin-1 encoding (permissive, can read any byte sequence) to avoid Unicode errors
        with open(path, 'r', encoding='latin-1', errors='replace') as f:
            for line in f:
                line = line.strip()
                if not line or line.startswith('#'):
                    continue
                # Support both space- and comma-separated
                parts = line.replace(',', ' ').split()
                floats = []
                for i, p in enumerate(parts):
                    if i >= 3:
                        break
                    try:
                        floats.append(float(p))
                    except ValueError:
                        break
                if len(floats) >= 3:
                    points.append(floats[:3])
    except Exception as e:
        print('Error reading points file %s: %s' % (path, e), file=sys.stderr)
        raise
    return points


def _points_to_vtk_polydata(points, out_path):
    """Write an ordered list of 3D points as a single VTK polyline."""
    try:
        import vtk
    except ImportError:
        # Slicer embeds VTK; if this fails we are not running inside Slicer
        raise RuntimeError('vtk module not found. This script must be run with: Slicer --python-script ...')

    if len(points) < 2:
        raise ValueError('Need at least 2 points to write a polyline; got %d' % len(points))

    pts = vtk.vtkPoints()
    for p in points:
        pts.InsertNextPoint(p[0], p[1], p[2])

    # One polyline: cell with n points, indices 0..n-1
    n = len(points)
    cell = vtk.vtkPolyLine()
    cell.GetPointIds().SetNumberOfIds(n)
    for i in range(n):
        cell.GetPointIds().SetId(i, i)

    ca = vtk.vtkCellArray()
    ca.InsertNextCell(cell)

    pd = vtk.vtkPolyData()
    pd.SetPoints(pts)
    pd.SetLines(ca)

    ext = os.path.splitext(out_path)[1].lower()
    if ext == '.vtp':
        w = vtk.vtkXMLPolyDataWriter()
    else:
        w = vtk.vtkPolyDataWriter()
    w.SetFileName(out_path)
    w.SetInputData(pd)
    w.Write()


def main():
    argv = sys.argv
    if '--' in argv:
        idx = argv.index('--')
        args = argv[idx + 1:]
    else:
        # If launched without --, take all after script path
        args = argv[1:]

    if len(args) < 2:
        print('Usage: Slicer --no-main-window --python-script slicer_extract_skeleton_to_vtk.py -- INPUT_NII OUTPUT_VTK [--fullTree] [--numPoints N]', file=sys.stderr)
        sys.exit(1)

    input_nii = os.path.abspath(args[0])
    output_vtk = os.path.abspath(args[1])
    full_tree = '--fullTree' in args
    num_points = 100
    in_coords = 'ras'  # ExtractSkeleton outputs in volume's coord system (typically RAS)
    i = 0
    while i < len(args):
        a = args[i]
        if a == '--numPoints' and i + 1 < len(args):
            try:
                num_points = int(args[i + 1])
            except ValueError:
                pass
            i += 2
            continue
        if a == '--inCoordinates' and i + 1 < len(args):
            v = (args[i + 1] or '').lower()
            if v in ('lps', 'ras'):
                in_coords = v
            i += 2
            continue
        i += 1

    if not os.path.isfile(input_nii):
        print('Error: Input file not found: %s' % input_nii, file=sys.stderr)
        sys.exit(1)

    out_dir = os.path.dirname(output_vtk)
    if out_dir and not os.path.isdir(out_dir):
        os.makedirs(out_dir, exist_ok=True)

    try:
        import slicer
    except ImportError:
        print('Error: slicer module not found. Run with: Slicer --no-main-window --python-script ...', file=sys.stderr)
        sys.exit(1)

    # Load volume (slicer.util.loadVolume returns node or list of nodes)
    vol = slicer.util.loadVolume(input_nii)
    if vol is None:
        print('Error: Could not load volume: %s' % input_nii, file=sys.stderr)
        sys.exit(1)
    if isinstance(vol, (list, tuple)):
        vol = vol[0] if vol else None
    if vol is None:
        print('Error: Could not load volume: %s' % input_nii, file=sys.stderr)
        sys.exit(1)

    # Outputs for ExtractSkeleton: use output dir for points (avoids /tmp sandbox issues)
    tmp = tempfile.mkdtemp(prefix='slicer_skel_')
    out_skeleton = os.path.join(tmp, 'skeleton.nii.gz')
    out_points = os.path.join(out_dir, '_slicer_skel_points.txt') if out_dir else os.path.join(tmp, 'points.txt')

    parameters = {
        'InputImageFileName': vol.GetID(),
        'OutputImageFileName': out_skeleton,
        'SkeletonType': '1D',
        'FullTree': full_tree,
        'NumberOfPoints': num_points,
        'OutputPointsFileName': out_points,
    }

    ok = slicer.cli.runSync(slicer.modules.extractskeleton, None, parameters)
    if not ok:
        print('Error: ExtractSkeleton failed.', file=sys.stderr)
        _cleanup(tmp)
        _remove(out_points)
        sys.exit(1)

    # Resolve points file: requested path, or cwd (CLI may write to cwd on some setups)
    if not os.path.isfile(out_points):
        out_points = os.path.join(os.getcwd(), 'points.txt')
    if not os.path.isfile(out_points):
        try:
            ls = os.listdir(tmp)
        except Exception:
            ls = []
        print('Error: ExtractSkeleton did not produce a points file at %s (or cwd/points.txt). Temp dir contents: %s' % (out_points, ls), file=sys.stderr)
        _cleanup(tmp)
        _remove(out_points)
        sys.exit(1)
    if os.path.getsize(out_points) == 0:
        print('Error: ExtractSkeleton points file is empty (skeleton may have 0 or 1 point).', file=sys.stderr)
        _cleanup(tmp)
        _remove(out_points)
        sys.exit(1)

    points = _parse_points_file(out_points)
    _cleanup(tmp)
    _remove(out_points)

    if len(points) < 2:
        print('Error: Extracted points file has fewer than 2 points.', file=sys.stderr)
        sys.exit(1)

    # Slicer writes disk coordinates in LPS; NIfTI/vmtkimagereader use RAS. Convert if lps.
    if in_coords == 'lps':
        for p in points:
            p[0] = -float(p[0])
            p[1] = -float(p[1])

    _points_to_vtk_polydata(points, output_vtk)
    print('Wrote centerline to %s (%d points)' % (output_vtk, len(points)))


def _cleanup(tmp):
    try:
        import shutil
        if os.path.isdir(tmp):
            shutil.rmtree(tmp, ignore_errors=True)
    except Exception:
        pass


def _remove(path):
    try:
        if path and os.path.isfile(path):
            os.remove(path)
    except Exception:
        pass


if __name__ == '__main__':
    main()
    sys.exit(0)
