#!/bin/bash
set -e -u -o pipefail

# --- Directory and Script Setup ---
RAW_DWI_DIR="${ROOT_DIR}/${SUBJECT_ID}/${SESSION_ID}/${SERIE_ID}"
PREPARED_DIR="${DERIVATIVES_DIR}/01_prepared_data"

# --- Step 1.1: Copy and Organize Raw Data ---
echo "================================================="
echo "STEP 1.1: COPYING RAW DATA"
echo "================================================="

# Clean up previous runs and create directories
rm -rf "${PREPARED_DIR}"
mkdir -p "${PREPARED_DIR}"

echo "Searching for DWI scans in: ${RAW_DWI_DIR}"
echo "Copying and organizing into: ${PREPARED_DIR}"

# Find .nii.gz files and loop through them
find "${RAW_DWI_DIR}" -type f -name "*.nii.gz" | while read -r nifti_file; do
    # Extract the base name without the extension
    base_name=$(basename "${nifti_file}" .nii.gz)

    # Copy all associated files
    cp "${RAW_DWI_DIR}/${base_name}.nii.gz" "${PREPARED_DIR}/dwi.nii.gz"
    cp "${RAW_DWI_DIR}/${base_name}.bval"   "${PREPARED_DIR}/dwi.bval"
    cp "${RAW_DWI_DIR}/${base_name}.bvec"   "${PREPARED_DIR}/dwi.bvec"
    cp "${RAW_DWI_DIR}/${base_name}.json"   "${PREPARED_DIR}/dwi.json"
done

echo "Data copying finished."