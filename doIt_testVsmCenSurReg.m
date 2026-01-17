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


%%%%%%%%%%%%%%%%%%
%% Copy data files
%%%%%%%%%%%%%%%%%%
% get data pointer
cp ../../vsmCenSur/dataPointers.mat ./sampleData/
load(fullfile(projectCode,'..','sampleData','dataPointers.mat'));
roi



%% %%%%%%%%%%%%%%%


return




