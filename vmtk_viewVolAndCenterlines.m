function cmd = vmtk_viewVolAndCenterlines(volume_nii, centerlines_vtk, printFlag)
    % VMTK_VIEW_VOLUME_CENTERLINES Visualize volume image and centerlines together in a single VMTK window
    %
    % Usage:
    %   vmtk_viewVolAndCenterlines(volume_nii, centerlines_vtk)
    %   vmtk_viewVolAndCenterlines(volume_nii, centerlines_vtk, printFlag)
    %
    % Inputs:
    %   volume_nii     - Path to volume image file (NIfTI format)
    %   centerlines_vtk - Path to centerlines file (VTK format)
    %   printFlag       - If 1, print command to file instead of running it (default: 1)
    %
    % This function opens a single VMTK viewer window displaying both the
    % volume image planes and the centerlines together.
    
    global src;
    
    if nargin < 2
        error('vmtk_viewVolAndCenterlines requires two inputs: volume_nii and centerlines_vtk');
    end
    
    if nargin < 3 || isempty(printFlag); printFlag = 1; end
    
    if ~exist(volume_nii, 'file')
        error('Volume file not found: %s', volume_nii);
    end
    
    if ~exist(centerlines_vtk, 'file')
        error('Centerlines file not found: %s', centerlines_vtk);
    end
    
    % Build VMTK command using the pattern from vmtk_viewVolAndSurf.m
    % Combine volume image viewer with centerline viewer in a single renderer
    cmd = {src.vmtk};
    cmd{end+1} = [         'vmtkimagereader -ifile ' volume_nii ' \'];
    cmd{end+1} = ['--pipe vmtksurfacereader -ifile ' centerlines_vtk ' \'];
    cmd{end+1} = ['--pipe vmtkrenderer \'];
    cmd{end+1} = ['--pipe vmtkimageviewer   -i @vmtkimagereader.o   -display 0 \'];
    cmd{end+1} = ['--pipe vmtksurfaceviewer -i @vmtksurfacereader.o -display 1'  ];
    
    if printFlag
        cmd_file = replace(centerlines_vtk, '.vtk', '.cmd-view');
        fid = fopen(cmd_file, 'w');
        if fid == -1
            error('Could not create command file: %s', cmd_file);
        end
        fprintf(fid, '%s\n', cmd{:});
        fclose(fid);
        fprintf('Command file created: %s\n', cmd_file);
    else
        system(strjoin(cmd,newline),'-echo');
    end
end
