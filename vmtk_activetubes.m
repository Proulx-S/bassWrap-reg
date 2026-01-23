function centerline_vtk = vmtk_activetubes(intensity_nii, initial_centerline_vtk, output_vtk, options)
%VMTK_ACTIVETUBES Refine centerlines using vmtkactivetubes
%   Uses vmtkactivetubes to refine initial centerlines using intensity image
%
%   Usage:
%     centerline_vtk = vmtk_activetubes(intensity_nii, initial_centerline_vtk)
%     centerline_vtk = vmtk_activetubes(intensity_nii, initial_centerline_vtk, output_vtk)
%     centerline_vtk = vmtk_activetubes(intensity_nii, initial_centerline_vtk, output_vtk, options)
%
%   Inputs:
%       intensity_nii        - Path to intensity NIfTI image
%       initial_centerline_vtk - Path to initial centerline VTK polydata file
%       output_vtk           - Optional: Path to output refined centerline VTK file
%                              If not provided, appends '_refined' to input centerline name
%       options              - Optional struct with parameters:
%                              - iterations: Number of iterations (default: 100)
%                              - potentialweight: Potential weight (default: 1.0)
%                              - stiffnessweight: Stiffness weight (default: 1.0)
%                              - forceThis: If true, regenerate even if output exists (default: false)
%
%   Outputs:
%       centerline_vtk - Path to refined centerline VTK file

    if nargin < 2
        error('vmtk_activetubes:NotEnoughInputs', ...
            'At least 2 inputs required: intensity_nii and initial_centerline_vtk');
    end
    
    if nargin < 3 || isempty(output_vtk)
        % Generate output filename by appending '_refined' to input centerline
        [path, name, ext] = fileparts(initial_centerline_vtk);
        if isempty(path)
            output_vtk = [name '_refined' ext];
        else
            output_vtk = fullfile(path, [name '_refined' ext]);
        end
    end
    
    if nargin < 4 || isempty(options)
        options = struct();
    end
    
    % Set default options
    if ~isfield(options, 'iterations')
        options.iterations = 100;
    end
    if ~isfield(options, 'potentialweight')
        options.potentialweight = 1.0;
    end
    if ~isfield(options, 'stiffnessweight')
        options.stiffnessweight = 1.0;
    end
    if ~isfield(options, 'forceThis')
        options.forceThis = false;
    end
    
    % Check input files
    if ~exist(intensity_nii, 'file')
        error('vmtk_activetubes:InputNotFound', 'Intensity image not found: %s', intensity_nii);
    end
    
    if ~exist(initial_centerline_vtk, 'file')
        error('vmtk_activetubes:InputNotFound', 'Initial centerline not found: %s', initial_centerline_vtk);
    end
    
    % Skip if output exists and forceThis is false
    if ~options.forceThis && exist(output_vtk, 'file')
        file_info = dir(output_vtk);
        if file_info.bytes > 0
            fprintf('Refined centerline file already exists: %s (use forceThis=1 to regenerate)\n', output_vtk);
            centerline_vtk = output_vtk;
            return;
        end
    end
    
    % Ensure output directory exists
    [output_dir, ~, ~] = fileparts(output_vtk);
    if ~isempty(output_dir) && ~exist(output_dir, 'dir')
        mkdir(output_dir);
    end
    
    % Get path to Python script (should be in same directory as this function)
    script_dir = fileparts(mfilename('fullpath'));
    python_script = fullfile(script_dir, 'vmtk_activetubes.py');
    
    if ~exist(python_script, 'file')
        error('vmtk_activetubes:ScriptNotFound', 'Python script not found: %s', python_script);
    end
    
    % Build command
    cmd = sprintf('python "%s" "%s" "%s" "%s" --iterations %d --potentialweight %.2f --stiffnessweight %.2f', ...
        python_script, intensity_nii, initial_centerline_vtk, output_vtk, ...
        options.iterations, options.potentialweight, options.stiffnessweight);
    
    % Try to use nipype container if available (check for global src.nipype)
    global src;
    if isfield(src, 'nipype') && ~isempty(src.nipype)
        cmd = [src.nipype '; ' cmd];
    end
    
    [status, result] = system(cmd, '-echo');
    
    if status ~= 0
        error('vmtk_activetubes:PythonScriptFailed', ...
            'Python script failed with error: %s\nCommand: %s', result, cmd);
    end
    
    % Verify output file was created
    if ~exist(output_vtk, 'file')
        error('vmtk_activetubes:VTKFileNotCreated', ...
            'VTK file was not created: %s', output_vtk);
    end
    
    % Check if file is empty
    file_info = dir(output_vtk);
    if file_info.bytes == 0
        error('vmtk_activetubes:VTKFileEmpty', ...
            'VTK file is empty: %s', output_vtk);
    end
    
    fprintf('vmtk_activetubes completed: %s\n', output_vtk);
    
    centerline_vtk = output_vtk;

end
