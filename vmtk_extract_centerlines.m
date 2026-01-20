function [centerlines_vtk, centerlines_with_radius_vtk, seg_surface_vtk] = vmtk_extract_centerlines(seg_nii, intensity_nii, output_path, options)
    global src;
    if nargin < 4 || isempty(options); options = struct(); end
    
    % Ensure output directory exists
    if ~exist(output_path,'dir'); mkdir(output_path); end
    
    % Step 1: Create surface mesh from segmentation using marching cubes
    % This is needed for centerline extraction (vmtkcenterlines requires a surface mesh)
    seg_surface_vtk = fullfile(output_path, 'segmentation_surface.vtk');
    % Use vmtk wrapper with piping for nifti -> marching cubes -> surface
    % -l 0.5 for binary segmentation (threshold between 0 and 1)
    cmd = {src.vmtk};
    cmd{end+1} = ['vmtkimagereader -ifile ' seg_nii ' --pipe vmtkmarchingcubes -l 0.5 --pipe vmtksurfacewriter -ofile ' seg_surface_vtk];
    system(strjoin(cmd,newline),'-echo');
    
    % Verify surface was created
    if ~exist(seg_surface_vtk,'file') || dir(seg_surface_vtk).bytes < 100
        error('Surface mesh creation failed - file is empty or missing. Check segmentation values.');
    end

    % Debugging: return early
    if 1
        centerlines_vtk = [];
        centerlines_with_radius_vtk = [];
        return;
    end


    
    % Step 2: Convert intensity nifti to VTK (if provided) - for future use
    intensity_vti = [];
    if ~isempty(intensity_nii) && exist(intensity_nii,'file')
        intensity_vti = fullfile(output_path, 'intensity.vti');
        cmd = {src.vmtk};
        cmd{end+1} = ['vmtkimagereader -ifile ' intensity_nii ' --pipe vmtkimagewriter -ofile ' intensity_vti];
        system(strjoin(cmd,newline),'-echo');
    end
    
    % Step 3: Extract centerlines from surface mesh (Phase 1 - simple approach)
    % NOTE: vmtkcenterlines requires seed points (source and target) for centerline extraction.
    % Vessels are expected to be open on at least one z-axis edge
    % Detect endpoints from z-axis edges (openprofiles requires GUI, so we skip it)
    
    centerlines_initial_vtk = fullfile(output_path, 'centerlines_initial.vtk');
    
    % Detect endpoints from segmentation
    % Vessels are open on at least one z-axis edge
        % Read segmentation to detect endpoints on z-axis edges
        mri = MRIread(seg_nii);
        seg = mri.vol > 0;
        
        % Find connected components
        CC = bwconncomp(seg, 26);
        
        % Use the largest component (main vessel)
        [~, largest_idx] = max(cellfun(@length, CC.PixelIdxList));
        voxel_indices = CC.PixelIdxList{largest_idx};
        [x, y, z] = ind2sub(size(seg), voxel_indices);
        
        % Find voxels on z-axis edges (z=1 or z=end)
        z_min = min(z);
        z_max = max(z);
        edge_voxels_min = voxel_indices(z == z_min);
        edge_voxels_max = voxel_indices(z == z_max);
        
        % Get center of mass for each edge
        if ~isempty(edge_voxels_min)
            [x_min, y_min, z_min_coords] = ind2sub(size(seg), edge_voxels_min);
            com_min = [mean(x_min), mean(y_min), mean(z_min_coords)];
        else
            com_min = [mean(x), mean(y), min(z)];
        end
        
        if ~isempty(edge_voxels_max)
            [x_max, y_max, z_max_coords] = ind2sub(size(seg), edge_voxels_max);
            com_max = [mean(x_max), mean(y_max), mean(z_max_coords)];
        else
            com_max = [mean(x), mean(y), max(z)];
        end
        
        % Convert to physical coordinates
        source_point_ras = mri.vox2ras * [com_min(:); 1];
        target_point_ras = mri.vox2ras * [com_max(:); 1];
        source_point = source_point_ras(1:3)';
        target_point = target_point_ras(1:3)';
        
    % Extract centerlines using pointlist seed selector
    cmd = {src.vmtk};
    cmd{end+1} = 'vmtkcenterlines \';
    cmd{end+1} = ['-ifile ' seg_surface_vtk ' \'];
    cmd{end+1} = ['-seedselector pointlist \'];
    cmd{end+1} = ['-sourcepoints ' num2str(source_point(1)) ' ' num2str(source_point(2)) ' ' num2str(source_point(3)) ' \'];
    cmd{end+1} = ['-targetpoints ' num2str(target_point(1)) ' ' num2str(target_point(2)) ' ' num2str(target_point(3)) ' \'];
    cmd{end+1} = ['-ofile ' centerlines_initial_vtk];
    [status, result] = system(strjoin(cmd,newline),'-echo');
    
    % Verify centerlines were created successfully
    if status ~= 0 || ~exist(centerlines_initial_vtk,'file') || dir(centerlines_initial_vtk).bytes == 0
        warning('Centerline extraction failed or produced empty file. Stopping at Step 3 for visualization.');
    end
    
    % Visualize surface mesh and segmentation volume
    fprintf('\n=== Step 3 Complete: Surface Mesh Created ===\n');
    surf_info = dir(seg_surface_vtk);
    fprintf('Surface mesh: %s (%d bytes)\n', seg_surface_vtk, surf_info.bytes);
    
    % Check if surface mesh has content
    fid = fopen(seg_surface_vtk, 'r');
    if fid ~= -1
        header = fgetl(fid);
        points_line = fgetl(fid);
        while ~feof(fid) && ~contains(points_line, 'POINTS')
            points_line = fgetl(fid);
        end
        if contains(points_line, 'POINTS')
            num_points = sscanf(points_line, 'POINTS %d');
            fprintf('  Number of points in mesh: %d\n', num_points);
        end
        fclose(fid);
    end
    
    % Read segmentation for visualization
    mri = MRIread(seg_nii);
    seg = mri.vol > 0;
    
    % Create visualization showing segmentation volume
    fprintf('\nVisualizing segmentation volume...\n');
    fprintf('Surface mesh saved to: %s\n', seg_surface_vtk);
    
    % Try VMTK native viewer (may fail if no display available)
    fprintf('\nAttempting VMTK native viewer...\n');
    viewer_cmd = {src.vmtk};
    viewer_cmd{end+1} = ['vmtksurfacereader -ifile ' seg_surface_vtk ' --pipe vmtkrenderer --pipe vmtksurfaceviewer'];
    [viewer_status, viewer_result] = system(strjoin(viewer_cmd,newline),'-echo');
    
    if viewer_status ~= 0
        fprintf('VMTK viewer failed (likely no display available).\n');
        fprintf('\nAlternative visualization options:\n');
        fprintf('  1. ParaView: File > Open > %s\n', seg_surface_vtk);
        fprintf('  2. freeview: freeview -f %s\n', seg_surface_vtk);
        fprintf('  3. MATLAB: Use volumeViewer or try reading VTK with external tools\n');
    end
    
    % Show segmentation volume slices
    figure('Name','Segmentation Volume and Surface Mesh','Position',[100 100 1200 600]);
    subplot(2,3,1);
    mid_slice = round(size(seg,3)/2);
    imagesc(seg(:,:,mid_slice)); axis image; colormap gray; title(sprintf('Z-slice %d', mid_slice));
    
    subplot(2,3,2);
    mid_y = round(size(seg,2)/2);
    imagesc(squeeze(seg(:,mid_y,:))); axis image; colormap gray; title(sprintf('Y-slice %d', mid_y));
    
    subplot(2,3,3);
    mid_x = round(size(seg,1)/2);
    imagesc(squeeze(seg(mid_x,:,:))); axis image; colormap gray; title(sprintf('X-slice %d', mid_x));
    
    % Show 3D isosurface of segmentation
    subplot(2,3,[4 5 6]);
    [x, y, z] = ind2sub(size(seg), find(seg));
    scatter3(x(1:10:end), y(1:10:end), z(1:10:end), 1, 'filled', 'MarkerFaceAlpha', 0.1);
    xlabel('X'); ylabel('Y'); zlabel('Z');
    title('Segmentation Volume (sampled points)');
    axis equal; grid on;
    
    % Return early for visualization
    centerlines_vtk = centerlines_initial_vtk;
    centerlines_with_radius_vtk = [];
    return;
    
    % Step 4: Refine centerlines with intensity image (Phase 2 - if provided)
    % Note: This is exploratory - need to check VMTK documentation for actual options
    % For now, use the same centerlines (refinement can be added later)
    centerlines_vtk = centerlines_initial_vtk;
    
    % Step 5: Explore integrated approaches (Phase 3 - future enhancement)
    % This will require investigation of VMTK capabilities
    
    % Step 6: Compute radius information along centerlines
    % vmtkcenterlines already computes MaximumInscribedSphereRadius by default
    % vmtkcenterlinegeometry computes additional geometric properties
    centerlines_with_radius_vtk = fullfile(output_path, 'centerlines_with_radius.vtk');
    cmd = {src.vmtk};
    cmd{end+1} = 'vmtkcenterlinegeometry \';
    cmd{end+1} = ['-ifile ' centerlines_vtk ' \'];
    cmd{end+1} = ['-ofile ' centerlines_with_radius_vtk];
    [status, result] = system(strjoin(cmd,newline),'-echo');
    
    % Verify centerlines with radius were created successfully
    if status ~= 0 || ~exist(centerlines_with_radius_vtk,'file') || dir(centerlines_with_radius_vtk).bytes == 0
        error('Centerline geometry computation failed. Check terminal output for details.');
    end
    
    % Step 7: Generate vessel wall mesh from centerlines and radii
    % NOTE: Temporarily disabled for debugging - will re-enable later
    % vmtkcenterlinemodeller creates a volume image from centerlines, then extract surface
    % vessel_volume_vti = fullfile(output_path, 'vessel_volume.vti');
    % cmd = {src.vmtk};
    % cmd{end+1} = 'vmtkcenterlinemodeller \';
    % cmd{end+1} = ['-ifile ' centerlines_with_radius_vtk ' \'];
    % cmd{end+1} = ['-radiusarray MaximumInscribedSphereRadius \'];
    % cmd{end+1} = ['-ofile ' vessel_volume_vti];
    % [status, result] = system(strjoin(cmd,newline),'-echo');
    % 
    % % Verify vessel volume was created successfully
    % if status ~= 0 || ~exist(vessel_volume_vti,'file') || dir(vessel_volume_vti).bytes == 0
    %     error('Vessel volume creation failed. Check terminal output for details.');
    % end
    % 
    % % Step 8: Extract surface mesh from vessel volume for visualization
    % vessel_mesh_vtk = fullfile(output_path, 'vessel_walls.vtk');
    % cmd = {src.vmtk};
    % cmd{end+1} = ['vmtkimagereader -ifile ' vessel_volume_vti ' --pipe vmtkmarchingcubes --pipe vmtksurfacewriter -ofile ' vessel_mesh_vtk];
    % [status, result] = system(strjoin(cmd,newline),'-echo');
    % 
    % % Verify vessel mesh was created successfully
    % if status ~= 0 || ~exist(vessel_mesh_vtk,'file') || dir(vessel_mesh_vtk).bytes == 0
    %     error('Vessel mesh extraction failed. Check terminal output for details.');
    % end
    % 
    % % Note: VTK format should work with freeview for visualization
    % % If FreeSurfer format conversion is needed later, can use mris_convert or similar tools
    
end
