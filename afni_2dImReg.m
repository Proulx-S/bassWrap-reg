function param = afni_2dImReg(fSource,fBase,fOut,spSmFac,confirmFlag)
    global src
    if ~exist('confirmFlag','var') || isempty(confirmFlag); confirmFlag = false; end
    if ~exist('spSmFac','var'); spSmFac = []; end

    fOut = replace(fOut,'.nii.gz','');
    if exist([fOut '.nii.gz'],'file')
        delete([fOut '.nii.gz'])
    end

    cmd = {src.afni};
    %%% moco
    cmd{end+1} = '2dImReg -overwrite \';
    cmd{end+1} = ['-input '    fSource ' \'];
    cmd{end+1} = ['-basefile ' fBase ' \'];
    if ~isempty(spSmFac)
        cmd{end+1} = ['-fine ' num2str(spSmFac) ' 0.07 0.21 \'];
    end
    cmd{end+1} = ['-prefix ' [fOut '.nii.gz'] ' \'];
    cmd{end+1} = ['-dprefix ' fOut ' \'];
    cmd{end+1} = ['-rprefix ' fOut];


    disp('2dImReg: running')
    [status,cmdout] = system(strjoin(cmd,newline)); if status || isempty(cmdout); dbstack; error(cmdout); error('x'); end
    disp('2dImReg: done')




    % Read back motion parameters
    X = readmatrix([fOut '.dx' ],'FileType','text');
    Y = readmatrix([fOut '.dy' ],'FileType','text');
    a = readmatrix([fOut '.psi'],'FileType','text');

    % Adjust for image orientation
    mri = MRIread(fSource,1);
    switch replace(num2str(mri.volsize>1),' ','')
        case '110'
            xDim = 1;
            yDim = 2;
            X = -X(:,2);
            Y =  Y(:,2);
            a =  a(:,2);
        otherwise
            dbstack; error('figure that out')
    end

    % Compensate the weird rotation influence on x translation
    % yes this is weird but it really seem to be the case
    X = X - a;

    % Convert to mm
    param = cat(2,X .* mri.volres(xDim),Y .* mri.volres(yDim),a);



    %% Confirm 3dAllineate movement parameters
    if confirmFlag
        i = 1;
        fOut    = [fOut '.nii.gz'];
        fOut2   = replace(fOut,'.nii.gz','_allin.nii.gz');


        trans = [param(i,1) 0 param(i,2)];
        rot   = [0 0 param(i,3)];
        afni_applyAffine([fSource '[' num2str(i-1) ']'],trans,rot,fOut2)


        mriSource = MRIread(fSource); mriSource = mriSource.vol(:,:,:,i);
        mriBase   = MRIread(fBase  ); mriBase   = mriBase.vol(:,:,:,i);
        mriOut    = MRIread(fOut   ); mriOut    = mriOut.vol(:,:,:,i);
        mriOut2   = MRIread(fOut2  ); mriOut2   = mriOut2.vol(:,:,:,i);


        fig = figure('Menu','none','ToolBar','none','Name','Figure With Tabs'); tgroup = uitabgroup(fig);

        tab1 = uitab(tgroup,'Title','source image');
        ax1 = axes(tab1);
        imagesc(ax1,mriSource); axis image; colormap gray;
        drawnow;
        
        tab2 = uitab(tgroup,'Title','base image');
        ax2 = axes(tab2);
        imagesc(ax2,mriBase); axis image; colormap gray;
        drawnow;

        tab3 = uitab(tgroup,'Title','source 2dImReg-registered to base');
        ax3  = axes(tab3);
        imagesc(ax3,mriOut); axis image; colormap gray;
        drawnow;

        tab4 = uitab(tgroup,'Title','2dImReg motion applied with 3dAllineate');
        ax4  = axes(tab4);
        imagesc(ax4,mriOut2); axis image; colormap gray;
        drawnow;

        yLim = mean(ax1.YLim) + [-0.5 0.5]*range(ax1.YLim)/8;
        xLim = mean(ax1.XLim) + [-0.5 0.5]*range(ax1.XLim)/8;
        set([ax1 ax2 ax3 ax4],'YLim',yLim,'XLim',xLim);
    end
