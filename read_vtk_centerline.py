#!/usr/bin/env python
# -*- coding: utf-8 -*-
"""
read_vtk_centerline.py

Read and analyze VTK PolyData centerline files to understand structure.
Extracts information about points, lines, connectivity, and branching.

Usage:
    python read_vtk_centerline.py <input_vtk_file>
"""

from __future__ import print_function
import sys
import os

try:
    import vtk
except ImportError:
    print('Error: VTK Python bindings not found. Install with: pip install vtk', file=sys.stderr)
    sys.exit(1)


def read_vtk_centerline(vtk_file):
    """Read VTK PolyData file and extract structure information."""
    if not os.path.exists(vtk_file):
        print('Error: File not found: %s' % vtk_file, file=sys.stderr)
        sys.exit(1)
    
    # Determine file type and use appropriate reader
    ext = os.path.splitext(vtk_file)[1].lower()
    if ext == '.vtp':
        reader = vtk.vtkXMLPolyDataReader()
    else:
        reader = vtk.vtkPolyDataReader()
    
    reader.SetFileName(vtk_file)
    reader.Update()
    polydata = reader.GetOutput()
    
    # Extract basic information
    num_points = polydata.GetNumberOfPoints()
    num_cells = polydata.GetNumberOfCells()
    
    print('=' * 60)
    print('VTK Centerline File Analysis')
    print('=' * 60)
    print('File: %s' % vtk_file)
    print('Number of points: %d' % num_points)
    print('Number of cells (lines): %d' % num_cells)
    print()
    
    # Analyze points
    print('Points:')
    print('  Total: %d' % num_points)
    if num_points > 0:
        # Get first and last point coordinates
        p0 = polydata.GetPoint(0)
        p_last = polydata.GetPoint(num_points - 1)
        print('  First point: (%.3f, %.3f, %.3f)' % p0)
        print('  Last point:  (%.3f, %.3f, %.3f)' % p_last)
    print()
    
    # Analyze lines/cells
    print('Lines (Cells):')
    print('  Total: %d' % num_cells)
    
    # Count points per line and identify branching
    points_per_line = []
    line_point_ids = []
    
    for i in range(num_cells):
        cell = polydata.GetCell(i)
        if cell.GetCellType() == vtk.VTK_LINE or cell.GetCellType() == vtk.VTK_POLY_LINE:
            num_pts = cell.GetNumberOfPoints()
            points_per_line.append(num_pts)
            
            # Get point IDs for this line
            ids = []
            for j in range(num_pts):
                ids.append(cell.GetPointId(j))
            line_point_ids.append(ids)
    
    if points_per_line:
        print('  Points per line: min=%d, max=%d, mean=%.1f' % (
            min(points_per_line), max(points_per_line), 
            sum(points_per_line) / len(points_per_line)
        ))
    
    # Analyze connectivity and branching
    print()
    print('Connectivity Analysis:')
    
    # Count how many lines share each point (degree)
    point_degree = [0] * num_points
    for line_ids in line_point_ids:
        for pt_id in line_ids:
            point_degree[pt_id] += 1
    
    # Identify node types
    endpoints = [i for i, deg in enumerate(point_degree) if deg == 1]
    junctions = [i for i, deg in enumerate(point_degree) if deg > 2]
    regular = [i for i, deg in enumerate(point_degree) if deg == 2]
    
    print('  Endpoints (degree=1): %d' % len(endpoints))
    print('  Junctions (degree>2): %d' % len(junctions))
    print('  Regular points (degree=2): %d' % len(regular))
    
    if junctions:
        print('  Branching detected!')
        print('  Junction point indices: %s' % str(junctions[:10]) + 
              ('...' if len(junctions) > 10 else ''))
    
    # Analyze point data arrays
    print()
    print('Point Data Arrays:')
    point_data = polydata.GetPointData()
    num_arrays = point_data.GetNumberOfArrays()
    print('  Number of arrays: %d' % num_arrays)
    
    for i in range(num_arrays):
        array = point_data.GetArray(i)
        if array:
            print('  [%d] %s: %s (%d components)' % (
                i, array.GetName(), 
                vtk.vtkDataArray.GetDataTypeName(array.GetDataType()),
                array.GetNumberOfComponents()
            ))
    
    # Summary
    print()
    print('=' * 60)
    print('Summary:')
    print('  This VTK file represents a centerline with %d points' % num_points)
    print('  organized into %d line segments.' % num_cells)
    if junctions:
        print('  Branching structure detected with %d junction points.' % len(junctions))
    else:
        print('  No branching detected (single path).')
    print('=' * 60)
    
    return {
        'num_points': num_points,
        'num_cells': num_cells,
        'points_per_line': points_per_line,
        'endpoints': endpoints,
        'junctions': junctions,
        'point_degree': point_degree
    }


def main():
    if len(sys.argv) < 2:
        print('Usage: python read_vtk_centerline.py <input_vtk_file>', file=sys.stderr)
        sys.exit(1)
    
    vtk_file = sys.argv[1]
    read_vtk_centerline(vtk_file)


if __name__ == '__main__':
    main()
