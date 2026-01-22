#!/usr/bin/env python
# -*- coding: utf-8 -*-
"""
points_to_vtk_centerline.py

Convert a list of 3D point coordinates to VTK PolyData centerline format.

Usage:
    python points_to_vtk_centerline.py <input_file> <output_file>

Input file format:
    One point per line: x y z
    (space or comma separated)

Output:
    Binary VTK PolyData file (.vtk) with a single polyline connecting all points sequentially.
"""

from __future__ import print_function
import os
import sys


def parse_points_file(path):
    """Read points from text file.
    Expects lines with at least 3 floats (x y z or x,y,z); extra columns ignored.
    Skips empty lines and comment lines starting with #.
    """
    points = []
    try:
        with open(path, 'r') as f:
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
        sys.exit(1)

    return points


def points_to_vtk_polydata(points, out_path):
    """Write an ordered list of 3D points as a single VTK polyline."""
    try:
        import vtk
    except ImportError:
        raise RuntimeError('vtk module not found. VTK Python bindings are required.')

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

    # Write as binary VTK (legacy format)
    ext = os.path.splitext(out_path)[1].lower()
    if ext == '.vtp':
        w = vtk.vtkXMLPolyDataWriter()
    else:
        w = vtk.vtkPolyDataWriter()
    w.SetFileName(out_path)
    w.SetInputData(pd)
    w.Write()


def main():
    if len(sys.argv) < 3:
        print('Usage: python points_to_vtk_centerline.py <input_file> <output_file>', file=sys.stderr)
        sys.exit(1)

    input_file = sys.argv[1]
    output_file = sys.argv[2]

    if not os.path.exists(input_file):
        print('Error: Input file not found: %s' % input_file, file=sys.stderr)
        sys.exit(1)

    # Ensure output directory exists
    output_dir = os.path.dirname(output_file)
    if output_dir and not os.path.exists(output_dir):
        os.makedirs(output_dir)

    # Parse points from input file
    points = parse_points_file(input_file)
    
    if len(points) < 2:
        print('Error: Need at least 2 points; found %d' % len(points), file=sys.stderr)
        sys.exit(1)

    # Write VTK file
    try:
        points_to_vtk_polydata(points, output_file)
        print('Wrote centerline to %s (%d points)' % (output_file, len(points)))
    except Exception as e:
        print('Error writing VTK file: %s' % str(e), file=sys.stderr)
        sys.exit(1)


if __name__ == '__main__':
    main()
