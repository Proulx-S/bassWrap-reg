function vesselboost_prediction(inFile, outFile, psFile, pretrained, prep_mode)
    global src;
    if nargin < 4 || isempty(prep_mode) ; prep_mode  = 4; end
    if nargin < 3 || isempty(pretrained); pretrained = fullfile(fileparts(ds_path),'models','manual_0429'); end

    if ~exist(inFile,'file')
        error('vesselboost input file does not exist');
    end


    [~,b,c] = fileparts(inFile);
    % tmp dir for input file
    if length(dir(fileparts(inFile)))==3
        rmFlag = false;
        in = inFile;
    else
        rmFlag = true;
        in = tempname; mkdir(in);
        in = fullfile(in,[b,c]);
        copyfile(inFile,in);
    end
    % tmp dir for preprocessing file
    if exist('psFile','var') && ~isempty(psFile)
        ps = tempname; mkdir(ps);
        ps = fullfile(ps,[b,c]);
    end
    % tmp dir for output file
    out = tempname; mkdir(out);
    out = fullfile(out,[b,c]);



    cmd = {src.vesselboost};
    cmd{end+1} = 'prediction.py \';
    cmd{end+1} = ['--ds_path ' fileparts(in) ' \'];
    cmd{end+1} = ['--out_path ' fileparts(out) ' \'];
    if exist('psFile','var') && ~isempty(psFile)
        cmd{end+1} = ['--ps_path ' fileparts(ps) ' \'];
    end
    cmd{end+1} = ['--pretrained ' pretrained ' \'];
    cmd{end+1} = ['--prep_mode ' num2str(prep_mode)];
    system(strjoin(cmd,newline),'-echo');


    % move from tmp dirs to original files
    if rmFlag; rmdir(fileparts(in), 's'); end
    if exist(psFile,'var') && ~isempty(psFile); movefile(ps,psFile); rmdir(fileparts(ps), 's'); end
    movefile(out,outFile); rmdir(fileparts(out), 's');
end