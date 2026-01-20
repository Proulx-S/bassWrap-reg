function centerline_vtk = skeleton_to_vtk_centerline(skeleton_nii, output_vtk, options)
%SKELETON_TO_VTK_CENTERLINE Convert skeleton volume to VTK polydata centerline using VMTK
%   Converts a binary skeleton volume (NIfTI) to VTK polydata centerline format
%   suitable as input for vmtkactivetubes
%
%   Inputs:
%       skeleton_nii - Path to skeleton NIfTI file (binary volume)
%       output_vtk   - Path to output VTK polydata file (.vtk or .vtp)
%       options      - Optional struct with parameters
%
%   Outputs:
%       centerline_vtk - Path to created VTK file
%
%   Approach: Uses VMTK tools to convert skeleton volume to centerline polydata:
%   1. Convert skeleton NIfTI to VTK image format
%   2. Create surface mesh from skeleton using marching cubes
%   3. Extract centerlines from surface using vmtkcenterlines
%   Note: This creates a proper centerline polydata from the skeleton volume

global src;
if nargin < 3 || isempty(options); options = struct(); end

% Ensure output directory exists
[output_dir, ~, ~] = fileparts(output_vtk);
if ~isempty(output_dir) && ~exist(output_dir,'dir')
    mkdir(output_dir);
end

% Step 1: Convert skeleton NIfTI to VTK image format
skeleton_vti = fullfile(output_dir, 'skeleton_temp.vti');
cmd = {src.vmtk};
cmd{end+1} = ['vmtkimagereader -ifile ' skeleton_nii ' --pipe vmtkimagewriter -ofile ' skeleton_vti];
system(strjoin(cmd,newline),'-echo');

% Step 2: Create surface mesh from skeleton using marching cubes
% The skeleton is already thin, so marching cubes will create a surface representation
skeleton_surface_vtk = fullfile(output_dir, 'skeleton_surface_temp.vtk');
cmd = {src.vmtk};
cmd{end+1} = ['vmtkimagereader -ifile ' skeleton_vti ' --pipe vmtkmarchingcubes --pipe vmtksurfacewriter -ofile ' skeleton_surface_vtk];
system(strjoin(cmd,newline),'-echo');

% Step 3: Extract centerlines from skeleton surface
% Since the skeleton is already a centerline representation, we can use
% vmtkcenterlines with appropriate seed selection
% Using carotidprofiles seed selector (works for vessels oriented along z-axis)
cmd = {src.vmtk};
cmd{end+1} = 'vmtkcenterlines \';
cmd{end+1} = ['-ifile ' skeleton_surface_vtk ' \'];
cmd{end+1} = ['-seedselector carotidprofiles \'];
cmd{end+1} = ['-ofile ' output_vtk];
[status, result] = system(strjoin(cmd,newline),'-echo');

% Verify centerlines were created successfully
if status ~= 0 || ~exist(output_vtk,'file') || dir(output_vtk).bytes == 0
    error('Centerline extraction from skeleton failed. Check terminal output for details.');
end

% Clean up temporary files
if exist(skeleton_vti,'file'); delete(skeleton_vti); end
if exist(skeleton_surface_vtk,'file'); delete(skeleton_surface_vtk); end

centerline_vtk = output_vtk;

end
