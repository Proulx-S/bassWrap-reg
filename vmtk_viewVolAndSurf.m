function vmtk_viewVolAndSurf(volume_nii, surface_vtk, printFlag)
    % VMTK_VIEW_VOLUME_SURFACE Visualize volume image and surface mesh together in a single VMTK window
    %
    % Usage:
    %   vmtk_view_volume_surface(volume_nii, surface_vtk)
    %
    % Inputs:
    %   volume_nii  - Path to volume image file (NIfTI format)
    %   surface_vtk - Path to surface mesh file (VTK format)
    %
    % This function opens a single VMTK viewer window displaying both the
    % volume image planes and the surface mesh together.
    
    global src;
    
    if nargin < 2
        error('vmtk_view_volume_surface requires two inputs: volume_nii and surface_vtk');
    end
    
    if nargin < 3 || isempty(printFlag); printFlag = 1; end
    
    if ~exist(volume_nii, 'file')
        error('Volume file not found: %s', volume_nii);
    end
    
    if ~exist(surface_vtk, 'file')
        error('Surface file not found: %s', surface_vtk);
    end
    
    % Build VMTK command using the pattern from vesselboost_prediction.m
    cmd = {src.vmtk};
    cmd{end+1} = [         'vmtkimagereader -ifile ' volume_nii ' \'];
    cmd{end+1} = ['--pipe vmtksurfacereader -ifile ' surface_vtk ' \'];
    cmd{end+1} = ['--pipe vmtkrenderer \'];
    cmd{end+1} = ['--pipe vmtkimageviewer   -i @vmtkimagereader.o   -display 0 \'];
    cmd{end+1} = ['--pipe vmtksurfaceviewer -i @vmtksurfacereader.o -display 1'  ];
    
    if printFlag
        cmd_file = replace(surface_vtk, '.vtk', '.cmd');
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
