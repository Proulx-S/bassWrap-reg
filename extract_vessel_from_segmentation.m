function vesselMask = extract_vessel_from_segmentation(segAll, skel, connectivity)
%EXTRACT_VESSEL_FROM_SEGMENTATION Extract vessel from full segmentation using skeleton
%
%   vesselMask = extract_vessel_from_segmentation(segAll, skel)
%   vesselMask = extract_vessel_from_segmentation(segAll, skel, connectivity)
%
%   This function extracts all voxels in segAll that belong to the vessel
%   containing the skeleton points in skel. It uses connected component
%   analysis to identify which component in the full segmentation contains
%   the skeleton points.
%
%   Inputs:
%     segAll      - 3D binary mask of all vessels (1 = vessel, 0 = background)
%     skel        - 3D binary mask of single vessel skeleton (1 = skeleton, 0 = background)
%     connectivity - Optional: connectivity for bwconncomp (default: 26 for 3D)
%                    Can be 6, 18, or 26 for 3D images
%
%   Outputs:
%     vesselMask  - 3D binary mask of extracted vessel (same size as segAll)
%
%   Example:
%     mriSkel = MRIread('skeleton.nii.gz');
%     mriSegAll = MRIread('all_vessels.nii.gz');
%     skel = mriSkel.vol;
%     segAll = mriSegAll.vol;
%     vesselMask = extract_vessel_from_segmentation(segAll, skel);
%
%   See also: bwconncomp, ismember

    % Set default connectivity
    if nargin < 3 || isempty(connectivity)
        connectivity = 26;  % Default: 26-connectivity for 3D
    end
    
    % Validate inputs
    if ~isequal(size(segAll), size(skel))
        error('extract_vessel_from_segmentation: segAll and skel must have the same size');
    end
    
    % Find connected components in full segmentation
    CC = bwconncomp(segAll, connectivity);
    
    % Get linear indices of skeleton points
    skelIndices = find(skel > 0);
    
    if isempty(skelIndices)
        warning('extract_vessel_from_segmentation: No skeleton points found in skel');
        vesselMask = false(size(segAll));
        return;
    end
    
    % Find which component contains skeleton points
    vesselComponentIdx = [];
    for i = 1:CC.NumObjects
        % Check if any skeleton point is in this component
        if any(ismember(skelIndices, CC.PixelIdxList{i}))
            vesselComponentIdx = i;
            break; % Assuming skeleton belongs to only one component
        end
    end
    
    % Extract the vessel mask
    vesselMask = false(size(segAll));
    if ~isempty(vesselComponentIdx)
        vesselMask(CC.PixelIdxList{vesselComponentIdx}) = true;
    else
        warning('extract_vessel_from_segmentation: No connected component found containing skeleton points');
    end
end
