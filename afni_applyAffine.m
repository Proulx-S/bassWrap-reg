function afni_applyAffine(fIn,trans,rot,fOut)
    global src

    if ~exist('trans','var') || isempty(trans); trans = [0 0 0]; end
    if ~exist('rot'  ,'var') || isempty(rot  );   rot = [0 0 0]; end
    param = [trans rot 1 1 1 0 0 0];
    paramStr = strjoin(arrayfun(@(x) sprintf('%.16g',x), param, 'UniformOutput', false), ' ');

    cmd = {src.afni};
    cmd{end+1} = '3dAllineate -overwrite \';
    cmd{end+1} = ['-prefix ' fOut ' \'];

    cmd{end+1} = ['-1Dparam_apply ''1D: ' paramStr '''\'' \'];
    cmd{end+1} = '-final cubic \'; % quintic, wsinc5
    cmd{end+1} = fIn;

    [status,cmdout] = system(strjoin(cmd,newline)); if status || isempty(cmdout); dbstack; error(cmdout); error('x'); end

end