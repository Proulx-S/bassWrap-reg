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
    % Opens one VMTK window with the volume slices and the mesh overlaid. The
    % volume is shown with texture interpolation off (-textureinterpolation 0)
    % so it appears pixelated (nearest-neighbor), not smoothed. Before
    % calling VMTK, the mesh is aligned to the volume using NIfTI spatial info
    % so they register even when the volume and the mesh come from different
    % NIfTIs (e.g. different resolution or crop).
    %
    % Alignment (why and when)
    % -----------------------
    % If the surface was built from one NIfTI (e.g. a cropped segmentation) and
    % you view with another (e.g. full-resolution TOF), raw coordinates would
    % not match and the mesh would look shifted. Alignment is only performed
    % when you pass the source NIfTI as the 4th argument (source_nii). Then:
    %   1. The volume NIfTI affine is read (voxel -> physical/RAS).
    %   2. When source_nii differs from volume_nii, the mesh is transformed into
    %      the volume's display space and written to <surface_vtk base>_aligned.vtk.
    %      VMTK is called with that file.
    %   3. When source_nii and volume_nii are the same file, no transform is applied.
    %
    % Giving the mesh a "source" (so alignment can run)
    % -------------------------------------------------
    % By default the viewer does NOT use stored spatial information (FieldData)
    % for alignment. If the VTK has FieldData (SourceNIfTI), a message is printed
    % on the terminal explaining how to have alignment applied.
    %
    % To have the mesh aligned when volume_nii and the mesh's source differ:
    %   (1) Pass the source NIfTI path as the 4th argument (source_nii). That is
    %       the NIfTI the mesh was created from (e.g. the segmentation). Example:
    %       vmtk_viewVolAndSurf(scaleMaxTof, vesselSurfList{v}, 0, fSegList{v})
    %   (2) The VTK may have that path stored in FieldData (vtk_add_nifti_metadata,
    %       or vmtk_surfFromSeg on the raw output). Stored info is not used by
    %       default; you still pass source_nii when you want alignment (e.g. the
    %       same path as in FieldData). Use read_vtk_fielddata.py <surface_vtk>
    %       to see stored SourceNIfTI.
    %
    % Examples
    % --------
    %   % View with same NIfTI as mesh source (no alignment needed):
    %   vmtk_viewVolAndSurf(fSegList{v}, vesselSurfList{v});
    %
    %   % View with different volume (e.g. full TOF); pass source_nii so mesh is aligned:
    %   vmtk_viewVolAndSurf(scaleMaxTof, vesselSurfList{v}, 0, fSegList{v});
    %   vmtk_viewVolAndSurf(scaleMaxTof, vesselCenterlineList{v}, 0, fSegList{v});
    %
    % See also: vmtk_viewVol, vtk_add_nifti_metadata, vmtk_align_surface_to_image.py, read_vtk_fielddata.py
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
    
    % Only run alignment when user requests it by passing source_nii.
    if ~isempty(source_nii) && exist(source_nii, 'file')
        script_dir = fileparts(mfilename('fullpath'));
        align_script = fullfile(script_dir, 'vmtk_align_surface_to_image.py');
        aligned_surface = replace(surface_vtk, '.vtk', '_aligned.vtk');
        align_cmd = sprintf('python "%s" "%s" "%s" "%s" "%s"', align_script, volume_nii, surface_vtk, aligned_surface, source_nii);
        [align_ok, align_err] = system(align_cmd, '-echo');
        if align_ok ~= 0
            error('Surface alignment failed: %s', align_err);
        end
        surface_to_show = aligned_surface;
    else
        surface_to_show = surface_vtk;
    end
    
    % Build VMTK command
    cmd = {src.vmtk};
    cmd{end+1} = [         'vmtkimagereader -ifile ' volume_nii ' \'];
    cmd{end+1} = ['--pipe vmtksurfacereader -ifile ' surface_to_show ' \'];
    cmd{end+1} = ['--pipe vmtkrenderer \'];
    cmd{end+1} = ['--pipe vmtkimageviewer   -i @vmtkimagereader.o   -display 0 -textureinterpolation 0 \'];
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
