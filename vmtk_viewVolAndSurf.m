function vmtk_viewVolAndSurf(volume_nii, surface_vtk, printFlag, source_nii)
    % VMTK_VIEW_VOLUME_SURFACE Visualize volume and surface/centerline in one VMTK window
    %
    % Usage:
    %   vmtk_viewVolAndSurf(volume_nii, surface_vtk)
    %   vmtk_viewVolAndSurf(volume_nii, surface_vtk, printFlag)
    %   vmtk_viewVolAndSurf(volume_nii, surface_vtk, printFlag, source_nii)
    %
    % Inputs:
    %   volume_nii  - Path to volume NIfTI to display (the "viewing" image).
    %   surface_vtk - Path to surface or centerline VTK (.vtk). Can be from
    %                  vmtk_surfFromSeg, vmtk_centerlinesFromSurf, etc.
    %   printFlag   - Optional. If true (default), write the VMTK command to a
    %                 .cmd file next to surface_vtk instead of running it.
    %   source_nii  - Optional. NIfTI the mesh was created from. Only needed if
    %                 the VTK has no FieldData (see "Giving the mesh a source" below).
    %
    % What this does
    % --------------
    % Opens one VMTK window with the volume slices and the mesh overlaid. Before
    % calling VMTK, the mesh is aligned to the volume using NIfTI spatial info
    % so they register even when the volume and the mesh come from different
    % NIfTIs (e.g. different resolution or crop).
    %
    % Alignment (why and when)
    % -----------------------
    % If the surface was built from one NIfTI (e.g. a cropped segmentation) and
    % you view with another (e.g. full-resolution TOF), raw coordinates would
    % not match and the mesh would look shifted. This function fixes that by:
    %   1. Reading the volume NIfTI affine (voxel -> physical/RAS).
    %   2. If the mesh has FieldData SourceNIfTI (or you pass source_nii), we
    %      know which NIfTI the mesh refers to. When that differs from volume_nii,
    %      we transform the mesh into the volume's display space and write
    %      <surface_vtk base>_aligned.vtk. VMTK is then called with that file.
    %   3. If the mesh was created from the same NIfTI as volume_nii, no transform
    %      is applied (we just copy the mesh to _aligned.vtk).
    %
    % Giving the mesh a "source" (so alignment can run)
    % -------------------------------------------------
    % The alignment script needs to know which NIfTI the mesh came from. Two ways:
    %   (1) FieldData on the VTK: NIfTI_Affine, CoordinateSystem, SourceNIfTI.
    %       Surfaces from vmtk_surfFromSeg get this on the raw output; for the
    %       final smoothed surface, call vtk_add_nifti_metadata(surface_vtk, seg_nii)
    %       after your pipeline (e.g. in doIt_singleSlabTofVolPrc).
    %   (2) Pass source_nii as the 4th argument. Use this for centerlines or any
    %       VTK that does not have FieldData, e.g.:
    %       vmtk_viewVolAndSurf(scaleMaxTof, vesselCenterlineList{v}, 0, fSegList{v})
    %
    % Examples
    % --------
    %   % Same NIfTI as segmentation (no transform):
    %   vmtk_viewVolAndSurf(fSegList{v}, vesselSurfList{v});
    %
    %   % Different volume (e.g. full TOF); surface should have FieldData or pass source_nii:
    %   vmtk_viewVolAndSurf(scaleMaxTof, vesselSurfList{v});
    %   vmtk_viewVolAndSurf(scaleMaxTof, vesselCenterlineList{v}, 0, fSegList{v});
    %
    % See also: vtk_add_nifti_metadata, vmtk_align_surface_to_image.py, read_vtk_fielddata.py
    %
    global src;
    
    if nargin < 2
        error('vmtk_view_volume_surface requires two inputs: volume_nii and surface_vtk');
    end
    
    if nargin < 3 || isempty(printFlag); printFlag = 1; end
    if nargin < 4; source_nii = ''; end
    
    if ~exist(volume_nii, 'file')
        error('Volume file not found: %s', volume_nii);
    end
    
    if ~exist(surface_vtk, 'file')
        error('Surface file not found: %s', surface_vtk);
    end
    
    % Align surface to volume using NIfTI spatial information so they register
    % when volume and surface come from different resolutions/crops.
    script_dir = fileparts(mfilename('fullpath'));
    align_script = fullfile(script_dir, 'vmtk_align_surface_to_image.py');
    aligned_surface = replace(surface_vtk, '.vtk', '_aligned.vtk');
    align_cmd = sprintf('python "%s" "%s" "%s" "%s"', align_script, volume_nii, surface_vtk, aligned_surface);
    if ~isempty(source_nii) && exist(source_nii, 'file')
        align_cmd = [align_cmd ' "' source_nii '"'];
    end
    [align_ok, align_err] = system(align_cmd, '-echo');
    if align_ok ~= 0
        error('Surface alignment failed: %s', align_err);
    end
    surface_to_show = aligned_surface;
    
    % Build VMTK command (surface_to_show is already aligned to volume_nii above)
    cmd = {src.vmtk};
    cmd{end+1} = [         'vmtkimagereader -ifile ' volume_nii ' \'];
    cmd{end+1} = ['--pipe vmtksurfacereader -ifile ' surface_to_show ' \'];
    cmd{end+1} = ['--pipe vmtkrenderer \'];
    cmd{end+1} = ['--pipe vmtkimageviewer   -i @vmtkimagereader.o   -display 0 \'];
    cmd{end+1} = ['--pipe vmtksurfaceviewer -i @vmtksurfacereader.o -display 1'  ];
    

    [~,~,e] = fileparts(surface_vtk);
    if ~strcmp(e,'.vtk')
        dbstack; error('Surface file must be a .vtk file');
    end

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
