function output_vtk = ras_coords_to_vtk(ras_coords, output_vtk_path)
%RAS_COORDS_TO_VTK Write RAS coordinates to VTK PolyData centerline file
%
%   Usage:
%     output_vtk = ras_coords_to_vtk(ras_coords, output_vtk_path)
%
%   Inputs:
%     ras_coords     - N×3 matrix of RAS coordinates [x, y, z] in real-world space (mm)
%     output_vtk_path - Path to output VTK file (.vtk or .vtp)
%
%   Outputs:
%     output_vtk     - Path to created VTK file (same as output_vtk_path)
%
%   This function writes RAS coordinates to a VTK PolyData file by:
%   1. Writing coordinates to a temporary text file
%   2. Calling Python script points_to_vtk_centerline.py to generate VTK file
%   3. Cleaning up temporary file
%
%   The output VTK file will contain a single polyline connecting all points
%   sequentially (0→1→2→...→N-1).

    if nargin < 2
        error('ras_coords_to_vtk requires two inputs: ras_coords and output_vtk_path');
    end

    if size(ras_coords, 2) ~= 3
        error('ras_coords must be N×3 matrix');
    end

    if size(ras_coords, 1) < 2
        error('Need at least 2 points to create a polyline; got %d', size(ras_coords, 1));
    end

    % Ensure output directory exists
    [output_dir, ~, ~] = fileparts(output_vtk_path);
    if ~isempty(output_dir) && ~exist(output_dir, 'dir')
        mkdir(output_dir);
    end

    % Get path to Python script (should be in same directory as this function)
    script_dir = fileparts(mfilename('fullpath'));
    python_script = fullfile(script_dir, 'points_to_vtk_centerline.py');
    
    if ~exist(python_script, 'file')
        error('Python script not found: %s', python_script);
    end

    % Create temporary text file with coordinates
    % Use tempname to get a unique temporary file
    temp_file = [tempname '.txt'];
    
    try
        % Write coordinates to temporary file (one point per line: x y z)
        fid = fopen(temp_file, 'w');
        if fid == -1
            error('Could not create temporary file: %s', temp_file);
        end
        
        for i = 1:size(ras_coords, 1)
            fprintf(fid, '%.6f %.6f %.6f\n', ras_coords(i, 1), ras_coords(i, 2), ras_coords(i, 3));
        end
        fclose(fid);

        % Call Python script
        cmd = sprintf('python "%s" "%s" "%s"', python_script, temp_file, output_vtk_path);
        [status, result] = system(cmd);
        
        if status ~= 0
            error('Python script failed: %s\nCommand: %s', result, cmd);
        end

        % Verify output file was created
        if ~exist(output_vtk_path, 'file')
            error('VTK file was not created: %s', output_vtk_path);
        end

        % Clean up temporary file
        if exist(temp_file, 'file')
            delete(temp_file);
        end

        output_vtk = output_vtk_path;

    catch ME
        % Clean up temporary file on error
        if exist(temp_file, 'file')
            delete(temp_file);
        end
        rethrow(ME);
    end

end
