# 2dImReg Registration Algorithm Details

## Overview

`2dImReg` performs **iterated differential spatial alignment** for 2D image registration on a slice-by-slice basis. The algorithm is designed for small displacements (typically up to 4 pixels) and uses a two-phase approach: a coarse fit followed by an optional fine fit.

## Core Algorithm: Iterated Differential Alignment

The registration is performed by the function `mri_align_dfspace()` in `/tmp/afni/src/mri_align.c`. The method is based on **differential spatial alignment** using least squares fitting.

## Algorithm Steps

### Phase 1: Preprocessing (Base Image)

For each slice, the algorithm first prepares the base image by computing:

1. **Smoothed base image** (`bim`):
   - Gaussian blur with FWHM = 4.0 pixels (σ = 4.0 × 0.42466090)
   - Uses FFT-based filtering with wraparound

2. **Spatial derivatives**:
   - **X-derivative** (`xim`): ∂I/∂x (horizontal gradient)
   - **Y-derivative** (`yim`): ∂I/∂y (vertical gradient)
   - **Rotational derivative** (`tim`): x·∂I/∂y - y·∂I/∂x (angular gradient)
     - Computed as: `DFAC × [(x - hnx) × ∂I/∂y - (y - hny) × ∂I/∂x]`
     - Where `hnx = nx/2`, `hny = ny/2` (image center)
     - `DFAC = π/180` (converts degrees to radians)

3. **Fitting basis set** (`fitim`):
   - An array of 4 images: `[bim, xim, yim, tim]`
   - These form the basis for the least squares fit

4. **Weight image** (`imww`):
   - If no weight image provided, uses absolute value of smoothed base image
   - Used to weight the least squares fit

5. **Cholesky decomposition** (if `USE_DELAYED_FIT` enabled):
   - Pre-computes Cholesky factorization of the normal equations
   - Speeds up repeated least squares fits

### Phase 2: Fine Fit Preparation (Optional)

If fine fit is enabled (default: yes), the algorithm creates a second set of fitting images with:

- **Finer smoothing**: FWHM = 1.0 pixels (σ = 1.0 × 0.42466090)
- **Tighter convergence thresholds**:
  - Translation: 0.07 pixels (vs 0.15 for coarse)
  - Rotation: 0.21 degrees (vs 0.45 for coarse)

### Phase 3: Registration Loop (Per Input Image)

For each input image in the time series:

#### 3.1 Initial Fit

1. Convert input image to float
2. Smooth with same Gaussian as base (FWHM = 4.0 pixels)
3. **Least squares fit** to find initial transformation:
   ```
   fit = argmin ||weighted(input - base - dx·∂I/∂x - dy·∂I/∂y - dφ·∂I/∂φ)||²
   ```
   - Returns: `[offset, dx, dy, dφ]`
   - `dx, dy` in pixels
   - `dφ` in radians

#### 3.2 Coarse Iterative Refinement

The algorithm iteratively refines the transformation:

```c
while (|dx| > 0.15 pixels OR |dy| > 0.15 pixels OR |dφ| > 0.45 degrees) 
    AND (iterations < max_iter = 5):
    
    1. Apply current transformation to input image:
       transformed = rotate_translate(input, dx, dy, dφ)
       - Uses bicubic interpolation (coarse mode)
    
    2. Smooth transformed image (same as base)
    
    3. Compute residual fit:
       residual = least_squares_fit(transformed, base_fitting_images)
    
    4. Update transformation:
       dx += residual[1]
       dy += residual[2]
       dφ += residual[3]
    
    5. Check convergence
```

**Convergence criteria**:
- Translation: `|dx| < 0.15 pixels` AND `|dy| < 0.15 pixels`
- Rotation: `|dφ| < 0.45 degrees`
- Maximum iterations: 5

#### 3.3 Fine Iterative Refinement (Optional)

If fine fit is enabled and coarse fit converged:

```c
while (|dx| > 0.07 pixels OR |dy| > 0.07 pixels OR |dφ| > 0.21 degrees) 
    AND (iterations < max_iter):
    
    1. Apply current transformation with finer interpolation:
       transformed = rotate_translate(input, dx, dy, dφ)
       - Uses bicubic interpolation (fine mode)
    
    2. Smooth with finer Gaussian (FWHM = 1.0 pixels)
    
    3. Compute residual fit using fine fitting images
    
    4. Update transformation (same as coarse)
    
    5. Check convergence with tighter thresholds
```

**Fine fit convergence criteria**:
- Translation: `|dx| < 0.07 pixels` AND `|dy| < 0.07 pixels`
- Rotation: `|dφ| < 0.21 degrees`

### Phase 4: Apply Final Transformation

Once transformation parameters are determined:

1. Apply final transformation to each input image:
   ```c
   registered = rotate_translate(input, dx, dy, dφ)
   ```
   - Uses bicubic interpolation (registration mode)
   - Always uses bicubic, regardless of coarse/fine modes

2. Convert back to original data type (byte, short, or float)

## Mathematical Foundation

### Least Squares Fit

The algorithm solves a weighted least squares problem:

```
minimize: Σ w(x,y) × [I_input(x,y) - I_base(x,y) - dx·∂I/∂x - dy·∂I/∂y - dφ·∂I/∂φ]²
```

Where:
- `w(x,y)` = weight at pixel (x,y) (from weight image)
- `I_base(x,y)` = base image intensity
- `∂I/∂x, ∂I/∂y, ∂I/∂φ` = spatial derivatives
- `dx, dy, dφ` = transformation parameters to solve for

This is solved using Cholesky decomposition of the normal equations for efficiency.

### Transformation Model

The transformation is a 2D rigid body transformation:
- **Translation**: (dx, dy) in pixels
- **Rotation**: dφ in radians (around image center)

The transformation is applied as:
```
x' = cos(dφ)·(x - hnx) - sin(dφ)·(y - hny) + hnx + dx
y' = sin(dφ)·(x - hnx) + cos(dφ)·(y - hny) + hny + dy
```

## Default Parameters

### Coarse Fit
- **Blur FWHM**: 4.0 pixels (σ = 1.70 pixels)
- **Max iterations**: 5
- **Translation threshold**: 0.15 pixels
- **Rotation threshold**: 0.45 degrees
- **Interpolation**: Bicubic

### Fine Fit (Default: Enabled)
- **Blur FWHM**: 1.0 pixels (σ = 0.42 pixels)
- **Translation threshold**: 0.07 pixels
- **Rotation threshold**: 0.21 degrees
- **Interpolation**: Bicubic

### User-Configurable Parameters

Via `-fine blur dxy dphi`:
- `blur`: FWHM of blurring prior to registration (default: 1.0 pixels)
- `dxy`: Convergence tolerance for translations (default: 0.07 pixels)
- `dphi`: Convergence tolerance for rotations (default: 0.21 degrees)

Via `-nofine`: Disables fine fit phase entirely

## Key Implementation Details

### Interpolation Methods

The algorithm supports different interpolation methods for different phases:
- **Coarse phase**: Configurable (default: bicubic)
- **Fine phase**: Configurable (default: bicubic)
- **Final registration**: Always bicubic

Available methods:
- `MRI_BILINEAR`: Bilinear interpolation
- `MRI_BICUBIC`: Bicubic interpolation (default)
- `MRI_FOURIER`: Fourier-based interpolation

### Weighted Least Squares

The algorithm uses a weight image to:
- Emphasize regions with high signal
- Downweight background/noise regions
- Default: absolute value of smoothed base image

### Iterative Refinement

The iterative approach allows the algorithm to:
- Handle larger displacements by breaking into smaller steps
- Converge more accurately than single-step methods
- Adapt to local image structure

### Limitations

- **Small displacements only**: Designed for displacements up to ~4 pixels
- **Rigid body only**: No scaling or shearing
- **2D only**: Works on individual slices, not full 3D volumes
- **Square slices**: Requires `nx == ny` and `|dx| ≈ |dy|`

## Performance Optimizations

1. **Cholesky decomposition**: Pre-computes normal equations matrix factorization
2. **FFT-based filtering**: Fast Gaussian smoothing using FFT
3. **Delayed fit**: Reuses pre-computed Cholesky factors for multiple fits
4. **Early termination**: Stops when convergence criteria met

## Output

The algorithm outputs:
- **Registered images**: Transformed input images aligned to base
- **Transformation parameters**: dx, dy, dφ for each image
  - Can be written to `.dx`, `.dy`, `.psi` files
  - Units: pixels (or mm with `-dmm`) and degrees

## References

- Source: `/tmp/afni/src/mri_align.c` (function `mri_align_dfspace`)
- Method: "Iterated differential alignment" (R.W. Cox, 1995)
- Designed for: Small displacements in 2D image sequences
