function centerline_vtk = vmtk_activetubes(intensity_nii, initial_centerline_vtk, output_vtk, options)
%VMTK_ACTIVETUBES Refine centerlines using vmtkactivetubes
%   Uses vmtkactivetubes to refine initial centerlines using intensity image
%
%   Inputs:
%       intensity_nii        - Path to intensity NIfTI image
%       initial_centerline_vtk - Path to initial centerline VTK polydata file
%       output_vtk           - Path to output refined centerline VTK file
%       options              - Optional struct with parameters
%
%   Outputs:
%       centerline_vtk - Path to refined centerline VTK file

global src;
if nargin < 4 || isempty(options); options = struct(); end

% Set default options
if ~isfield(options, 'iterations'); options.iterations = 100; end
if ~isfield(options, 'potentialweight'); options.potentialweight = 1.0; end
if ~isfield(options, 'stiffnessweight'); options.stiffnessweight = 1.0; end

% Ensure output directory exists
[output_dir, ~, ~] = fileparts(output_vtk);
if ~isempty(output_dir) && ~exist(output_dir,'dir')
    mkdir(output_dir);
end

% Convert intensity NIfTI to VTK image format
intensity_vti = fullfile(output_dir, 'intensity_temp.vti');
cmd = {src.vmtk};
cmd{end+1} = ['vmtkimagereader -ifile ' intensity_nii ' --pipe vmtkimagewriter -ofile ' intensity_vti];
system(strjoin(cmd,newline),'-echo');

% Run vmtkactivetubes
cmd = {src.vmtk};
cmd{end+1} = 'vmtkactivetubes \';
cmd{end+1} = ['-imagefile ' intensity_vti ' \'];
cmd{end+1} = ['-ifile ' initial_centerline_vtk ' \'];
cmd{end+1} = ['-iterations ' num2str(options.iterations) ' \'];
cmd{end+1} = ['-potentialweight ' num2str(options.potentialweight) ' \'];
cmd{end+1} = ['-stiffnessweight ' num2str(options.stiffnessweight) ' \'];
cmd{end+1} = ['-ofile ' output_vtk];
[status, result] = system(strjoin(cmd,newline),'-echo');

% Verify centerlines were created successfully
if status ~= 0 || ~exist(output_vtk,'file') || dir(output_vtk).bytes == 0
    error('vmtkactivetubes failed. Check terminal output for details.');
end

% Clean up temporary files
if exist(intensity_vti,'file'); delete(intensity_vti); end

centerline_vtk = output_vtk;

end
