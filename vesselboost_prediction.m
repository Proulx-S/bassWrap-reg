function vesselboost_prediction(ds_path, out_path, pretrained, prep_mode)
    global src;
    if nargin < 4 || isempty(prep_mode) ; prep_mode  = 4; end
    if nargin < 3 || isempty(pretrained); pretrained = fullfile(fileparts(ds_path),'models','manual_0429'); end

    cmd = {src.vesselboost};
    cmd{end+1} = 'prediction.py \';
    cmd{end+1} = ['--ds_path ' ds_path ' \'];
    cmd{end+1} = ['--out_path ' out_path ' \'];
    cmd{end+1} = ['--pretrained ' pretrained ' \'];
    cmd{end+1} = ['--prep_mode ' num2str(prep_mode)];
    system(strjoin(cmd,newline),'-echo');
end