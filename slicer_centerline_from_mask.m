function centerline_vtk = slicer_centerline_from_mask(mask_nii, output_vtk, options)
%SLICER_CENTERLINE_FROM_MASK Extract centerline from binary mask using 3D Slicer Extract Skeleton
%
%   Uses 3D Slicer's built-in ExtractSkeleton (1D centerline) and writes
%   VTK PolyData. All coordinate handling is done by Slicer; no manual
%   vox2ras or transform.
%
%   Usage:
%     centerline_vtk = slicer_centerline_from_mask(mask_nii, output_vtk)
%     centerline_vtk = slicer_centerline_from_mask(mask_nii, output_vtk, options)
%
%   Inputs:
%     mask_nii   - Path to binary mask NIfTI (non-zero = foreground), e.g. vessel
%                  segmentation. Pre-skeletonized volumes also work. Slicer performs
%                  thinning internally, so you can pass the mask directly (no need to
%                  run bwskel first).
%     output_vtk - Path to output VTK PolyData (.vtk or .vtp)
%     options    - Optional struct:
%       .slicerPath - Path to Slicer executable (fallback if src.slicer not set)
%       .fullTree   - (default: false) If false, only the maximal center skeleton
%                     (longest single path through the object) is returned. If true,
%                     the full skeleton tree including all branches (e.g. bifurcations)
%                     is returned. Use false for a single unbranched vessel; use true
%                     for vessel trees. If you get "points file is empty", retry with
%                     fullTree = true.
%       .numPoints  - Number of skeleton points (default: 100)
%       .useXvfb    - On Linux, prepend xvfb-run for headless when no DISPLAY (default: false)
%       .slicerOutputCoordinates - 'ras' (default) or 'lps'. ExtractSkeleton outputs in
%         the volume's coordinate system (typically RAS). Use 'ras' for no conversion.
%         If centerlines are misaligned, try 'lps' to apply LPS→RAS conversion.
%
%   Slicer path resolution order (same style as src.vmtk in doIt.m):
%     1) global src.slicer
%     2) options.slicerPath
%     3) environment SLICER_HOME (append /Slicer or /bin/Slicer as applicable)
%     4) environment SLICER (used as-is)
%     5) 'Slicer' (must be in PATH)
%
%   Requires: 3D Slicer installed. On Linux without display, xvfb-run (useXvfb=true).
%
%   Example (replace bwskel + skeleton_to_vtk_centerline in doIt.m):
%     % Slicer does thinning internally; pass vessel seg directly:
%     centerline_vtk = slicer_centerline_from_mask(tof_vesselSeg, 'centerline.vtk');
%
%   Setup: Install 3D Slicer, then set src.slicer before calling (e.g. in doIt.m
%     alongside src.vmtk):  src.slicer = '/path/to/Slicer'
%     Fallbacks: options.slicerPath, SLICER_HOME, SLICER, or Slicer in PATH.
%
%   See also: skeleton_to_vtk_centerline (VMTK-based), slicer_extract_skeleton_to_vtk.py

    if nargin < 3 || isempty(options); options = struct(); end

    % Options
    if ~isfield(options, 'fullTree');   options.fullTree   = false; end
    if ~isfield(options, 'numPoints');  options.numPoints  = 100;   end
    if ~isfield(options, 'useXvfb');    options.useXvfb    = false; end  % set true only if xvfb-run installed and no DISPLAY
    if ~isfield(options, 'slicerOutputCoordinates'); options.slicerOutputCoordinates = 'ras'; end

    if ~exist(mask_nii, 'file')
        error('slicer_centerline_from_mask:InputNotFound', 'Mask file not found: %s', mask_nii);
    end

    [out_dir, ~, ~] = fileparts(output_vtk);
    if ~isempty(out_dir) && ~exist(out_dir, 'dir')
        mkdir(out_dir);
    end

    % Resolve Slicer executable
    slicer_exe = resolve_slicer(options);
    if isempty(slicer_exe)
        error('slicer_centerline_from_mask:NoSlicer', ...
            'Slicer not found. Set src.slicer (e.g. in doIt.m with src.vmtk), or options.slicerPath, SLICER_HOME, or SLICER.');
    end

    % Path to Python script (next to this .m)
    mpath = fileparts(mfilename('fullpath'));
    py_script = fullfile(mpath, 'slicer_extract_skeleton_to_vtk.py');
    if ~exist(py_script, 'file')
        error('slicer_centerline_from_mask:ScriptNotFound', ...
            'slicer_extract_skeleton_to_vtk.py not found at: %s', py_script);
    end

    % Build: [xvfb-run -a] Slicer ... -- in out [--fullTree] [--numPoints N] [--inCoordinates lps|ras]
    coords = options.slicerOutputCoordinates;
    if ~ismember(coords, {'lps','ras'}), coords = 'lps'; end

    args = {slicer_exe, '--no-splash', '--no-main-window', '--python-script', py_script, '--', mask_nii, output_vtk};
    if options.fullTree
        args{end+1} = '--fullTree';
    end
    args{end+1} = '--numPoints';
    args{end+1} = num2str(options.numPoints);
    args{end+1} = '--inCoordinates';
    args{end+1} = coords;

    if options.useXvfb && isunix && ~ismac
        args = [{'xvfb-run', '-a'}, args];
    end

    cmd = strjoin(args, ' ');
    [status, result] = system([cmd ' 2>&1'], '-echo');

    if status ~= 0
        if contains(result, 'points file is empty')
            error('slicer_centerline_from_mask:EmptyPoints', ...
                ['ExtractSkeleton points file is empty (skeleton may have 0 or 1 point).\n' ...
                 'Retry with options.fullTree = true, e.g.:\n' ...
                 '  slicer_centerline_from_mask(mask_nii, output_vtk, struct(''fullTree'', true));\n%s'], result);
        end
        error('slicer_centerline_from_mask:RunFailed', ...
            'Slicer ExtractSkeleton failed (status=%d). Check that Slicer is installed and the mask is binary.\n%s', status, result);
    end
    if ~exist(output_vtk, 'file') || dir(output_vtk).bytes == 0
        error('slicer_centerline_from_mask:NoOutput', ...
            'Output VTK missing or empty: %s', output_vtk);
    end

    centerline_vtk = output_vtk;
end


function exe = resolve_slicer(options)
    % 1) global src.slicer (same style as src.vmtk in doIt.m)
    try
        global src;
        if isfield(src, 'slicer') && ~isempty(src.slicer)
            exe = [src.slicer '; Slicer'];
            return;
        end
    catch
    end

    % 2) options.slicerPath
    if isfield(options, 'slicerPath') && ~isempty(options.slicerPath)
        p = options.slicerPath;
        if isfolder(p)
            for sub = {'Contents/MacOS/Slicer', 'Slicer', 'bin/Slicer'}
                cand = fullfile(p, sub{1});
                if isfile(cand)
                    exe = cand;
                    return;
                end
            end
            exe = fullfile(p, 'Slicer');
        else
            exe = p;
        end
        if isfile(exe)
            return;
        end
    end

    % 3) SLICER_HOME
    sh = getenv('SLICER_HOME');
    if ~isempty(sh)
        for sub = {'Contents/MacOS/Slicer', 'Slicer', 'bin/Slicer'}
            cand = fullfile(sh, sub{1});
            if isfile(cand)
                exe = cand;
                return;
            end
        end
    end

    % 4) SLICER (full path or command)
    sl = getenv('SLICER');
    if ~isempty(sl)
        exe = sl;
        return;
    end

    % 5) 'Slicer' (must be in PATH)
    exe = 'Slicer';
end
