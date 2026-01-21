function vmtk_surfSmoothing(input_vtk, output_vtk, options)
    % VMTK_SURFSMOOTHING Smooth a surface mesh using VMTK (Taubin non-shrinking filter)
    %
    % Usage:
    %   vmtk_surfSmoothing(input_vtk, output_vtk)
    %   vmtk_surfSmoothing(input_vtk, output_vtk, options)
    %
    % Inputs:
    %   input_vtk   - Path to input surface mesh (VTK format)
    %   output_vtk  - Path to output smoothed surface (VTK format)
    %   options     - Optional struct:
    %       .passband   - Cut-off spatial frequency (default 0.1). Lower = more smoothing (e.g. 0.01).
    %       .iterations - Number of smoothing passes (default 30).
    %
    % Uses vtkWindowedSincPolyDataFilter (Taubin algorithm) to reduce bumps and
    % noise from segmentation while avoiding shrinkage. Recommended before
    % centerline extraction on thin or coarse vessel surfaces.
    % Avoid excessive smoothing: it can blunt bifurcation apices and alter geometry.
    
    global src;
    if nargin < 3 || isempty(options); options = struct(); end
    
    passband   = 0.1;
    iterations = 30;
    if isfield(options, 'passband')   && ~isempty(options.passband);   passband   = options.passband;   end
    if isfield(options, 'iterations') && ~isempty(options.iterations); iterations = options.iterations; end
    
    if ~exist(input_vtk, 'file')
        error('Input surface file not found: %s', input_vtk);
    end
    
    if ~exist(fileparts(output_vtk), 'dir')
        mkdir(fileparts(output_vtk));
    end
    
    cmd = {src.vmtk};
    cmd{end+1} = ['vmtksurfacesmoothing -ifile ' input_vtk ' -ofile ' output_vtk ' -passband ' num2str(passband) ' -iterations ' num2str(iterations)];
    system(strjoin(cmd, newline), '-echo');
    
    if ~exist(output_vtk, 'file') || dir(output_vtk).bytes < 100
        error('Surface smoothing failed - output is empty or missing. Check input surface.');
    end
end
