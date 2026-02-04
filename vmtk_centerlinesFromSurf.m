function cmd = vmtk_centerlinesFromSurf(surface_vtk, output_centerlines_vtk, source_point, target_point, printFlag)
    % VMTK_CENTERLINESFROMSURF Extract centerlines from surface mesh using VMTK
    %
    % Usage:
    %   vmtk_centerlinesFromSurf(surface_vtk, output_centerlines_vtk)
    %   vmtk_centerlinesFromSurf(surface_vtk, output_centerlines_vtk, source_point, target_point)
    %   vmtk_centerlinesFromSurf(surface_vtk, output_centerlines_vtk, source_point, target_point, printFlag)
    %
    % Inputs:
    %   surface_vtk            - Path to input surface mesh file (VTK format)
    %   output_centerlines_vtk - Path to output centerlines file (VTK format)
    %   source_point           - Optional 3-element vector [x,y,z] in RAS coordinates for source point
    %   target_point            - Optional 3-element vector [x,y,z] in RAS coordinates for target point
    %   printFlag               - If 1, print command to file instead of running it (default: 0)
    %
    % If source_point and target_point are provided, uses pointlist seed selector.
    % Otherwise, uses openprofiles seed selector (requires GUI interaction).
    
    global src;
    
    if nargin < 5 || isempty(printFlag); printFlag = 0; end
    
    if ~exist(surface_vtk, 'file')
        error('Surface file not found: %s', surface_vtk);
    end
    
    % Ensure output directory exists
    if ~exist(fileparts(output_centerlines_vtk),'dir')
        mkdir(fileparts(output_centerlines_vtk));
    end
    
    % Build command based on whether points are provided
    cmd = {src.vmtk};
    cmd{end+1} = ['vmtkcenterlines -ifile ' surface_vtk ' \'];
    
    if nargin >= 4 && ~isempty(source_point) && ~isempty(target_point)
        % Use pointlist seed selector with provided points
        if length(source_point) ~= 3 || length(target_point) ~= 3
            error('source_point and target_point must be 3-element vectors [x, y, z]');
        end
        % cmd{end+1} = ['-seedselector pointlist \'];
        cmd{end+1} = ['-sourcepoints ' num2str(source_point(1)) ' ' num2str(source_point(2)) ' ' num2str(source_point(3)) ' \'];
        cmd{end+1} = ['-targetpoints ' num2str(target_point(1)) ' ' num2str(target_point(2)) ' ' num2str(target_point(3)) ' \'];
    else
        % Use openprofiles seed selector (requires GUI)
        cmd{end+1} = ['-seedselector openprofiles \'];
    end
    
    cmd{end+1} = ['-ofile ' output_centerlines_vtk];
    
    if printFlag
        cmd_file = replace(surface_vtk, '.vtk', '.cmd-centerlines');
        fid = fopen(cmd_file, 'w');
        if fid == -1
            error('Could not create command file: %s', cmd_file);
        end
        fprintf(fid, '%s\n', cmd{:});
        fclose(fid);
        fprintf('Command file created: %s\n', cmd_file);
    else
        [status, result] = system(strjoin(cmd, newline), '-echo');
        
        % Verify centerlines were created successfully
        if status ~= 0 || ~exist(output_centerlines_vtk,'file') || dir(output_centerlines_vtk).bytes == 0
            error('Centerline extraction failed - file is empty or missing. Check surface mesh and vessel structure.');
        end
    end
end
