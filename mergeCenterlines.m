function output_vtk = mergeCenterlines(fCenterlineList, output_vtk)
%MERGECENTERLINES Merge centerline VTK files into one (no coordinate transform).
%
%   output_vtk = mergeCenterlines(fCenterlineList)
%   output_vtk = mergeCenterlines(fCenterlineList, output_vtk)
%
%   Appends all centerline VTKs into a single file using vtkAppendPolyData.
%   No NIfTI or coordinate harmonization: geometry is concatenated as-is.
%
%   Inputs:
%       fCenterlineList - Cell array of paths to centerline VTK files.
%       output_vtk     - Optional. Output path. If omitted, writes
%                        combined_centerlines.vtk next to the first centerline.
%
%   Outputs:
%       output_vtk - Path to the written combined centerline VTK file.

if nargin < 1
    error('mergeCenterlines:NotEnoughInputs', ...
        'At least one input required: fCenterlineList');
end

if ~iscell(fCenterlineList)
    fCenterlineList = {fCenterlineList};
end

if numel(fCenterlineList) < 1
    error('mergeCenterlines:EmptyList', 'fCenterlineList must not be empty.');
end

if nargin < 2 || isempty(output_vtk)
    [baseDir, ~, ext] = fileparts(fCenterlineList{1});
    output_vtk = fullfile(baseDir, ['combined_centerlines' ext]);
end

script_dir = fileparts(mfilename('fullpath'));
py_script = fullfile(script_dir, 'merge_centerlines.py');

cmd = sprintf('python "%s" --output "%s" --centerlines', py_script, output_vtk);
for v = 1:numel(fCenterlineList)
    cmd = [cmd ' "' fCenterlineList{v} '"'];
end

global src;
if isfield(src, 'nipype') && ~isempty(src.nipype)
    cmd = [src.nipype '; ' cmd];
end

[status, err] = system(cmd, '-echo');
if status ~= 0
    error('mergeCenterlines:ScriptFailed', 'merge_centerlines.py failed: %s', err);
end

if ~exist(output_vtk, 'file')
    error('mergeCenterlines:OutputMissing', 'Output file was not created: %s', output_vtk);
end

end
