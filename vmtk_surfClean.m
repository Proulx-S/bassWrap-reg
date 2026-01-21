function vmtk_surfClean(input_vtk, output_vtk, options)
    % VMTK_SURFCLEAN Clean a surface mesh using VMTK (merge duplicates, remove unused/degenerate)
    %
    % Usage:
    %   vmtk_surfClean(input_vtk, output_vtk)
    %   vmtk_surfClean(input_vtk, output_vtk, options)
    %
    % Inputs:
    %   input_vtk   - Path to input surface mesh (VTK format)
    %   output_vtk  - Path to output cleaned surface (VTK format)
    %   options     - Optional struct:
    %       .method  - 'largest' (default) or 'closest'. For per-vessel meshes, 'largest' keeps the mesh.
    %
    % Uses vmtksurfaceconnectivity with -cleanoutput 1, which applies vtkCleanPolyData-like
    % operations: merge duplicate/close points, remove unused points, remove degenerate cells.
    % Run after marching cubes and before smoothing to improve robustness of centerline extraction.
    
    global src;
    if nargin < 3 || isempty(options); options = struct(); end
    
    method = 'largest';
    if isfield(options, 'method') && ~isempty(options.method); method = options.method; end
    
    if ~exist(input_vtk, 'file')
        error('Input surface file not found: %s', input_vtk);
    end
    
    if ~exist(fileparts(output_vtk), 'dir')
        mkdir(fileparts(output_vtk));
    end
    
    cmd = {src.vmtk};
    cmd{end+1} = ['vmtksurfaceconnectivity -ifile ' input_vtk ' -ofile ' output_vtk ' -method ' method ' -cleanoutput 1'];
    system(strjoin(cmd, newline), '-echo');
    
    if ~exist(output_vtk, 'file') || dir(output_vtk).bytes < 100
        error('Surface clean failed - output is empty or missing. Check input surface.');
    end
end
