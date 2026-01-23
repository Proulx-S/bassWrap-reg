function [output, bbox] = auto_crop_nifti(input_nii, output_nii, threshold, forceThis)
%AUTO_CROP_NIFTI Automatically crop NIfTI volume to bounding box of non-zero voxels
%
%   Usage:
%     output_nii = auto_crop_nifti(input_nii, output_nii)
%     [output_nii, bbox] = auto_crop_nifti(input_nii, output_nii)
%     output_nii = auto_crop_nifti(input_nii, output_nii, threshold)
%     output_nii = auto_crop_nifti(input_nii, output_nii, threshold, forceThis)
%     cropped = auto_crop_nifti(input_nii)  % Returns 3D matrix
%     cropped = auto_crop_nifti(input_nii, [], threshold)  % Returns 3D matrix
%
%   Inputs:
%     input_nii  - Path to input NIfTI file
%     output_nii - Path to output cropped NIfTI file (optional)
%                  If empty or not provided, returns 3D matrix
%     threshold  - Optional: Threshold for non-zero detection (default: 0)
%     forceThis  - Optional: if true, regenerate even if output exists (default: false)
%
%   Outputs:
%     output     - If output_nii provided: Path to created cropped NIfTI file
%                  If output_nii not provided: 3D matrix of cropped volume
%     bbox       - Structure with bounding box indices in original image:
%                  .min - [x_min, y_min, z_min, ...] (0-indexed)
%                  .max - [x_max, y_max, z_max, ...] (0-indexed)
%                  .dims - dimension names {'x', 'y', 'z', 't', ...}
%
%   This function finds the bounding box of non-zero voxels and crops the volume
%   while correctly updating the affine matrix to preserve spatial coordinates.
%   Uses nibabel for proper handling of NIfTI spatial information.

    % Handle optional arguments
    if nargin < 3 || isempty(threshold)
        threshold = 0;  % Default: any non-zero value
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
        output_nii = fullfile(temp_dir, [input_name '_cropped_temp.nii.gz']);
        forceThis = true;  % Always regenerate temp file
    end

    if ~exist(input_nii, 'file')
        error('Input file not found: %s', input_nii);
    end

    % Read bounding box indices file path (needed for both new and existing files)
    indices_file = strrep(output_nii, '.nii.gz', '_bbox_indices.txt');
    indices_file = strrep(indices_file, '.nii', '_bbox_indices.txt');
    
    % Skip if output exists and forceThis is false
    if ~forceThis && exist(output_nii, 'file')
        % Read bounding box indices if available
        bbox = struct('min', [], 'max', [], 'dims', {{}});
        if exist(indices_file, 'file')
            fid = fopen(indices_file, 'r');
            if fid ~= -1
                dims_list = {};
                min_list = [];
                max_list = [];
                line = fgetl(fid);
                while ischar(line)
                    % Skip comment lines
                    if ~isempty(line) && line(1) ~= '#'
                        parts = strsplit(strtrim(line));
                        if length(parts) >= 3
                            dim_name = parts{1};
                            min_val = str2double(parts{2});
                            max_val = str2double(parts{3});
                            if ~isnan(min_val) && ~isnan(max_val)
                                dims_list{end+1} = dim_name;
                                min_list(end+1) = min_val;
                                max_list(end+1) = max_val;
                            end
                        end
                    end
                    line = fgetl(fid);
                end
                fclose(fid);
                
                % Assign to bbox struct
                if ~isempty(min_list)
                    bbox.dims = dims_list;
                    bbox.min = min_list(:)';
                    bbox.max = max_list(:)';
                end
            end
        end
        
        if return_matrix
            % Read and return the matrix
            mri = MRIread(output_nii);
            output = mri.vol;
            return;
        else
            fprintf('Cropped file already exists: %s (use forceThis=1 to regenerate)\n', output_nii);
            if isfield(bbox, 'min') && isfield(bbox, 'dims')
                bbox_min = getfield(bbox, 'min');
                bbox_max = getfield(bbox, 'max');
                bbox_dims = getfield(bbox, 'dims');
                if length(bbox_min) > 0
                    fprintf('Bounding box indices (0-indexed):\n');
                    for i = 1:length(bbox_dims)
                        fprintf('  %s: [%d, %d]\n', bbox_dims{i}, bbox_min(i), bbox_max(i));
                    end
                end
            end
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
    python_script = fullfile(script_dir, 'auto_crop_nifti.py');
    
    if ~exist(python_script, 'file')
        error('Python auto-crop script not found: %s', python_script);
    end

    % Try to use nipype container if available (check for global src.nipype)
    global src;
    if isfield(src, 'nipype') && ~isempty(src.nipype)
        cmd = sprintf('%s; python "%s" "%s" "%s" --threshold %g', src.nipype, python_script, input_nii, output_nii, threshold);
    else
        cmd = sprintf('python "%s" "%s" "%s" --threshold %g', python_script, input_nii, output_nii, threshold);
    end
    
    [status, result] = system(cmd, '-echo');
    
    if status ~= 0
        error('Auto-crop failed. Error: %s\nCommand: %s', result, cmd);
    end

    % Verify output file was created
    if ~exist(output_nii, 'file')
        error('Cropped file was not created: %s', output_nii);
    end

    % Read bounding box indices from the text file
    bbox = struct('min', [], 'max', [], 'dims', {{}});
    if exist(indices_file, 'file')
        % Read the indices file
        fid = fopen(indices_file, 'r');
        if fid ~= -1
            dims_list = {};
            min_list = [];
            max_list = [];
            line = fgetl(fid);
            while ischar(line)
                % Skip comment lines
                if ~isempty(line) && line(1) ~= '#'
                    parts = strsplit(strtrim(line));
                    if length(parts) >= 3
                        dim_name = parts{1};
                        min_val = str2double(parts{2});
                        max_val = str2double(parts{3});
                        if ~isnan(min_val) && ~isnan(max_val)
                            dims_list{end+1} = dim_name;
                            min_list(end+1) = min_val;
                            max_list(end+1) = max_val;
                        end
                    end
                end
                line = fgetl(fid);
            end
            fclose(fid);
            
            % Assign to bbox struct
            if ~isempty(min_list)
                bbox.dims = dims_list;
                bbox.min = min_list(:)';
                bbox.max = max_list(:)';
            end
        else
            warning('Could not read bounding box indices file: %s', indices_file);
        end
    else
        warning('Bounding box indices file not found: %s', indices_file);
    end

    if return_matrix
        % Read the cropped volume and return as matrix
        mri = MRIread(output_nii);
        output = mri.vol;
        % Clean up temporary file
        delete(output_nii);
        if exist(indices_file, 'file')
            delete(indices_file);
        end
    else
        fprintf('Auto-crop completed: %s\n', output_nii);
        if isfield(bbox, 'min') && isfield(bbox, 'dims')
            bbox_min = getfield(bbox, 'min');
            bbox_max = getfield(bbox, 'max');
            bbox_dims = getfield(bbox, 'dims');
            if length(bbox_min) > 0
                fprintf('Bounding box indices (0-indexed):\n');
                for i = 1:length(bbox_dims)
                    fprintf('  %s: [%d, %d]\n', bbox_dims{i}, bbox_min(i), bbox_max(i));
                end
            end
        end
        output = output_nii;
    end

end
