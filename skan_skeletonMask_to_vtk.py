#!/usr/bin/env python
# -*- coding: utf-8 -*-
"""
skan_skeletonMask_to_vtk.py

Extract vessel network graph from skeleton mask using skan library and output
as VTK PolyData centerline format compatible with vmtkcenterlines.

This script uses skan's skeleton_to_csgraph to extract graph structure from
skeleton masks, which handles junctions and branching more robustly than
manual neighbor checking.

Usage:
    python skan_skeletonMask_to_vtk.py <input_skeleton_nii> <output_vtk> [--coordinate-system xyz]
"""

from __future__ import print_function
import skan
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
    from skan.csr import skeleton_to_csgraph
except ImportError:
    print('Error: skan is required. Install with: pip install skan', file=sys.stderr)
    print('Or use a Neurodesk container with skan (e.g., nipype/1.8.3)', file=sys.stderr)
    sys.exit(1)

try:
    from scipy.sparse import csr_matrix
except ImportError:
    print('Error: scipy is required. Install with: pip install scipy', file=sys.stderr)
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
        voxel_coords: Nx3 array of voxel coordinates (0-based, may be non-integer)
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
        voxel_coords: Nx3 array of voxel coordinates (0-based, may be non-integer)
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


def csr_to_edges(csr_graph):
    """Convert CSR sparse matrix to list of edge tuples.
    
    Args:
        csr_graph: scipy.sparse.csr_matrix representing adjacency graph
    
    Returns:
        List of edge tuples (node_idx1, node_idx2) where node_idx1 < node_idx2
    """
    edges = []
    # Iterate through non-zero entries in CSR matrix
    for i in range(csr_graph.shape[0]):
        # Get indices of non-zero entries in row i
        row_start = csr_graph.indptr[i]
        row_end = csr_graph.indptr[i + 1]
        for j in range(row_start, row_end):
            col_idx = csr_graph.indices[j]
            # Only add edge once (with smaller index first)
            if i < col_idx:
                edges.append((i, col_idx))
    
    return edges


def graph_to_vtk_polydata(nodes_coords, edges, output_path):
    """Convert graph (nodes and edges) to VTK PolyData format.
    
    Args:
        nodes_coords: Nx3 array of coordinates (RAS or xyz)
        edges: List of edge tuples (node_idx1, node_idx2)
        output_path: Path to output VTK file
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
        description='Extract graph from skeleton mask using skan and output as VTK centerline'
    )
    parser.add_argument('input_nii', help='Input skeleton NIfTI file (binary mask)')
    parser.add_argument('output_vtk', help='Output VTK PolyData file (.vtk or .vtp)')
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
    
    # Load skeleton
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
    
    # Extract graph using skan
    print('Extracting graph using skan...')
    pixel_graph, coordinates = skeleton_to_csgraph(skeleton_data)
    
    if pixel_graph.shape[0] == 0:
        print('Error: No nodes found in skeleton', file=sys.stderr)
        sys.exit(1)
    
    print('Skan graph: %d nodes' % pixel_graph.shape[0])
    
    # Convert CSR matrix to edge list
    print('Converting CSR graph to edge list...')
    edges = csr_to_edges(pixel_graph)
    print('Graph: %d nodes, %d edges' % (pixel_graph.shape[0], len(edges)))
    
    # Convert coordinates to output coordinate system
    # Note: skan's coordinates may be non-integer due to junction collapsing
    if args.coordinate_system == 'xyz':
        # Use xyz space (vmtk physical space) to match vmtkcenterlines output
        print('Converting voxel coordinates to xyz space (vmtk physical space)...')
        nodes_coords = voxel_to_xyz_coords(coordinates, affine)
        coord_system_name = 'xyz'
    else:
        # Use RAS space (standard NIfTI coordinate system)
        print('Converting voxel coordinates to RAS space...')
        nodes_coords = voxel_to_ras_coords(coordinates, affine)
        coord_system_name = 'RAS'
    
    # Write VTK file
    print('Writing VTK PolyData to: %s' % args.output_vtk)
    graph_to_vtk_polydata(nodes_coords, edges, args.output_vtk)
    
    print('Success! Created VTK centerline with %d points and %d line segments (coordinate system: %s)' % (
        len(nodes_coords), len(edges), coord_system_name
    ))


if __name__ == '__main__':
    main()
