function rho = imCorr(fRun,fMaskE)


    if ischar(fRun)
        mri    = MRIread(fRun);
        im     = single(mri.vol);

        mri    = MRIread(fMaskE);
        imMask = ~logical(mri.vol);

        im = permute(im,[4 1 2 3]);
        rho = corr(permute(im(:,imMask),[2 1]));
    else
        im = permute(fRun,[3 1 2]);
        if exist('fMaskE','var') && ~isempty(fMaskE)
            rho = corr(permute(im(:,logical(-(fMaskE-1))),[2 1]));
        else
            rho = corr(permute(im(:,:),[2 1]));
        end
    end


    fFig = figure('Menu','none','ToolBar','none');
    imagesc(rho.^2,[0 1]);
    axis image
    ylabel(colorbar,'cross-frame Pearson''s correlation^2');


    % tr = mri.tr/1000;
    % xline(60/tr,'r');
    % yline(60/tr,'r');



    
