function ras_coords = voxel_to_ras_coords(voxel_coords, mri)
%VOXEL_TO_RAS_COORDS Convert voxel coordinates to RAS (real-world) coordinates
%
%   Usage:
%     ras_coords = voxel_to_ras_coords(voxel_coords, mri)
%
%   Inputs:
%     voxel_coords - N×3 matrix of voxel coordinates [x, y, z] (1-based indexing from ind2sub)
%     mri          - MRI structure from MRIread with vox2ras field
%
%   Outputs:
%     ras_coords   - N×3 matrix of RAS coordinates in real-world space (mm)
%
%   This function converts voxel indices to RAS coordinates using the vox2ras
%   transformation matrix. The vox2ras matrix is typically 1-based for MATLAB's
%   ind2sub output (which uses 1-based indexing).
%
%   Example:
%     [x, y, z] = ind2sub(size(mri.vol), voxel_indices);
%     voxel_coords = [x, y, z];
%     ras_coords = voxel_to_ras_coords(voxel_coords, mri);

    if nargin < 2
        error('voxel_to_ras_coords requires two inputs: voxel_coords and mri');
    end

    if ~isfield(mri, 'vox2ras')
        error('MRI structure must have vox2ras field');
    end

    if size(voxel_coords, 2) ~= 3
        error('voxel_coords must be N×3 matrix');
    end

    % Convert to column vectors and add homogeneous coordinate
    % vox2ras is 4×4 matrix: [R A S T; 0 0 0 1]
    % Apply transformation: ras = vox2ras * [voxel_coords; 1]
    n_points = size(voxel_coords, 1);
    voxel_homogeneous = [voxel_coords'; ones(1, n_points)];
    
    % Apply transformation
    ras_homogeneous = mri.vox2ras * voxel_homogeneous;
    
    % Extract first 3 rows (RAS coordinates)
    ras_coords = ras_homogeneous(1:3, :)';
    
end
