function vmtk_viewVolAndSurf(volume_nii, surface_vtk, printFlag)
    % VMTK_VIEW_VOLUME_SURFACE Visualize volume image and surface mesh together in a single VMTK window
    %
    % Usage:
    %   vmtk_view_volume_surface(volume_nii, surface_vtk)
    %   vmtk_view_volume_surface(volume_nii, surface_vtk, printFlag)
    %
    % Inputs:
    %   volume_nii  - Path to volume image file (NIfTI format)
    %   surface_vtk - Path to surface mesh file (VTK format)
    %   printFlag   - Optional: if true, print command to file instead of executing (default: true)
    %
    % This function opens a single VMTK viewer window displaying both the
    % volume image planes and the surface mesh together.
    %
    % IMPORTANT: Coordinate System Alignment
    % The VTK surface file includes coordinate system metadata in FieldData:
    % - NIfTI_Affine: 4x4 transformation matrix from voxel to RAS coordinates
    % - CoordinateSystem: Identifier (RAS or xyz)  
    % - SourceNIfTI: Path to source NIfTI file
    %
    % However, VMTK command-line tools do NOT automatically read and use FieldData.
    % The surface coordinates must be in the same coordinate system as what
    % vmtkimagereader outputs for proper alignment.
    %
    % If surfaces don't align, check the coordinate system:
    % - Use read_vtk_fielddata.py <surface_vtk> to view stored metadata
    % - The surface should match the coordinate system that vmtkimagereader outputs
    % - If RAS doesn't align, try using --coordinate-system xyz when creating the surface
    
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
    
    % Build VMTK command
    % 
    % IMPORTANT: Coordinate system alignment
    % vmtkimagereader reads NIfTI files and outputs image data in a coordinate system
    % that depends on how ITK processes the NIfTI affine transformation. The surface
    % coordinates must match this coordinate system for proper alignment.
    %
    % The VTK surface file now includes coordinate system metadata in FieldData:
    % - NIfTI_Affine: 4x4 transformation matrix from voxel to RAS coordinates
    % - CoordinateSystem: Identifier (RAS or xyz)
    % - SourceNIfTI: Path to source NIfTI file
    %
    % However, VMTK command-line tools do NOT automatically read and use FieldData
    % metadata. The surface coordinates must already be in the correct coordinate system
    % that matches what vmtkimagereader outputs.
    %
    % If surfaces don't align, check:
    % 1. What coordinate system does vmtkimagereader output? (typically RAS after ITK processing)
    % 2. What coordinate system is the surface in? (check CoordinateSystem in FieldData)
    % 3. Apply appropriate transformation to match coordinate systems
    %
    % To extract and view the metadata, use: read_vtk_fielddata.py <surface_vtk>
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
