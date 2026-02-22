function output_vtk = merge_centerlines_to_vtk(fCenterlineList, fTofList, fTofRef, output_vtk)
%MERGE_CENTERLINES_TO_VTK Merge vessel centerline VTKs into one VTK for vmtk_viewVolAndSurf.
%
%   output_vtk = merge_centerlines_to_vtk(fCenterlineList, fTofList, fTofRef)
%   output_vtk = merge_centerlines_to_vtk(fCenterlineList, fTofList, fTofRef, output_vtk)
%
%   Transforms each centerline from vessel voxel to RAS, then to the reference
%   volume display space so the combined VTK overlays correctly in vmtk_viewVolAndSurf.
%
%   Inputs:
%       fCenterlineList - Cell array of paths to centerline VTK files (one per vessel).
%       fTofList        - Cell array of paths to vessel NIfTI files (same order).
%       fTofRef         - Reference NIfTI path (volume used when viewing; e.g. subject ToF).
%       output_vtk     - Optional. Output combined VTK path. If omitted, writes
%                        combined_centerlines.vtk in the same directory as the first centerline.
%
%   Outputs:
%       output_vtk - Path to the written combined centerline VTK file.

if nargin < 3
    error('merge_centerlines_to_vtk:NotEnoughInputs', ...
        'At least 3 inputs required: fCenterlineList, fTofList, fTofRef');
end

if ~iscell(fCenterlineList)
    fCenterlineList = {fCenterlineList};
end
if ~iscell(fTofList)
    fTofList = {fTofList};
end

if numel(fCenterlineList) ~= numel(fTofList)
    error('merge_centerlines_to_vtk:LengthMismatch', ...
        'fCenterlineList and fTofList must have the same length.');
end

if nargin < 4 || isempty(output_vtk)
    [baseDir, ~, ext] = fileparts(fCenterlineList{1});
    output_vtk = fullfile(baseDir, ['combined_centerlines' ext]);
end

if ~exist(fTofRef, 'file')
    error('merge_centerlines_to_vtk:FileNotFound', 'Reference NIfTI not found: %s', fTofRef);
end

script_dir = fileparts(mfilename('fullpath'));
py_script = fullfile(script_dir, 'merge_centerlines_to_vtk.py');

% Build command: python script --reference ref --output out --centerlines c1 c2 ... --niftis n1 n2 ...
cmd = sprintf('python "%s" --reference "%s" --output "%s" --centerlines', py_script, fTofRef, output_vtk);
for v = 1:numel(fCenterlineList)
    cmd = [cmd ' "' fCenterlineList{v} '"'];
end
cmd = [cmd ' --niftis'];
for v = 1:numel(fTofList)
    cmd = [cmd ' "' fTofList{v} '"'];
end

% Use nipype environment if available (has nibabel and VTK)
global src;
if isfield(src, 'nipype') && ~isempty(src.nipype)
    cmd = [src.nipype '; ' cmd];
end

[status, err] = system(cmd, '-echo');
if status ~= 0
    error('merge_centerlines_to_vtk:ScriptFailed', 'merge_centerlines_to_vtk.py failed: %s', err);
end

if ~exist(output_vtk, 'file')
    error('merge_centerlines_to_vtk:OutputMissing', 'Output file was not created: %s', output_vtk);
end

end
