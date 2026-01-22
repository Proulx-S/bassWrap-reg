function output_vtk = skeleton_to_graph_vtk(skeleton_nii, output_vtk, connectivity, forceThis, reference_nii)
%SKELETON_TO_GRAPH_VTK Extract graph from skeleton mask and output as VTK centerline
%
%   Usage:
%     output_vtk = skeleton_to_graph_vtk(skeleton_nii, output_vtk)
%     output_vtk = skeleton_to_graph_vtk(skeleton_nii, output_vtk, connectivity)
%     output_vtk = skeleton_to_graph_vtk(skeleton_nii, output_vtk, connectivity, forceThis)
%     output_vtk = skeleton_to_graph_vtk(skeleton_nii, output_vtk, connectivity, forceThis, reference_nii)
%
%   Inputs:
%     skeleton_nii - Path to input skeleton NIfTI file (binary mask)
%     output_vtk   - Path to output VTK PolyData file (.vtk or .vtp)
%     connectivity - Optional: 6, 18, or 26 (default: 26 for 3D)
%     forceThis    - Optional: if true, regenerate even if output exists (default: false)
%     reference_nii - Optional: Path to reference NIfTI file to use for affine
%                     transformation (e.g., original TOF volume). If not provided,
%                     uses the input skeleton file's affine.
%
%   Outputs:
%     output_vtk   - Path to created VTK PolyData file
%
%   This function extracts a full graph representation (nodes and edges) from a
%   skeleton mask where each non-zero voxel becomes a node, and edges connect
%   adjacent voxels. The output is in VTK PolyData format compatible with
%   vmtkcenterlines, preserving branching structure.
%
%   The function attempts to use pi2 if available, but falls back to direct
%   graph construction if pi2 is not available.

    if nargin < 3 || isempty(connectivity)
        connectivity = 26;  % Default: 26-connectivity for 3D
    end
    
    if nargin < 4 || isempty(forceThis)
        forceThis = false;
    end

    if ~exist(skeleton_nii, 'file')
        error('Input file not found: %s', skeleton_nii);
    end

    % Skip if output exists and forceThis is false
    if ~forceThis && exist(output_vtk, 'file')
        fprintf('VTK centerline file already exists: %s (use forceThis=1 to regenerate)\n', output_vtk);
        return;
    end

    % Ensure output directory exists
    [output_dir, ~, ~] = fileparts(output_vtk);
    if ~isempty(output_dir) && ~exist(output_dir, 'dir')
        mkdir(output_dir);
    end

    % Get path to Python script (should be in same directory as this function)
    script_dir = fileparts(mfilename('fullpath'));
    python_script = fullfile(script_dir, 'skeleton_to_graph_vtk.py');
    
    if ~exist(python_script, 'file')
        error('skeleton_to_graph_vtk:ScriptNotFound', 'Python script not found: %s', python_script);
    end

    % Build command with optional reference volume
    % Use xyz coordinate system by default to match vmtkcenterlines output
    % This ensures centerlines align properly when viewed with vmtk_viewVolAndSurf
    if nargin >= 5 && ~isempty(reference_nii) && exist(reference_nii, 'file')
        cmd = sprintf('python "%s" "%s" "%s" --connectivity %d --reference-nii "%s" --coordinate-system xyz', ...
            python_script, skeleton_nii, output_vtk, connectivity, reference_nii);
    else
        cmd = sprintf('python "%s" "%s" "%s" --connectivity %d --coordinate-system xyz', ...
            python_script, skeleton_nii, output_vtk, connectivity);
    end
    
    % Try to use nipype container if available (check for global src.nipype)
    global src;
    if isfield(src, 'nipype') && ~isempty(src.nipype)
        cmd = [src.nipype '; ' cmd];
    end
    
    [status, result] = system(cmd, '-echo');
    
    if status ~= 0
        error('skeleton_to_graph_vtk:PythonScriptFailed', ...
            'Python script failed with error: %s\nCommand: %s', result, cmd);
    end

    % Verify output file was created
    if ~exist(output_vtk, 'file')
        error('skeleton_to_graph_vtk:VTKFileNotCreated', ...
            'VTK file was not created: %s', output_vtk);
    end
    
    % Check if file is empty
    file_info = dir(output_vtk);
    if file_info.bytes == 0
        error('skeleton_to_graph_vtk:VTKFileEmpty', ...
            'VTK file is empty: %s', output_vtk);
    end

    fprintf('skeleton_to_graph_vtk completed: %s\n', output_vtk);

end
