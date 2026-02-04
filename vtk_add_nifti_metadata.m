function vtk_add_nifti_metadata(surface_vtk, source_nii, output_vtk)
%VTK_ADD_NIFTI_METADATA Add NIfTI coordinate system metadata to a VTK PolyData file
%
%   vtk_add_nifti_metadata(surface_vtk, source_nii)
%   vtk_add_nifti_metadata(surface_vtk, source_nii, output_vtk)
%
%   Adds FieldData (NIfTI_Affine, CoordinateSystem, SourceNIfTI) to the VTK file
%   so downstream tools know the surface points are in that NIfTI's physical (RAS) space.
%   If output_vtk is omitted, surface_vtk is overwritten.

if nargin < 2
    error('Require at least surface_vtk and source_nii');
end
if nargin < 3 || isempty(output_vtk)
    output_vtk = surface_vtk;
end
if ~exist(surface_vtk, 'file')
    error('Surface file not found: %s', surface_vtk);
end
if ~exist(source_nii, 'file')
    error('NIfTI file not found: %s', source_nii);
end

script_dir = fileparts(mfilename('fullpath'));
py_script = fullfile(script_dir, 'vtk_add_nifti_metadata.py');
cmd = sprintf('python "%s" "%s" "%s" "%s"', py_script, surface_vtk, source_nii, output_vtk);
[status, err] = system(cmd, '-echo');
if status ~= 0
    error('vtk_add_nifti_metadata failed: %s', err);
end
