function vmtk_viewVol(volume_nii, printFlag)
    % VMTK_VIEW_VOLUME View a single 3D NIfTI volume in the VMTK viewer
    %
    % Usage:
    %   vmtk_viewVol(volume_nii)
    %   vmtk_viewVol(volume_nii, printFlag)
    %
    % Inputs:
    %   volume_nii - Path to volume NIfTI file (.nii or .nii.gz).
    %   printFlag  - Optional. If true (default), write the VMTK command to a
    %                .cmd file next to the volume instead of running it.
    %
    % Opens the VMTK image viewer on the volume only (no surface/centerline).
    % Texture interpolation is disabled (-textureinterpolation 0) so the image
    % appears pixelated (nearest-neighbor) rather than smoothed.
    %
    % See also: vmtk_viewVolAndSurf
    %
    global src;

    if nargin < 1
        error('vmtk_viewVol requires at least one input: volume_nii');
    end
    if nargin < 2 || isempty(printFlag)
        printFlag = 1;
    end

    if ~exist(volume_nii, 'file')
        error('Volume file not found: %s', volume_nii);
    end

    cmd = {src.vmtk};
    cmd{end+1} = ['vmtkimagereader -ifile ' volume_nii ' \'];
    cmd{end+1} = ['--pipe vmtkrenderer \'];
    cmd{end+1} = ['--pipe vmtkimageviewer -i @vmtkimagereader.o -textureinterpolation 0'];

    if printFlag
        [pth, name, ext] = fileparts(volume_nii);
        if strcmpi(ext, '.gz')
            [~, base] = fileparts(name);
        else
            base = name;
        end
        cmd_file = fullfile(pth, [base '.cmd']);
        fid = fopen(cmd_file, 'w');
        if fid == -1
            error('Could not create command file: %s', cmd_file);
        end
        fprintf(fid, '%s\n', cmd{:});
        fclose(fid);
        fprintf('Command file created: %s\n', cmd_file);
    else
        system(strjoin(cmd, newline), '-echo');
    end
end
