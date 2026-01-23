#!/usr/bin/env python
# -*- coding: utf-8 -*-
"""
skeleton_to_graph_vtk.py

Extract full graph structure (nodes and edges) from skeleton mask and output
as VTK PolyData centerline format compatible with vmtkcenterlines.

This script builds a graph where each skeleton voxel is a node and edges
connect adjacent voxels, preserving branching structure.

The output VTK file includes coordinate system metadata in FieldData:
- NIfTI_Affine: 4x4 transformation matrix from voxel to RAS coordinates
- CoordinateSystem: Identifier of the coordinate system used (RAS or xyz)
- SourceNIfTI: Path to the source NIfTI file

Usage:
    python skeleton_to_graph_vtk.py <input_skeleton_nii> <output_vtk> [--connectivity 26] [--coordinate-system ras]
"""

from __future__ import print_function
import sys
import os
import argparse
import numpy as np

try:
    import nibabel as nib
except ImportError:
    print('Error: nibabel is required. Install with: pip install nibabel', file=sys.stderr)
    print('Or use a Neurodesk container with nibabel (e.g., nipype/1.8.3)', file=sys.stderr)
    sys.exit(1)

try:
    import vtk
except ImportError:
    print('Error: VTK Python bindings are required but not installed.', file=sys.stderr)
    print('Install with: pip install vtk', file=sys.stderr)
    print('Or use a Python environment that includes VTK.', file=sys.stderr)
    sys.exit(1)


def voxel_to_ras_coords(voxel_coords, affine):
    """Convert voxel coordinates to RAS coordinates using NIfTI affine matrix.
    
    Args:
        voxel_coords: Nx3 array of voxel coordinates (0-based)
        affine: 4x4 affine transformation matrix from NIfTI header
    
    Returns:
        Nx3 array of RAS coordinates
    """
    # Convert to homogeneous coordinates
    n = voxel_coords.shape[0]
    homogeneous_voxel = np.ones((n, 4))
    homogeneous_voxel[:, :3] = voxel_coords
    
    # Apply affine transformation
    homogeneous_ras = (affine @ homogeneous_voxel.T).T
    
    # Return first 3 columns (RAS coordinates)
    return homogeneous_ras[:, :3]


def voxel_to_xyz_coords(voxel_coords, affine):
    """Convert voxel coordinates to xyz (physical) coordinates as vmtk does.
    
    vmtk uses xyz space where: xyz = origin + (voxel * spacing)
    This is the coordinate system that vmtkcenterlines expects for centerlines.
    
    Args:
        voxel_coords: Nx3 array of voxel coordinates (0-based)
        affine: 4x4 affine transformation matrix from NIfTI header
    
    Returns:
        Nx3 array of xyz coordinates (physical space, matching vmtk convention)
    """
    # Extract spacing and origin from affine matrix
    spacing = np.array([
        np.linalg.norm(affine[:3, 0]),
        np.linalg.norm(affine[:3, 1]),
        np.linalg.norm(affine[:3, 2])
    ])
    origin = affine[:3, 3]
    
    # vmtk's xyz space: xyz = origin + (voxel * spacing)
    xyz_coords = origin[np.newaxis, :] + (voxel_coords * spacing[np.newaxis, :])
    
    return xyz_coords


def build_graph_from_skeleton(skeleton_data, connectivity=26):
    """Build graph from skeleton where each non-zero voxel is a node.
    
    Args:
        skeleton_data: 3D binary array (skeleton mask)
        connectivity: 6, 18, or 26 (default: 26 for 3D)
    
    Returns:
        nodes: Nx3 array of voxel coordinates (0-based)
        edges: List of edge tuples (node_idx1, node_idx2)
    """
    # Find all non-zero voxel coordinates
    coords = np.argwhere(skeleton_data > 0)
    n_nodes = len(coords)
    
    if n_nodes == 0:
        return np.array([]), []
    
    # Create mapping from coordinate to node index
    coord_to_idx = {}
    for idx, coord in enumerate(coords):
        coord_to_idx[tuple(coord)] = idx
    
    # Define neighbors based on connectivity
    if connectivity == 6:
        # 6-connectivity: face neighbors only
        offsets = [
            (-1, 0, 0), (1, 0, 0),
            (0, -1, 0), (0, 1, 0),
            (0, 0, -1), (0, 0, 1)
        ]
    elif connectivity == 18:
        # 18-connectivity: face + edge neighbors
        offsets = [
            (-1, 0, 0), (1, 0, 0),
            (0, -1, 0), (0, 1, 0),
            (0, 0, -1), (0, 0, 1),
            (-1, -1, 0), (-1, 1, 0), (1, -1, 0), (1, 1, 0),
            (-1, 0, -1), (-1, 0, 1), (1, 0, -1), (1, 0, 1),
            (0, -1, -1), (0, -1, 1), (0, 1, -1), (0, 1, 1)
        ]
    else:  # connectivity == 26
        # 26-connectivity: all neighbors (face + edge + corner)
        offsets = []
        for dx in [-1, 0, 1]:
            for dy in [-1, 0, 1]:
                for dz in [-1, 0, 1]:
                    if (dx, dy, dz) != (0, 0, 0):
                        offsets.append((dx, dy, dz))
    
    # Build edges by checking neighbors
    edges = []
    shape = skeleton_data.shape
    
    for idx, coord in enumerate(coords):
        x, y, z = coord
        for dx, dy, dz in offsets:
            nx, ny, nz = x + dx, y + dy, z + dz
            
            # Check bounds
            if (0 <= nx < shape[0] and 0 <= ny < shape[1] and 0 <= nz < shape[2]):
                neighbor_coord = (nx, ny, nz)
                if neighbor_coord in coord_to_idx:
                    neighbor_idx = coord_to_idx[neighbor_coord]
                    # Add edge (only once, with smaller index first)
                    if idx < neighbor_idx:
                        edges.append((idx, neighbor_idx))
    
    return coords, edges


def graph_to_vtk_polydata(nodes_coords, edges, output_path, affine=None, coord_system='RAS', source_nii=None):
    """Convert graph (nodes and edges) to VTK PolyData format with coordinate system metadata.
    
    Args:
        nodes_coords: Nx3 array of coordinates (RAS or xyz)
        edges: List of edge tuples (node_idx1, node_idx2)
        output_path: Path to output VTK file (.vtk or .vtp)
        affine: Optional 4x4 affine transformation matrix from NIfTI header
        coord_system: Coordinate system identifier (e.g., 'RAS', 'xyz')
        source_nii: Optional path to source NIfTI file for reference
    """
    
    # Create points
    points = vtk.vtkPoints()
    for node in nodes_coords:
        points.InsertNextPoint(node[0], node[1], node[2])
    
    # Create lines (each edge becomes a line segment)
    lines = vtk.vtkCellArray()
    for edge in edges:
        line = vtk.vtkLine()
        line.GetPointIds().SetId(0, edge[0])
        line.GetPointIds().SetId(1, edge[1])
        lines.InsertNextCell(line)
    
    # Create PolyData
    polydata = vtk.vtkPolyData()
    polydata.SetPoints(points)
    polydata.SetLines(lines)
    
    # Add coordinate system metadata to FieldData
    if affine is not None:
        field_data = polydata.GetFieldData()
        
        # Store NIfTI affine transformation matrix (4x4 = 16 values)
        affine_array = vtk.vtkDoubleArray()
        affine_array.SetName('NIfTI_Affine')
        affine_array.SetNumberOfComponents(16)
        affine_array.SetNumberOfTuples(1)
        # Flatten affine matrix row-major (as VTK expects)
        affine_flat = affine.flatten(order='C')
        for i in range(16):
            affine_array.SetValue(i, affine_flat[i])
        field_data.AddArray(affine_array)
        
        # Store coordinate system identifier
        coord_array = vtk.vtkStringArray()
        coord_array.SetName('CoordinateSystem')
        coord_array.SetNumberOfValues(1)
        coord_array.SetValue(0, coord_system)
        field_data.AddArray(coord_array)
        
        # Store source NIfTI file path if provided
        if source_nii is not None:
            source_array = vtk.vtkStringArray()
            source_array.SetName('SourceNIfTI')
            source_array.SetNumberOfValues(1)
            source_array.SetValue(0, source_nii)
            field_data.AddArray(source_array)
    
    # Write to file
    ext = os.path.splitext(output_path)[1].lower()
    if ext == '.vtp':
        writer = vtk.vtkXMLPolyDataWriter()
    else:
        writer = vtk.vtkPolyDataWriter()
    
    writer.SetFileName(output_path)
    writer.SetInputData(polydata)
    writer.Write()




def main():
    parser = argparse.ArgumentParser(
        description='Extract graph from skeleton mask and output as VTK centerline'
    )
    parser.add_argument('input_nii', help='Input skeleton NIfTI file (binary mask)')
    parser.add_argument('output_vtk', help='Output VTK PolyData file (.vtk or .vtp)')
    parser.add_argument(
        '--connectivity', type=int, default=26,
        choices=[6, 18, 26],
        help='Voxel connectivity (6, 18, or 26, default: 26)'
    )
    parser.add_argument(
        '--coordinate-system', type=str, default='ras',
        choices=['ras', 'xyz'],
        help='Output coordinate system: "ras" (RAS space, default) or "xyz" (vmtk physical space). '
             'RAS is the standard NIfTI coordinate system. The NIfTI affine transformation matrix '
             'is always stored in VTK FieldData for reference.'
    )
    parser.add_argument(
        '--validate-coords', action='store_true',
        help='Print coordinate system validation information (first few points in both systems)'
    )
    
    args = parser.parse_args()
    
    # Check input file
    if not os.path.exists(args.input_nii):
        print('Error: Input file not found: %s' % args.input_nii, file=sys.stderr)
        sys.exit(1)
    
    # Ensure output directory exists
    output_dir = os.path.dirname(args.output_vtk)
    if output_dir and not os.path.exists(output_dir):
        os.makedirs(output_dir)
    
    # Build graph from skeleton
    print('Loading skeleton from: %s' % args.input_nii)
    nii = nib.load(args.input_nii)
    skeleton_data = nii.get_fdata()
    
    # Use the best affine from the input file header
    # This ensures we use qform if available, otherwise sform
    affine = nii.header.get_best_affine()
    print('Using best affine from input file header')
    
    # Binarize (ensure it's 0/1)
    skeleton_data = (skeleton_data > 0).astype(np.uint8)
    
    num_voxels = np.sum(skeleton_data)
    print('Skeleton voxels: %d' % num_voxels)
    
    if num_voxels == 0:
        print('Error: Skeleton mask is empty', file=sys.stderr)
        sys.exit(1)
    
    # Build graph from skeleton
    print('Building graph from skeleton (connectivity=%d)...' % args.connectivity)
    nodes_voxel, edges = build_graph_from_skeleton(skeleton_data, args.connectivity)
    
    if len(nodes_voxel) == 0:
        print('Error: No nodes found in skeleton', file=sys.stderr)
        sys.exit(1)
    
    print('Graph: %d nodes, %d edges' % (len(nodes_voxel), len(edges)))
    
    # Convert voxel coordinates to output coordinate system
    if args.coordinate_system == 'xyz':
        # Use xyz space (vmtk physical space) to match vmtkcenterlines output
        print('Converting voxel coordinates to xyz space (vmtk physical space)...')
        nodes_coords = voxel_to_xyz_coords(nodes_voxel, affine)
        coord_system_name = 'xyz'
    else:
        # Use RAS space (standard NIfTI coordinate system)
        print('Converting voxel coordinates to RAS space...')
        nodes_coords = voxel_to_ras_coords(nodes_voxel, affine)
        coord_system_name = 'RAS'
    
    # Coordinate system validation (if requested)
    if args.validate_coords and len(nodes_voxel) > 0:
        print('\nCoordinate system validation:')
        print('  Affine matrix shape: %s' % str(affine.shape))
        print('  First 3 voxel coordinates:')
        for i in range(min(3, len(nodes_voxel))):
            print('    Voxel[%d]: %s' % (i, nodes_voxel[i]))
        print('  First 3 %s coordinates:' % coord_system_name)
        for i in range(min(3, len(nodes_coords))):
            print('    %s[%d]: %s' % (coord_system_name, i, nodes_coords[i]))
        # Also show what RAS would be if using xyz
        if args.coordinate_system == 'xyz':
            nodes_ras_check = voxel_to_ras_coords(nodes_voxel[:min(3, len(nodes_voxel))], affine)
            print('  First 3 RAS coordinates (for comparison):')
            for i in range(len(nodes_ras_check)):
                print('    RAS[%d]: %s' % (i, nodes_ras_check[i]))
        print('')
    
    # Write VTK file with coordinate system metadata
    print('Writing VTK PolyData to: %s' % args.output_vtk)
    graph_to_vtk_polydata(nodes_coords, edges, args.output_vtk, 
                         affine=affine, coord_system=coord_system_name, 
                         source_nii=args.input_nii)
    
    print('Success! Created VTK centerline with %d points and %d line segments (coordinate system: %s)' % (
        len(nodes_coords), len(edges), coord_system_name
    ))
    if affine is not None:
        print('  Coordinate system metadata stored in VTK FieldData:')
        print('    - NIfTI_Affine: 4x4 transformation matrix')
        print('    - CoordinateSystem: %s' % coord_system_name)
        print('    - SourceNIfTI: %s' % args.input_nii)


if __name__ == '__main__':
    main()
