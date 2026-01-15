# 2dImReg Source Code Information

## Location

The source code for `2dImReg` is part of the AFNI software package and is available in the AFNI GitHub repository.

## Source Files

The main source code files are:

1. **`2dImReg.c`** - Main program source (1,620 lines)
   - Author: B. Douglas Ward
   - Initial release: 04 February 1998
   - Latest revision: 20 March 2024
   - Location: `afni/src/2dImReg.c`

2. **`imreg.c`** - Related 2D image registration program (731 lines)
   - Location: `afni/src/imreg.c`

3. **`plug_imreg.c`** - AFNI plugin version (440 lines)
   - Location: `afni/src/plug_imreg.c`

## Accessing the Source Code

### Option 1: Clone the AFNI Repository

```bash
cd /tmp
git clone https://github.com/afni/afni.git
cd afni/src
# View the main source file
cat 2dImReg.c
# Or use your preferred editor
```

### Option 2: View Online

The source code is available on GitHub:
- Repository: https://github.com/afni/afni
- Direct link to `2dImReg.c`: https://github.com/afni/afni/blob/master/src/2dImReg.c

### Option 3: Extract from Container (if needed)

The binary in your container is located at:
- `/usr/local/abin/2dImReg` (inside the container)

However, since it's a compiled binary, you'll need the source code from the repository.

## Key Information from Source Code

- **Program Purpose**: Performs 2D image registration on a slice-by-slice basis for 3D+time datasets
- **Algorithm**: Uses iterative differential spatial alignment (`mri_align_dfspace`)
- **Registration Parameters**: 
  - Translation (dx, dy) in pixels or mm
  - Rotation (psi) in degrees
- **Fine Fit Parameters**:
  - Blur: FWHM of blurring prior to registration (default: 1.0 pixels)
  - dxy: Convergence tolerance for translations (default: 0.07 pixels)
  - dphi: Convergence tolerance for rotations (default: 0.21 degrees)

## Dependencies

The program uses AFNI's internal libraries:
- `mrilib.h` - MRI library functions
- `matrix.h` - Matrix operations
- Various AFNI dataset handling functions

## Notes

- The program was adapted from `plug_imreg.c` and `imreg.c`
- It handles byte, short, and float data types
- Supports writing registration parameters to ASCII files (.dx, .dy, .psi)
- Can output RMS error metrics for registration quality assessment

## Detailed Algorithm Documentation

For a comprehensive explanation of how the registration algorithm works, including:
- Mathematical foundation
- Step-by-step algorithm description
- Parameter details
- Implementation details

See: **[2dImReg_algorithm_details.md](./2dImReg_algorithm_details.md)**
