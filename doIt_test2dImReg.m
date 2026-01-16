clear all
close all
clc
% figure('Menu','none','ToolBar','none');



projectName = 'test2dImReg';
%%%%%%%%%%%%%%%%%%%%%
%% Set up environment
%%%%%%%%%%%%%%%%%%%%%


% Detect computing environment
os   = char(java.lang.System.getProperty('os.name'));
host = char(java.net.InetAddress.getLocalHost.getHostName);
user = char(java.lang.System.getProperty('user.name'));


% Setup folders
if strcmp(os,'Linux') && strcmp(host,'takoyaki') && strcmp(user,'sebp')
    envId      = 1;
    storageDrive = '/scratch/users/Proulx-S/tools/bassWrap-reg/';
    scratchDrive = '/scratch/users/Proulx-S/tools/bassWrap-reg/';
    projectCode    = fullfile(scratchDrive, projectName);        if ~exist(projectCode,'dir');    mkdir(projectCode);    end
    projectStorage = fullfile(storageDrive, projectName);        if ~exist(projectStorage,'dir'); mkdir(projectStorage); end
    projectScratch = fullfile(scratchDrive, projectName, 'tmp'); if ~exist(projectScratch,'dir'); mkdir(projectScratch); end
    toolDir        = '/scratch/users/Proulx-S/tools';            if ~exist(toolDir,'dir');        mkdir(toolDir);        end
else
    envId = 2;
    storageDrive = '/Users/sebastienproulx/bassWrap-reg';
    scratchDrive = '/Users/sebastienproulx/bassWrap-reg';
    projectCode    = fullfile(scratchDrive, projectName);        if ~exist(projectCode,'dir');    mkdir(projectCode);    end
    projectStorage = fullfile(storageDrive, projectName);        if ~exist(projectStorage,'dir'); mkdir(projectStorage); end
    projectScratch = fullfile(scratchDrive, projectName, 'tmp'); if ~exist(projectScratch,'dir'); mkdir(projectScratch); end
    toolDir        = '/Users/sebastienproulx/tools';             if ~exist(toolDir,'dir');        mkdir(toolDir);        end
end

% Load dependencies and set paths
%%% matlab util (contains my matlab git wrapper)
tool = 'util'; toolURL = 'https://github.com/Proulx-S/util.git';
if ~exist(fullfile(toolDir, tool), 'dir'); system(['git clone ' toolURL ' ' fullfile(toolDir, tool)]); end; addpath(genpath(fullfile(toolDir,tool)))
%%% matlab others
tool = 'freesurfer'; subTool = 'matlab'; repoURL = 'https://github.com/freesurfer/freesurfer.git';
gitClone(repoURL, fullfile(toolDir, tool), subTool);
% tool = 'vasomoTools'; subTool = []; repoURL = 'https://github.com/Proulx-S/vasomoTools.git';
% gitClone(repoURL, fullfile(toolDir, tool), subTool);
% tool = 'bassWrap-func'; subTool = []; repoURL = 'https://github.com/Proulx-S/bassWrap-func.git';
% gitClone(repoURL, fullfile(toolDir, tool), subTool);


%%% neurodesk
switch envId
    case 1
        global src    
        setenv('SINGULARITY_BINDPATH',strjoin({projectCode projectStorage projectScratch toolDir},','));
        %%%% afni
        src.afni = 'ml afni/24.3.00';
        system([src.afni '; 3dinfo > /dev/null'],'-echo');
        % %%%% ants
        % src.ants = 'ml ants/2.5.3';
        % system([src.ants '; antsRegistration --version > /dev/null'],'-echo');
        % %%%% freesurfer
        % src.fs   = 'ml freesurfer/8.0.0';
        % system([src.fs   '; mri_convert > /dev/null'],'-echo');
        % %%%% fsl for fslview once we figure out how to make it work
    case 2
        warning('neurodesk not implemented for this environment');
    otherwise
        dbstack; error('not implemented')
        % neurodeskModule = {
        % ":/neurodesktop-storage/containers/freesurfer_8.0.0_20250210"
        % ":/neurodesktop-storage/containers/afni_24.3.00_20241003"};
        % for i = 1:length(neurodeskModule)
        %     if contains(getenv("PATH"),neurodeskModule{i}); continue; end
        %     setenv("PATH",getenv("PATH") + neurodeskModule{i});
        % end
end
%% %%%%%%%%%%%%%%%%%%
projectCode
projectStorage
projectScratch


return


%%%%%%%%%%%%%%%%%%%%%%%%%%%
%% Generate noisy test data
dir(fullfile(projectStorage,'..','sampleData','*.nii.gz'));
dataFile    = fullfile(projectStorage,'..','sampleData','vfMRIsample01.nii.gz');
dataMaskInv = fullfile(projectStorage,'..','sampleData','vfMRIsample01_brainMask.nii.gz');

mri = MRIread(dataFile);

im = squeeze(single(mri.vol));
im = im - min(im(:));
im = im./max(im(:));
im = im + randn(size(im))*0.01;
mri.vol = single(im);
MRIwrite(mri,dataFile);



[~,b,~] = fileparts(replace(dataFile,'.nii.gz',''));
fRun0    = fullfile(projectScratch,[b '.nii.gz']);
fMaskInv = fullfile(projectScratch,[b '_mask.nii.gz']);
copyfile(dataFile   ,fRun0   );
copyfile(dataMaskInv,fMaskInv);



%% Test matlab functions
% GUI
mri = MRIread(fRun0);
im = squeeze(single(mri.vol));
imA = im(:,:,10);
imB = im(:,:,20);
mri10 = mri; mri10.vol = mri.vol(:,:,:,10);
mri20 = mri; mri20.vol = mri.vol(:,:,:,20);
fRun10 = replace(fRun0,'.nii.gz','_10.nii.gz');
fRun20 = replace(fRun0,'.nii.gz','_20.nii.gz');
MRIwrite(mri10,fRun10);
MRIwrite(mri20,fRun20);

registrationEstimator(imA,imB)

medicalRegistrationEstimator(fRun0,fRun0)



% registrationEstimator-generated functions
mri = MRIread(fRun0);
im0 = squeeze(single(mri.vol));
im0 = im0 - min(mri.vol(:));
im0 = im0./max(im0(:));

[dispField,reg] = imreggroupwise(im0(:,:,[10:30 300:320]),'GridRegularization',inf);
[dispField_reguInf,reg_reguInf] = imreggroupwise(im0(:,:,[10:30 300:320]),'GridRegularization',0.11,'GridSpacing',[10 10]);
[dispField_regu1,reg_regu1] = imreggroupwise(im0(:,:,[10:30 300:320]),'GridRegularization',1);
[dispField_regu0,reg_regu0] = imreggroupwise(im0(:,:,[10:30 300:320]),'GridRegularization',0);

figure('Menu','none','ToolBar','none');
cur = dispField_reguInf;
i = 5;
range = [-1 1].*max(max(max(max(abs(cur(:,:,:,i))))));
histogram(cur(:));
% range = [-1 1].*0.1;
subplot(1,2,1);
imagesc(cur(:,:,1,i),range); axis image off; colormap gray;
subplot(1,2,2);
imagesc(cur(:,:,2,i),range); axis image off; colormap gray;
squeeze(mean(cur,[1 2]))

baseIdx = 3;
im0reg_monomodal = zeros(size(im0));
im0reg_phaseCorr = zeros(size(im0));
for ii = 1:size(im0,3)
    disp(['image ' num2str(ii) '/' num2str(size(im0,3))])
    tmp = registerImages_monomodal(im0(:,:,ii),im0(:,:,baseIdx));
    im0_regMono(:,:,ii) = tmp.RegisteredImage;
    tmp = registerImages_phaseCorrelation(im0(:,:,ii),im0(:,:,baseIdx));
    im0_regPhaseCorr(:,:,ii) = tmp.RegisteredImage;
end

im00             = imCorr(im0);
im00regMono      = imCorr(im0_regMono);
im00regPhaseCorr = imCorr(im0_regPhaseCorr);

im00(            diag(true(size(im00,1),1))            ) = nan;
im00regMono(     diag(true(size(im00regMono,1),1))     ) = nan;
im00regPhaseCorr(diag(true(size(im00regPhaseCorr,1),1))) = nan;




hFig = figure('Name','Mean images','Menu','none','ToolBar','none');
tgroup = uitabgroup(hFig);

t1 = uitab(tgroup, 'Title', 'Original');
axes1 = axes('Parent', t1);
% imagesc(mean(im0,3,'omitnan'), 'Parent', axes1,[0 0.7]); axis image off; colormap gray;
imagesc(im0(:,:,50), 'Parent', axes1,[0 0.7]); axis image off; colormap gray;
title(axes1,'Original');

t2 = uitab(tgroup, 'Title', 'Monomodal Reg');
axes2 = axes('Parent', t2);
% imagesc(mean(im0_regMono,3,'omitnan'), 'Parent', axes2,[0 0.7]); axis image off; colormap gray;
imagesc(im0_regMono(:,:,50), 'Parent', axes2,[0 0.7]); axis image off; colormap gray;
title(axes2,'Monomodal Reg');

t3 = uitab(tgroup, 'Title', 'PhaseCorr Reg');
axes3 = axes('Parent', t3);
% imagesc(mean(im0_regPhaseCorr,3,'omitnan'), 'Parent', axes3,[0 0.7]); axis image off; colormap gray;
imagesc(im0_regPhaseCorr(:,:,50), 'Parent', axes3,[0 0.7]); axis image off; colormap gray;
title(axes3,'PhaseCorr Reg');






%% Test exactitude of motion parameter conversion from 2dImReg to 3dAllineate
mri = MRIread(fRun0);
mri.vol = mri.vol(:,:,:,1:2);
fRun2f = replace(fRun0,'.nii.gz','_2frames.nii.gz');
MRIwrite(mri,fRun2f);





%% Test accuracy based on overall correlation
% get mask
mriMaskInv = MRIread(fMaskInv);
% make average base image
fBase0 = replace(fRun0,'.nii.gz','_avgBase.nii.gz');
afni_2dImReg(fRun0,fRun0,fBase0);
% imCorr(fRun0,fMaskInv);
% imCorr(fBase0,fMaskInv);
mri = MRIread(fBase0); mri.vol = mean(mri.vol,4); MRIwrite(mri,fBase0);

% register run to average base image using 3dAllineate
fRun_3dAllin = replace(fRun0,'.nii.gz','_3dAllin.nii.gz');
motAllin = afni_3dAllineate(fRun0,fBase0,fMaskInv,fRun_3dAllin,4);


% register run to average base image using 2dImReg
fRun_ImReg = replace(fRun0,'.nii.gz','_ImReg.nii.gz');
motImReg = afni_2dImReg(fRun0,fBase0,fRun_ImReg);

% % apply 2dImReg motion with 3dAllineate
% trans = [motImReg(1) 0 motImReg(2)];
% rot   = [0 0 motImReg(3)];
% fRun_ImReg_allinApplied = replace(fRun0,'.nii.gz','_ImReg_allinApplied.nii.gz');
% afni_applyAffine(fRun0,trans,rot,fRun_ImReg_allinApplied)

run0Corr       = imCorr(fRun0,fMaskInv);
run3dAllinCorr = imCorr(fRun_3dAllin,fMaskInv);
runImRegCorr   = imCorr(fRun_ImReg,fMaskInv);
% runImRegAllinAppliedCorr = imCorr(fRun_ImReg_allinApplied,fMaskInv);

run0Corr(diag(true(size(run0Corr,1),1))) = nan;
run3dAllinCorr(diag(true(size(run3dAllinCorr,1),1))) = nan;
runImRegCorr(diag(true(size(runImRegCorr,1),1))) = nan;
% runImRegAllinAppliedCorr(diag(true(size(runImRegAllinAppliedCorr,1),1))) = nan;

figure('Menu','none','ToolBar','none');
plot(mean(im00,2,'omitnan')); hold on
plot(mean(im00regMono,2,'omitnan')); hold on
plot(mean(im00regPhaseCorr,2,'omitnan')); hold on
plot(mean(run0Corr,2,'omitnan')); hold on
plot(mean(run3dAllinCorr,2,'omitnan'));
plot(mean(runImRegCorr,2,'omitnan'));
% plot(mean(runImRegAllinAppliedCorr,2,'omitnan'));
% legend('run0','3dAllin','ImReg','ImReg_allinApplied','interpreter','none');
% legend('run0','3dAllin','ImReg','interpreter','none');
legend('im00','im00_regMono','im00_regPhaseCorr','run0','3dAllin','ImReg','interpreter','none');
ylim([0 1]);




%% Test precision with ground truth
mri = MRIread(fRun0);
mri.vol = mri.vol(:,:,:,1:2);
fRun = replace(fRun0,'.nii.gz','_2frames.nii.gz');
MRIwrite(mri,fRun);


spSmFac = 4;
err      = [];
errAllin = [];
for ii = 1:100
    disp(['iteration ' num2str(ii) '/' num2str(100)])
    % motActual = [1 -0.5 0.25];
    motActual = rand(1,3)*2-1;
    transActual = [motActual(1) 0 motActual(2)];
    rotActual   = [0 0 motActual(3)];
    fBaseShifted1 = replace(fRun,'.nii.gz','_shift1.nii.gz');
    afni_applyAffine(fRun,-transActual/2,-rotActual/2,fBaseShifted1)
    fBaseShifted2 = replace(fRun,'.nii.gz','_shift2.nii.gz');
    afni_applyAffine(fRun,transActual/2,rotActual/2,fBaseShifted2)
    
    fBaseShifted1to2 = replace(fBaseShifted1,'_shift1.nii.gz','_shift1to2.nii.gz');
    if ii==1; confirmFlag = true; else; confirmFlag = false; end
    mot = afni_2dImReg(fBaseShifted1,fBaseShifted2,fBaseShifted1to2,spSmFac,confirmFlag);
    mot = mot(1,:);
    err(ii,:) = mot./motActual;

    afni_3dAllineate(fBaseShifted1,fBaseShifted2,fMaskInv,replace(fBaseShifted1to2,'.nii.gz',''),spSmFac);
    motAllin = readmatrix(replace(fBaseShifted1to2,'.nii.gz','.param.1D'),'FileType','text');
    motAllin = motAllin(1,[1 3 6]);
    errAllin(ii,:) = motAllin./motActual;
end
mean(err,1)
mean(errAllin,1)
std(err,[],1)
std(errAllin,[],1)



%% Test matlab functions
mri = MRIread(fRun0);
im = squeeze(single(mri.vol));
medicalRegistrationEstimator