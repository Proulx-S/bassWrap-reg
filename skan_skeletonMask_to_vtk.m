function output_vtk = skan_skeletonMask_to_vtk(skeleton_nii, output_vtk, forceThis)
%SKAN_SKELETONMASK_TO_VTK Extract graph from skeleton mask using skan and output as VTK centerline
%
%   Usage:
%     output_vtk = skan_skeletonMask_to_vtk(skeleton_nii, output_vtk)
%     output_vtk = skan_skeletonMask_to_vtk(skeleton_nii, output_vtk, forceThis)
%
%   Inputs:
%     skeleton_nii - Path to input skeleton NIfTI file (binary mask)
%     output_vtk   - Path to output VTK PolyData file (.vtk or .vtp)
%     forceThis    - Optional: if true, regenerate even if output exists (default: false)
%
%   Outputs:
%     output_vtk   - Path to created VTK PolyData file
%
%   This function uses the skan library to extract a graph representation from a
%   skeleton mask. skan handles junctions and branching more robustly than
%   manual neighbor checking. The output is in VTK PolyData format compatible
%   with vmtkcenterlines, preserving branching structure.
%
%   The function uses the input skeleton file's affine transformation for
%   coordinate conversion.

    if nargin < 3 || isempty(forceThis)
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
    python_script = fullfile(script_dir, 'skan_skeletonMask_to_vtk.py');
    
    if ~exist(python_script, 'file')
        error('skan_skeletonMask_to_vtk:ScriptNotFound', 'Python script not found: %s', python_script);
    end

    % Build command
    % Use xyz coordinate system by default to match vmtkcenterlines output
    % This ensures centerlines align properly when viewed with vmtk_viewVolAndSurf
    cmd = sprintf('python "%s" "%s" "%s" --coordinate-system xyz', ...
        python_script, skeleton_nii, output_vtk);
    
    % % Try to use nipype container if available (check for global src.nipype)
    % % nipype container contains skan library
    % global src;
    % if isfield(src, 'nipype') && ~isempty(src.nipype)
    %     cmd = [src.nipype '; ' cmd];
    % end
    
    [status, result] = system(cmd, '-echo');
    
    if status ~= 0
        error('skan_skeletonMask_to_vtk:PythonScriptFailed', ...
            'Python script failed with error: %s\nCommand: %s', result, cmd);
    end

    % Verify output file was created
    if ~exist(output_vtk, 'file')
        error('skan_skeletonMask_to_vtk:VTKFileNotCreated', ...
            'VTK file was not created: %s', output_vtk);
    end
    
    % Check if file is empty
    file_info = dir(output_vtk);
    if file_info.bytes == 0
        error('skan_skeletonMask_to_vtk:VTKFileEmpty', ...
            'VTK file is empty: %s', output_vtk);
    end

    fprintf('skan_skeletonMask_to_vtk completed: %s\n', output_vtk);

end
