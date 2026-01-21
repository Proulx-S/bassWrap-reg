function vmtk_surfUpSample(input_vtk, output_vtk, options)
    % VMTK_SURFUPSAMPLE Upsample a triangulated surface to increase triangle density
    %
    % Usage:
    %   vmtk_surfUpSample(input_vtk, output_vtk)
    %   vmtk_surfUpSample(input_vtk, output_vtk, options)
    %
    % Inputs:
    %   input_vtk   - Path to input surface mesh (VTK format)
    %   output_vtk  - Path to output upsampled surface (VTK format)
    %   options     - Optional struct:
    %       .method       - 'butterfly' (default), 'loop', or 'linear'.
    %                      butterfly: preserve original vertices, C1 limit; good for vessel meshes.
    %                      loop: smooth limit C2, moves vertices.
    %                      linear: simple split, no smoothing.
    %       .subdivisions - Number of subdivision passes (default 1). Each pass ~4x triangles.
    %
    % Wraps vmtksurfacesubdivision. Use after smoothing when the mesh has too few triangles
    % (thin vessels, low-res segmentations) to improve Delaunay/Voronoi quality in
    % vmtkcenterlines or downstream meshing.
    
    global src;
    if nargin < 3 || isempty(options); options = struct(); end
    
    method       = 'butterfly';
    subdivisions = 1;
    if isfield(options, 'method')       && ~isempty(options.method);       method       = options.method;       end
    if isfield(options, 'subdivisions') && ~isempty(options.subdivisions); subdivisions = options.subdivisions; end
    
    if ~exist(input_vtk, 'file')
        error('Input surface file not found: %s', input_vtk);
    end
    
    if ~exist(fileparts(output_vtk), 'dir')
        mkdir(fileparts(output_vtk));
    end
    
    cmd = {src.vmtk};
    cmd{end+1} = ['vmtksurfacesubdivision -ifile ' input_vtk ' -ofile ' output_vtk ' -method ' method ' -subdivisions ' num2str(subdivisions)];
    system(strjoin(cmd, newline), '-echo');
    
    if ~exist(output_vtk, 'file') || dir(output_vtk).bytes < 100
        error('Surface upsample failed - output is empty or missing. Check input surface.');
    end
end
