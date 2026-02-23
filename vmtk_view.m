function vmtk_view(fileList, printFlag)
%VMTK_VIEW Display one NIfTI volume and/or one or more VTK surfaces/centerlines (no transform).
%
%   vmtk_view(fileList)
%   vmtk_view(fileList, printFlag)
%
%   Inputs:
%       fileList  - Cell or string array of file paths. At most one NIfTI (.nii,
%                   .nii.gz); any number of VTK (.vtk, .vtp). NIfTI is shown as
%                   volume; each VTK is shown as a separate surface/centerline in
%                   the same window (Shared Renderer: reader1->renderer->viewer1,
%                   then reader2->viewer2 -i @vmtksurfacereader.o, etc.). No merge,
%                   no spatial transformation.
%       printFlag - Optional. If true (default), write the VMTK command to a .cmd
%                   file in the current directory instead of running it.
%
%   Examples:
%       vmtk_view({volumeNii, centerline1.vtk, centerline2.vtk})
%       vmtk_view({surfaceVtk})
%       vmtk_view({refNii, centerline1.vtk, centerline2.vtk}, 0)
%
%   See also vmtk_viewVol, vmtk_viewVolAndSurf, mergeCenterlines.

global src;

if nargin < 1
    error('vmtk_view:NotEnoughInputs', 'At least one input required: fileList');
end
if nargin < 2 || isempty(printFlag)
    printFlag = 1;
end

if ischar(fileList) || isstring(fileList)
    fileList = cellstr(fileList);
end
if isempty(fileList)
    error('vmtk_view:EmptyList', 'fileList must not be empty.');
end

niiList = {};
vtkList = {};
for i = 1:numel(fileList)
    f = fileList{i};
    if ~exist(f, 'file')
        error('vmtk_view:FileNotFound', 'File not found: %s', f);
    end
    [~, ~, ext] = fileparts(f);
    if strcmpi(ext, '.gz')
        [~, ~, ext] = fileparts(f(1:end-3));
    end
    if strcmpi(ext, '.nii')
        niiList{end+1} = f;
    elseif strcmpi(ext, '.vtk') || strcmpi(ext, '.vtp')
        vtkList{end+1} = f;
    else
        error('vmtk_view:UnknownType', 'Unknown file type (expected .nii/.nii.gz or .vtk/.vtp): %s', f);
    end
end

if numel(niiList) > 1
    error('vmtk_view:TooManyNifti', 'At most one NIfTI allowed; got %d.', numel(niiList));
end

if isempty(niiList) && isempty(vtkList)
    error('vmtk_view:NoValidFiles', 'No NIfTI or VTK files in fileList.');
end

% Shared Renderer pattern (no merging): first reader -> renderer -> first viewer
% (piped), then for each extra surface: reader -> viewer -i @vmtksurfacereader.o
% Display: 0 = invisible, 1 = visible. Only the last viewer gets -display 1.
% First surface color is green; then red, blue, ...
surfaceColors = [0 1 0; 1 0 0; 0 0 1; 1 1 0; 0 1 1; 1 0 1; 1 0.5 0]; % green, red, blue, yellow, cyan, magenta, orange
cmd = {src.vmtk};

if ~isempty(niiList)
    cmd{end+1} = ['vmtkimagereader -ifile ' niiList{1} ' \'];
end
if numel(vtkList) >= 1
    cmd{end+1} = ['--pipe vmtksurfacereader -ifile ' vtkList{1} ' \'];
end
cmd{end+1} = ['--pipe vmtkrenderer \'];
if ~isempty(niiList)
    isLastViewer = (numel(vtkList) == 0);
    cmd{end+1} = ['--pipe vmtkimageviewer -i @vmtkimagereader.o -display ' num2str(double(isLastViewer)) ' -textureinterpolation 0 \'];
end
if numel(vtkList) >= 1
    rgb = surfaceColors(1 + mod(0, size(surfaceColors, 1)), :);
    isLastViewer = (numel(vtkList) == 1);
    cmd{end+1} = ['--pipe vmtksurfaceviewer -color ' sprintf('%g %g %g', rgb(1), rgb(2), rgb(3)) ' -display ' num2str(double(isLastViewer)) ' \'];
end
for v = 2:numel(vtkList)
    cmd{end+1} = ['--pipe vmtksurfacereader -ifile ' vtkList{v} ' \'];
    rgb = surfaceColors(1 + mod(v-1, size(surfaceColors, 1)), :);
    isLastViewer = (v == numel(vtkList));
    cmd{end+1} = ['--pipe vmtksurfaceviewer -i @vmtksurfacereader.o -color ' sprintf('%g %g %g', rgb(1), rgb(2), rgb(3)) ' -display ' num2str(double(isLastViewer)) ' \'];
end
% Remove trailing backslash from last line
if ~isempty(cmd) && cmd{end}(end) == '\'
    cmd{end} = strtrim(cmd{end}(1:end-1));
end

if printFlag
    cmd_file = fullfile(pwd, 'vmtk_view.cmd');
    fid = fopen(cmd_file, 'w');
    if fid == -1
        error('vmtk_view:WriteFailed', 'Could not create command file: %s', cmd_file);
    end
    fprintf(fid, '%s\n', cmd{:});
    fclose(fid);
    fprintf('Command file created: %s\n', cmd_file);
else
    system(strjoin(cmd, newline), '-echo');
end
end
