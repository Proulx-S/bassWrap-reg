#!/usr/bin/env python
# -*- coding: utf-8 -*-
"""
skeleton_to_graph_vtk.py

Extract full graph structure (nodes and edges) from skeleton mask and output
as VTK PolyData centerline format compatible with vmtkcenterlines.

This script builds a graph where each skeleton voxel is a node and edges
connect adjacent voxels, preserving branching structure.

Usage:
    python skeleton_to_graph_vtk.py <input_skeleton_nii> <output_vtk> [--connectivity 26]
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


def graph_to_vtk_polydata(nodes_ras, edges, output_path):
    """Convert graph (nodes and edges) to VTK PolyData format.
    
    Args:
        nodes_ras: Nx3 array of RAS coordinates
        edges: List of edge tuples (node_idx1, node_idx2)
        output_path: Path to output VTK file
    """
    
    # Create points
    points = vtk.vtkPoints()
    for node in nodes_ras:
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
        '--reference-nii', type=str, default=None,
        help='Reference NIfTI file to use for affine transformation (default: use input file affine)'
    )
    parser.add_argument(
        '--coordinate-system', type=str, default='xyz',
        choices=['ras', 'xyz'],
        help='Output coordinate system: "ras" (RAS space) or "xyz" (vmtk physical space, default). '
             'Use "xyz" to match vmtkcenterlines output coordinate system.'
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
    
    # Use reference volume affine if provided, otherwise use input file affine
    if args.reference_nii and os.path.exists(args.reference_nii):
        print('Using reference volume affine from: %s' % args.reference_nii)
        ref_nii = nib.load(args.reference_nii)
        affine = ref_nii.affine
        # Verify dimensions match (they should for proper alignment)
        if ref_nii.shape[:3] != nii.shape[:3]:
            print('Warning: Reference volume shape %s does not match input shape %s' % (
                str(ref_nii.shape[:3]), str(nii.shape[:3])), file=sys.stderr)
    else:
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
    
    # Write VTK file
    print('Writing VTK PolyData to: %s' % args.output_vtk)
    graph_to_vtk_polydata(nodes_coords, edges, args.output_vtk)
    
    print('Success! Created VTK centerline with %d points and %d line segments (coordinate system: %s)' % (
        len(nodes_coords), len(edges), coord_system_name
    ))


if __name__ == '__main__':
    main()
