clear all
close all
clc
% figure('Menu','none','ToolBar','none');



projectName = 'testVsmCenSurReg';
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
        %%%% vesselboost
        src.vesselboost = 'ml vesselboost/1.0.0';
        system([src.vesselboost '; prediction.py --help > /dev/null'],'-echo');
        
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
disp(projectCode)
disp(projectStorage)
disp(projectScratch)



%%%%%%%%%%%%%%%%%%
%% Copy data files
%%%%%%%%%%%%%%%%%%
% get data pointer
pointerFile = fullfile(projectCode,'tmp','dataPointers.mat');
% copyfile('/scratch/users/Proulx-S/vsmCenSur/dataPointers.mat',pointerFile);
load(pointerFile);
s = 1; % perferct all over
s = 2; % somewhate rigid movement mostly in the first and 2nd run -> mostly correctable with matlab registration over vesselRegion, but frames failed (will probably require temporal smoothing)
s = 3; % ok
s = 4; % minimal possibly non-rigid movement
s = 5; % some non-rigid movement particularly in one vessel on the left on the last run
s = 6; % ok
s = 7; % some movements, not clear if rigid
%% %%%%%%%%%%%%%%%
return


S=2;
tmp = fullfile(roi{S}.(acq).(task).rCond.volAnat.tof.folder,roi{S}.(acq).(task).rCond.volAnat.tof.name);
tmpDir = fullfile(projectCode,'tmp','tof','seg'); if ~exist(tmpDir,'dir'); mkdir(tmpDir); end
tmpDir = fullfile(projectCode,'tmp','tof','raw'); if ~exist(tmpDir,'dir'); mkdir(tmpDir); end
tof = fullfile(tmpDir,'tof.nii.gz');
copyfile(tmp,tof);

in    = fileparts(tof);
out   = fullfile(in,'..','seg');
model = fullfile(projectCode,'tmp','tof','models','manual_0429');
vesselboost_prediction(in,out,model,4);


tof_seg = MRIread(fullfile(out,'tof.nii.gz'));
figure('Menu','none','ToolBar','none');
imagesc(tof_seg.vol(:,:,round(end/2),1));
bwskel(tof_seg.vol)


% ml vesselboost
% prediction.py --ds_path /scratch/users/Proulx-S/tools/bassWrap-reg/testVsmCenSurReg/tmp/tof/raw/ --out_path /scratch/users/Proulx-S/tools/bassWrap-reg/testVsmCenSurReg/tmp/tof/seg/ --pretrained /scratch/users/Proulx-S/tools/bassWrap-reg/testVsmCenSurReg/saved_models/manual_0429 --prep_mode 4

%%%%%%%%%%%%%%%%%%%%%%%%%%
%% Try matlab registration
%%%%%%%%%%%%%%%%%%%%%%%%%%


S=2;
roi{S}.(acq).(task);
im0 = squeeze(cat(5,roi{S}.(acq).(task).vesselRegion.im.ts.im{:}));
im0 = im0 - min(im0(:));
im0 = im0./max(im0(:));
im0Base = mean(im0,[3 4]);
clear im0_reg im0_regParam
for i = 1:3%size(im0,4)
    disp(['RUN ' num2str(i) '/' num2str(size(im0,4))])
    for j = 1:size(im0,3)
        if j==1 || mod(j,10)==0 || j==size(im0,3)
            disp(['frame ' num2str(j) '/' num2str(size(im0,3))])
        end
        im0_regTmp = registerImages_phaseCorrelation(im0(:,:,j,i),im0Base           );
        im0_regTmp = registerImages_monomodal(       im0(:,:,j,i),im0Base,im0_regTmp);
        im0_reg(:,:,j,i) = im0_regTmp.RegisteredImage;
        im0_regParam(j,i) = im0_regTmp.Transformation;
    end
end
whos im0 im0_reg

regParams = cat(1,im0_regParam.Translation);
regParams = cat(2,regParams,cat(1,im0_regParam.RotationAngle));

figure('Menu','none','ToolBar','none');
plot(regParams);
return

sz = size(im0); sz(3) = 1;
im0 = cat(3,im0,repmat(0.5,sz));
sz = size(im0_reg); sz(3) = 1;
im0_reg = cat(3,im0_reg,repmat(0.5,sz));


COM = cat(1,roi{S}.(acq).(task).vesselRegion.com{:}); COM = COM - [roi{S}.(acq).(task).vesselRegion.cropXlim(1) roi{S}.(acq).(task).vesselRegion.cropYlim(1)] + 1;
for c = 1:size(COM,1)
    im0(    round(COM(c,2)),round(COM(c,1)),:,:) = 0;
    im0_reg(round(COM(c,2)),round(COM(c,1)),:,:) = 0;
end


tmp = im0(:,:,[1:20 end-20:end],1:3); sz = size(tmp); sz(3:4) = [prod(sz(3:4)) 1];
implay(reshape(uint8(tmp.*255),sz));
tmp = im0_reg(:,:,[1:20 end-20:end],:); sz = size(tmp); sz(3:4) = [prod(sz(3:4)) 1];
implay(reshape(uint8(tmp.*255),sz));

tmp = im0(:,:,:,1:3);
im0_xMat = imCorr(tmp(:,:,:));
tmp = im0_reg(:,:,:,1:3);
im0_reg_xMat = imCorr(tmp(:,:,:));

hFig = figure('Menu','none','ToolBar','none');
plot(mean(im0_xMat.^2,2)); hold on;
plot(mean(im0_reg_xMat.^2,2));
legend('Original','Registered');
ylim([0 1]);

%% %%%%%%%%%%%%%%%%%%%%%%%



return




