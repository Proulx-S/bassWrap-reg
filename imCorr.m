function rho = imCorr(fRun,fMaskE)


    mri    = MRIread(fMaskE);
    imMask = ~logical(mri.vol);

    mri    = MRIread(fRun);
    im     = single(mri.vol);

    im = permute(im,[4 1 2 3]);
    rho = corr(permute(im(:,imMask),[2 1]));


    fFig = figure('Menu','none','ToolBar','none');
    imagesc(rho.^2,[0 1]);
    axis image
    ylabel(colorbar,'cross-frame Pearson''s correlation^2');


    % tr = mri.tr/1000;
    % xline(60/tr,'r');
    % yline(60/tr,'r');



    
