function output_dir = run_centerline_coord_tests(fCenterlineList, fTofList, fTofRef, output_dir)
%RUN_CENTERLINE_COORD_TESTS Write five centerline VTKs in different coordinate spaces for overlay tests.
%
%   output_dir = run_centerline_coord_tests(fCenterlineList, fTofList, fTofRef)
%   output_dir = run_centerline_coord_tests(fCenterlineList, fTofList, fTofRef, output_dir)
%
%   Same inputs as merge_centerlines_to_vtk. Writes five test VTKs into
%   coord_tests/ (or output_dir): test_1_ras.vtk, test_2_ref_display.vtk,
%   test_3_ref_voxel.vtk, test_4_lps.vtk, test_5_ras_minus_ref_origin.vtk.
%
%   View each with two-arg vmtk_viewVolAndSurf only, e.g.:
%     vmtk_viewVolAndSurf(fTofRef, fullfile(output_dir, 'test_1_ras.vtk'))
%
%   Inputs:
%       fCenterlineList - Cell array of paths to centerline VTK files (one per vessel).
%       fTofList        - Cell array of paths to vessel NIfTI files (same order).
%       fTofRef         - Reference NIfTI path (volume used when viewing).
%       output_dir     - Optional. Directory for the five test VTKs. Default:
%                        fullfile(fileparts(fCenterlineList{1}), 'coord_tests').
%
%   Outputs:
%       output_dir - Directory containing the five test VTK files.

if nargin < 3
    error('run_centerline_coord_tests:NotEnoughInputs', ...
        'At least 3 inputs required: fCenterlineList, fTofList, fTofRef');
end

if ~iscell(fCenterlineList)
    fCenterlineList = {fCenterlineList};
end
if ~iscell(fTofList)
    fTofList = {fTofList};
end

if numel(fCenterlineList) ~= numel(fTofList)
    error('run_centerline_coord_tests:LengthMismatch', ...
        'fCenterlineList and fTofList must have the same length.');
end

if nargin < 4 || isempty(output_dir)
    baseDir = fileparts(fCenterlineList{1});
    output_dir = fullfile(baseDir, 'coord_tests');
end

if ~exist(fTofRef, 'file')
    error('run_centerline_coord_tests:FileNotFound', 'Reference NIfTI not found: %s', fTofRef);
end

script_dir = fileparts(mfilename('fullpath'));
py_script = fullfile(script_dir, 'merge_centerlines_coord_tests.py');

% python script --reference ref --output-dir dir --centerlines c1 c2 ... --niftis n1 n2 ...
cmd = sprintf('python "%s" --reference "%s" --output-dir "%s" --centerlines', ...
    py_script, fTofRef, output_dir);
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
    error('run_centerline_coord_tests:ScriptFailed', ...
        'merge_centerlines_coord_tests.py failed: %s', err);
end

expected = {'test_1_ras.vtk', 'test_2_ref_display.vtk', 'test_3_ref_voxel.vtk', ...
    'test_4_lps.vtk', 'test_5_ras_minus_ref_origin.vtk'};
for i = 1:numel(expected)
    p = fullfile(output_dir, expected{i});
    if ~exist(p, 'file')
        error('run_centerline_coord_tests:OutputMissing', 'Test output not created: %s', p);
    end
end

end
