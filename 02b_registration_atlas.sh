source config/config.sh

# get the age-matched atlas
ATLAS_DWI=${ATLAS_DIR}/diffusion/dwi1000-t${GW}.00.nii.gz
ATLAS_MASK=${ATLAS_DIR}/masks_dilated/mask-t${GW}.00_dhcp-19.nii.gz

# =========================================================================
# ATLAS to SUBJECT B1000 
# =========================================================================

echo "Registering Atlas DWI to Subject b1000..."

B1000="$OUTPUT_DIR_TMP/${BASENAME}_final_b1000_for_reg.nii.gz"
SUBJECT_MASK="$OUTPUT_DIR_TMP/${BASENAME}_brain_mask.nii.gz"

flirt \
    -in "${ATLAS_DWI}" \
    -ref "${B1000}" \
    -omat "$OUTPUT_DIR_TMP/${BASENAME}_Atlas_to_B1000_6dof.mat" \
    -dof 6 \
    -cost mutualinfo \
    -bins 64 \
    -searchrx -180 180 -searchry -180 180 -searchrz -180 180 \

flirt \
    -in "${ATLAS_DWI}" \
    -ref "${B1000}" \
    -omat "$OUTPUT_DIR_TMP/${BASENAME}_Atlas_to_B1000_12dof.mat" \
    -init "$OUTPUT_DIR_TMP/${BASENAME}_Atlas_to_B1000_6dof.mat" \
    -out "${OUTPUT_DIR_TMP}/${BASENAME}_Atlas_to_B1000_12dof.nii.gz" \
    -dof 12 \
    -cost mutualinfo \
    -bins 64 \
    -searchrx -25 25 -searchry -25 25 -searchrz -25 25 \

$C3D_TOOL_PATH \
    -ref "${B1000}" -src "${ATLAS_DWI}" \
    "$OUTPUT_DIR_TMP/${BASENAME}_Atlas_to_B1000_12dof.mat" \
    -fsl2ras -oitk "$OUTPUT_DIR_TMP/${BASENAME}_Atlas_to_B1000_12dof.txt" \

PREFIX="$OUTPUT_DIR_TMP/${BASENAME}_Atlas_to_B1000_"

antsRegistration \
    --verbose 0 --dimensionality 3 --float 1 \
    --output ["$PREFIX","${PREFIX}Warped_Atlas.nii.gz"] \
    --interpolation Linear \
    --winsorize-image-intensities [0.005,0.995] \
    --use-histogram-matching 1 \
    --initial-moving-transform "$OUTPUT_DIR_TMP/${BASENAME}_Atlas_to_B1000_12dof.txt" \
    --transform SyN[0.1,3,0] \
    --metric Mattes["${B1000}","${ATLAS_DWI}",1,32] \
    --convergence [200x200x100x100,1e-6,10] \
    --shrink-factors 6x4x2x1 \
    --smoothing-sigmas 3x2x1x0vox \
    --masks ["${SUBJECT_MASK}","${ATLAS_MASK}"] \
    --random-seed 42

cp "$OUTPUT_DIR_TMP/${BASENAME}_Atlas_to_B1000_1Warp.nii.gz" "$OUTPUT_DIR_BIDS_XFM/${BASENAME}_dhcp${GW}wk_to_DWI_Warp.nii.gz" 
cp "$OUTPUT_DIR_TMP/${BASENAME}_Atlas_to_B1000_12dof.txt" "$OUTPUT_DIR_BIDS_XFM/${BASENAME}_dhcp${GW}wk_to_DWI_Affine.nii.gz" 
