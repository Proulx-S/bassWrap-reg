function output = skeletonize_nifti(input_nii, output_nii, method, forceThis)
%SKELETONIZE_NIFTI Skeletonize binary NIfTI volume using scikit-image
%
%   Usage:
%     output_nii = skeletonize_nifti(input_nii, output_nii)
%     output_nii = skeletonize_nifti(input_nii, output_nii, method)
%     output_nii = skeletonize_nifti(input_nii, output_nii, method, forceThis)
%     skeleton = skeletonize_nifti(input_nii)  % Returns logical 3D matrix
%     skeleton = skeletonize_nifti(input_nii, [], method)  % Returns logical 3D matrix
%
%   Inputs:
%     input_nii  - Path to input binary NIfTI file (non-zero = foreground)
%     output_nii - Path to output skeletonized NIfTI file (optional)
%                  If empty or not provided, returns logical 3D matrix
%     method     - Optional: 'zhang' or 'lee' (default: 'lee' for 3D volumes)
%     forceThis  - Optional: if true, regenerate even if output exists (default: false)
%
%   Outputs:
%     output     - If output_nii provided: Path to created skeletonized NIfTI file
%                  If output_nii not provided: Logical 3D matrix of skeletonized volume
%
%   This function uses scikit-image's skeletonize function to reduce binary
%   objects to 1 pixel wide representations while preserving connectivity.
%   For 3D volumes, Lee's method is automatically used (recommended for 3D).

    % Handle optional arguments
    if nargin < 3 || isempty(method)
        method = 'lee';  % Default: Lee method for 3D
    end
    
    if nargin < 4 || isempty(forceThis)
        forceThis = false;
    end

    % Check if output_nii is provided
    return_matrix = false;
    if nargin < 2 || isempty(output_nii)
        return_matrix = true;
        % Create temporary file path
        [input_dir, input_name, ~] = fileparts(input_nii);
        temp_dir = fullfile(input_dir, 'tmp');
        if ~exist(temp_dir, 'dir')
            mkdir(temp_dir);
        end
        output_nii = fullfile(temp_dir, [input_name '_skeleton_temp.nii.gz']);
        forceThis = true;  % Always regenerate temp file
    end

    if ~exist(input_nii, 'file')
        error('Input file not found: %s', input_nii);
    end

    % Skip if output exists and forceThis is false
    if ~forceThis && exist(output_nii, 'file')
        if return_matrix
            % Read and return the matrix
            mri = MRIread(output_nii);
            output = logical(mri.vol);
            return;
        else
            fprintf('Skeleton file already exists: %s (use forceThis=1 to regenerate)\n', output_nii);
            output = output_nii;
            return;
        end
    end

    % Ensure output directory exists
    [output_dir, ~, ~] = fileparts(output_nii);
    if ~isempty(output_dir) && ~exist(output_dir, 'dir')
        mkdir(output_dir);
    end

    % Get path to Python script (should be in same directory as this function)
    script_dir = fileparts(mfilename('fullpath'));
    python_script = fullfile(script_dir, 'skeletonize_nifti.py');
    
    if ~exist(python_script, 'file')
        error('Python skeletonization script not found: %s', python_script);
    end

    % Try to use nipype container if available (check for global src.nipype)
    global src;
    if isfield(src, 'nipype') && ~isempty(src.nipype)
        cmd = sprintf('%s; python "%s" "%s" "%s" --method %s', src.nipype, python_script, input_nii, output_nii, method);
    else
        cmd = sprintf('python "%s" "%s" "%s" --method %s', python_script, input_nii, output_nii, method);
    end
    
    [status, result] = system(cmd, '-echo');
    
    if status ~= 0
        error('scikit-image skeletonization failed. Error: %s\nCommand: %s', result, cmd);
    end

    % Verify output file was created
    if ~exist(output_nii, 'file')
        error('Skeletonized file was not created: %s', output_nii);
    end

    if return_matrix
        % Read the skeletonized volume and return as logical matrix
        mri = MRIread(output_nii);
        output = logical(mri.vol);
        % Clean up temporary file
        delete(output_nii);
    else
        fprintf('scikit-image skeletonization completed: %s\n', output_nii);
        output = output_nii;
    end

end
