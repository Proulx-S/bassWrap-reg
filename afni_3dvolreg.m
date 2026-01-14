function cmdout = afni_3dvolreg(fSource,fBase,fMaskE,fOut,spSmFac)
    global src


    afni3dAlineateArg = {'-cost lpa+ZZ' '-interp quintic' '-final wsinc5' '-nopad' '-conv 0' '-nmatch 100%' '-onepass' '-nocmass'};

    cmd = {src.afni};
    %%% moco
    cmd{end+1} = '3dvolreg -overwrite \';
    cmd{end+1} = ['-base ' fBase ' \'];
    cmd{end+1} = ['-prefix ' [fOut '.nii.gz'] ' \'];
    cmd{end+1} = fSource;


    % cmd{end+1} = ['-1Dparam_save ' fOut ' \'];
    % cmd{end+1} = ['-1Dmatrix_save ' fOut ' \'];
    
    % if ~isempty(fMaskE)
    %     disp(['  using mask: ' fMaskE])
    %     cmd{end+1} = ['-emask ' fMaskE ' \'];
    % else
    %     disp('  not using mask')
    % end

    % cmd{end+1} = [strjoin(afni3dAlineateArg,' ') ' \'];
    
    % if spSmFac>0
    %     vSize = MRIread(fSource,1); vSize = vSize.volres;
    %     fineBlur = mean(vSize(1:2))*spSmFac;
    %     cmd{end+1} = ['-fineblur ' num2str(fineBlur) ' \'];
    % end
    
    % cmd{end+1} = '-warp shift_rotate'; % cmd{end+1} = ['-warp shift_rotate -parfix 2 0 -parfix 4 0 -parfix 5 0'];

    [status,cmdout] = system(strjoin(cmd,newline),'-echo'); if status || isempty(cmdout); dbstack; error(cmdout); error('x'); end

