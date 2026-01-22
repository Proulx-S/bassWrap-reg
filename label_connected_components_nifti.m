function labeled_nii = label_connected_components_nifti(input_nii, output_nii, connectivity)
%LABEL_CONNECTED_COMPONENTS_NIFTI Label connected components using scikit-image
%
%   Usage:
%     labeled_nii = label_connected_components_nifti(input_nii, output_nii)
%     labeled_nii = label_connected_components_nifti(input_nii, output_nii, connectivity)
%
%   Inputs:
%     input_nii   - Path to input binary NIfTI file (non-zero = foreground)
%     output_nii  - Path to output labeled NIfTI file
%     connectivity - Optional: 1 (6-connectivity), 2 (18-connectivity), or 3 (26-connectivity, default)
%
%   Outputs:
%     labeled_nii - Path to created labeled NIfTI file (same as output_nii)
%
%   This function uses scikit-image's label function to find connected components
%   in a binary volume. Components are sorted by size (largest = 1, second largest = 2, etc.)
%   and written to a labeled NIfTI where each voxel value is the component index.
%
%   Example:
%     labeled = label_connected_components_nifti('skeleton.nii.gz', 'skeleton_labeled.nii.gz');
%     mri = MRIread(labeled);
%     % Component 1 is largest, component 2 is second largest, etc.

    if nargin < 3 || isempty(connectivity)
        connectivity = 3;  % Default: 26-connectivity for 3D
    end

    if ~exist(input_nii, 'file')
        error('Input file not found: %s', input_nii);
    end

    % Ensure output directory exists
    [output_dir, ~, ~] = fileparts(output_nii);
    if ~isempty(output_dir) && ~exist(output_dir, 'dir')
        mkdir(output_dir);
    end

    % Get path to Python script (should be in same directory as this function)
    script_dir = fileparts(mfilename('fullpath'));
    python_script = fullfile(script_dir, 'label_connected_components_nifti.py');
    
    if ~exist(python_script, 'file')
        error('Python script not found: %s', python_script);
    end

    % Try to use nipype container if available (check for global src.nipype)
    global src;
    if isfield(src, 'nipype') && ~isempty(src.nipype)
        cmd = sprintf('%s; python "%s" "%s" "%s" --connectivity %d', src.nipype, python_script, input_nii, output_nii, connectivity);
    else
        cmd = sprintf('python "%s" "%s" "%s" --connectivity %d', python_script, input_nii, output_nii, connectivity);
    end
    [status, result] = system(cmd, '-echo');
    
    if status ~= 0
        error('Python script failed: %s\nCommand: %s', result, cmd);
    end

    % Verify output file was created
    if ~exist(output_nii, 'file')
        error('Labeled file was not created: %s', output_nii);
    end

    labeled_nii = output_nii;

end
