function vmtk_surfFromSeg(input_seg_nii, output_vtk_file, options)
    % VMTK_SURFFROMSEG Create surface mesh from segmentation using VMTK marching cubes
    %
    % Usage:
    %   seg_surface_vtk = vmtk_surfFromSeg(input_seg_nii, output_vtk_file)
    %   seg_surface_vtk = vmtk_surfFromSeg(input_seg_nii, output_vtk_file, options)
    %
    % Inputs:
    %   input_seg_nii    - Path to segmentation volume (NIfTI format)
    %   output_vtk_file  - Path to output surface mesh file (VTK format)
    %   options          - Optional struct:
    %     .addSpatialMetadata - If true, add NIfTI_Affine/SourceNIfTI to the VTK
    %                           so vmtk_viewVolAndSurf can align when viewing with
    %                           a different volume (default: false).
    %
    % This function uses VMTK's marching cubes algorithm to create a surface mesh
    % from a binary segmentation volume. The threshold is set to 0.5 for binary
    % segmentations (values between 0 and 1).
    
    global src;
    if nargin < 3 || isempty(options); options = struct(); end
    if ~isfield(options, 'addSpatialMetadata'); options.addSpatialMetadata = false; end
    
    % Ensure output directory exists
    if ~exist(fileparts(output_vtk_file),'dir'); mkdir(fileparts(output_vtk_file)); end
    
    % Create surface mesh from segmentation using marching cubes
    % This is needed for centerline extraction (vmtkcenterlines requires a surface mesh)
    % Use vmtk wrapper with piping for nifti -> marching cubes -> surface
    % -l 0.5 for binary segmentation (threshold between 0 and 1)
    cmd = {src.vmtk};
    cmd{end+1} = ['vmtkimagereader -ifile ' input_seg_nii ' --pipe vmtkmarchingcubes -l 0.5 --pipe vmtksurfacewriter -ofile ' output_vtk_file];
    system(strjoin(cmd,newline),'-echo');
    
    % Verify surface was created
    if ~exist(output_vtk_file,'file') || dir(output_vtk_file).bytes < 100
        error('Surface mesh creation failed - file is empty or missing. Check segmentation values.');
    end
    
    if options.addSpatialMetadata
        vtk_add_nifti_metadata(output_vtk_file, input_seg_nii);
    end
end
