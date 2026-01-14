clear all
close all
figure('Menu','none','ToolBar','none');
force = 1;
info.dataSetLabel = 'vsmDiamCenSur'; % vsmDiamCenSur, satinV2 
%%%%%%%%%%%%%%%%%%%%%
%% Set up environment
%%%%%%%%%%%%%%%%%%%%%

% Detect computing environment
os   = char(java.lang.System.getProperty('os.name'));
host = char(java.net.InetAddress.getLocalHost.getHostName);
user = char(java.lang.System.getProperty('user.name'));

% Configure paths accordingly
if strcmp(os,'Linux') && strcmp(host,'takoyaki') && strcmp(user,'sebp')
    storageDir = '/local/users/Proulx-S/';
    scratchDir = '/scratch/users/Proulx-S/';
    toolDir    = fullfile(getenv('HOME'),'tools');
    workScript = mfilename;
    workFile   = [workScript '.mat'];
    workDir    = fullfile(getenv('HOME'),'/work/generalPreproc/',workScript); if ~exist(workDir,'dir'); mkdir(workDir); end
    workFile   = fullfile(fileparts(workDir),workFile);
    envId      = 1;
    setenv('SINGULARITY_BINDPATH',strjoin({storageDir scratchDir toolDir workDir},','));
else
    dbstack; error('not implemented')
end


% Load dependencies
%%% matlab
addpath(genpath(         workDir                                 ))
tool = 'bassReg2';    toolURL = 'https://github.com/Proulx-S/bassReg2.git';
if ~exist(fullfile(toolDir, tool), 'dir'); system(['git clone ' toolURL ' ' fullfile(toolDir, tool)]); end
addpath(genpath(fullfile(toolDir,tool)))
tool = 'vasomoTools'; toolURL = 'https://github.com/Proulx-S/vasomoTools.git';
if ~exist(fullfile(toolDir, tool), 'dir'); system(['git clone ' toolURL ' ' fullfile(toolDir, tool)]); end
addpath(genpath(fullfile(toolDir,tool)))
tool = 'util';    toolURL = 'https://github.com/Proulx-S/util.git';
if ~exist(fullfile(toolDir, tool), 'dir'); system(['git clone ' toolURL ' ' fullfile(toolDir, tool)]); end
addpath(genpath(fullfile(toolDir,tool)))
tool = 'chronux';     toolURL = 'https://github.com/Proulx-S/chronux';
if ~exist(fullfile(toolDir, tool), 'dir'); system(['git clone ' toolURL ' ' fullfile(toolDir, tool)]); end
addpath(genpath(fullfile(toolDir,'chronux/chronux_2_12/modified')))
tool = 'fieldtrip';   toolURL = 'https://github.com/fieldtrip/fieldtrip';
if ~exist(fullfile(toolDir, tool), 'dir'); system(['git clone ' toolURL ' ' fullfile(toolDir, tool)]); end
addpath(genpath(fullfile(toolDir,'fieldtrip/external/freesurfer')))
%%% neurodesk
switch envId
    case 1
        global src
        %%%% afni
        src.afni = 'ml afni/24.3.00';
        system([src.afni '; 3dinfo > /dev/null'],'-echo');
        %%%% freesurfer
        src.fs   = 'ml freesurfer/8.0.0';
        system([src.fs   '; mri_convert > /dev/null'],'-echo');
        %%%% ants
        src.ants = 'ml ants/2.5.3';
        system([src.ants '; N4BiasFieldCorrection > /dev/null'],'-echo');
        %%%% fsl for fslview once we figure out how to make it work
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


% Current dataset/project
info.workDir      = workDir; if ~exist(info.workDir,'dir'); mkdir(info.workDir); end
info.workFile     = fullfile(info.workDir,[info.dataSetLabel '_' replace(workScript,'doIt_','') '20250630.mat']);
info.indexFile    = fullfile(info.workDir,[info.dataSetLabel '_indexFile20250630.mat']);
%% %%%%%%%%%%%%%%%%%%










% Test precision with ground truth
mri = MRIread(fRun0);
mri.vol = mri.vol(:,:,:,1:2);
fRun = replace(fRun0,'run0.nii.gz','run2.nii.gz');
MRIwrite(mri,fRun);


spSmFac = 4;
err      = [];
errAllin = [];
for ii = 1:100
    disp(['iteration ' num2str(ii) '/' num2str(100)])
    motActual = rand(1,3)*2-1;
    transActual = [motActual(1) 0 motActual(2)];
    rotActual   = [0 0 motActual(3)];
    fBaseShifted1 = replace(fRun,'.nii.gz','_shift1.nii.gz');
    afni_applyAffine(fRun,-transActual/2,-rotActual/2,fBaseShifted1)
    fBaseShifted2 = replace(fRun,'.nii.gz','_shift2.nii.gz');
    afni_applyAffine(fRun,transActual/2,rotActual/2,fBaseShifted2)
    
    fBaseShifted1to2 = replace(fBaseShifted1,'_shift1.nii.gz','_shift1to2.nii.gz');
    mot = afni_2dImReg(fBaseShifted1,fBaseShifted2,fBaseShifted1to2,spSmFac,false);
    mot = mot(1,:);
    err(ii,:) = mot./motActual;

    afni_3dAllineate(fBaseShifted1,fBaseShifted2,fMask,replace(fBaseShifted1to2,'.nii.gz',''),spSmFac);
    motAllin = readmatrix(replace(fBaseShifted1to2,'.nii.gz','.param.1D'),'FileType','text');
    motAllin = motAllin(1,[1 3 6]);
    errAllin(ii,:) = motAllin./motActual;
end
mean(err,1)
mean(errAllin,1)
std(err,[],1)
std(errAllin,[],1)



% Test accuracy based on overall correlation

% make average base image
fBase0 = replace(fRun0,'.nii.gz','_avBase.nii.gz');
mot = afni_2dImReg(fRun0,fRun0,fBase0);
mri = MRIread(fBase0); mri.vol = mean(mri.vol,4); MRIwrite(mri,fBase0);

% register run to average base image using 3dAllineate
fRun_3dAllin = replace(fRun0,'.nii.gz','_3dAllin.nii.gz');
motAllin = afni_3dAllineate(fRun0,fBase0,fMask,fRun_3dAllin,4);


% register run to average base image using 2dImReg
fRun_ImReg = replace(fRun0,'.nii.gz','_ImReg.nii.gz');
motImReg = afni_2dImReg(fRun0,fBase0,fRun_ImReg);

% apply 2dImReg motion with 3dAllineate
trans = [motImReg(1) 0 motImReg(2)];
rot   = [0 0 motImReg(3)];
fRun_ImReg_allinApplied = replace(fRun0,'.nii.gz','_ImReg_allinApplied.nii.gz');
afni_applyAffine(fRun0,trans,rot,fRun_ImReg_allinApplied)

run0Corr = imCorr(fRun0,fMask);
run3dAllinCorr = imCorr(fRun_3dAllin,fMask);
runImRegCorr = imCorr(fRun_ImReg,fMask);
runImRegAllinAppliedCorr = imCorr(fRun_ImReg_allinApplied,fMask);

run0Corr(diag(true(size(run0Corr,1),1))) = nan;
run3dAllinCorr(diag(true(size(run3dAllinCorr,1),1))) = nan;
runImRegCorr(diag(true(size(runImRegCorr,1),1))) = nan;
runImRegAllinAppliedCorr(diag(true(size(runImRegAllinAppliedCorr,1),1))) = nan;

figure('Menu','none','ToolBar','none');
plot(mean(run0Corr,2,'omitnan')); hold on
plot(mean(run3dAllinCorr,2,'omitnan'));
plot(mean(runImRegCorr,2,'omitnan'));
legend('run0','3dAllin','ImReg');
ylim([0 1]);


run0Corr(isnan(run0Corr)) = nan;
run3dAllinCorr(isnan(run3dAllinCorr)) = nan;
runImRegCorr(isnan(runImRegCorr)) = nan;
runImRegAllinAppliedCorr(isnan(runImRegAllinAppliedCorr)) = nan;

