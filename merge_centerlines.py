#!/usr/bin/env python
# -*- coding: utf-8 -*-
"""
merge_centerlines.py

Merge multiple centerline VTK files into a single VTK file. No coordinate transform:
each file is appended as-is (vtkAppendPolyData). Use when inputs are already in
a common space or when only concatenation is needed.

Usage:
    python merge_centerlines.py --output combined.vtk --centerlines c1.vtk c2.vtk ...

Dependencies: VTK.
"""

from __future__ import print_function
import argparse
import os
import sys

try:
    import vtk
except ImportError:
    print('Error: VTK Python bindings are required.', file=sys.stderr)
    sys.exit(1)


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
        description='Merge centerline VTK files into one (no coordinate transform).'
    )
    parser.add_argument(
        '--output', '-o', required=True,
        help='Output combined VTK path.'
    )
    parser.add_argument(
        '--centerlines', '-c', nargs='+', required=True,
        help='Paths to centerline VTK files.'
    )
    args = parser.parse_args()

    append_filter = vtk.vtkAppendPolyData()
    for cl_path in args.centerlines:
        if not os.path.exists(cl_path):
            print('Error: Centerline not found: %s' % cl_path, file=sys.stderr)
            sys.exit(1)
        polydata = read_polydata(cl_path)
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
