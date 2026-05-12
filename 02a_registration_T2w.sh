source config/config.sh

# get the subject T2
T2W="${T2W_DIR}/${SUBJECT_ID}/${SESSION_ID}/anat/${SUBJECT_ID}_${SESSION_ID}_rec-nesvor_T2w.nii.gz"
T2W_SEG="${T2W_DIR}/${SUBJECT_ID}/${SESSION_ID}/anat/${SUBJECT_ID}_${SESSION_ID}_rec-nesvor_seg-bounti_dseg.nii.gz"

T2W_MASK="$OUTPUT_DIR_TMP/${BASENAME}_T2w_brain_mask.nii.gz"
fslmaths $T2W_SEG -bin -dilM $T2W_MASK       # crete a mask from the bounti labels to speedup the registration

# get the age-matched atlas
ATLAS_T2W=${ATLAS_DIR}/structural/t2-t${GW}.00.nii.gz
ATLAS_SEG=${ATLAS_DIR}/extended_parcellations/bounti_symmetrical-t${GW}.00_dhcp-19.nii.gz
ATLAS_MASK=${ATLAS_DIR}/masks_dilated/mask-t${GW}.00_dhcp-19.nii.gz

# extract the smoothed cortex from both of the T2
SUBJECT_CORTEX="$OUTPUT_DIR_TMP/${BASENAME}_subject_cortex.nii.gz"
ATLAS_CORTEX="$OUTPUT_DIR_TMP/${BASENAME}_atlas_cortex.nii.gz"
fslmaths "${T2W_SEG}" -thr 3 -uthr 4 -bin -s 1 "$OUTPUT_DIR_TMP/${BASENAME}_subject_cortex.nii.gz"
fslmaths "${ATLAS_SEG}" -thr 2 -uthr 2 -bin -s 1 "$OUTPUT_DIR_TMP/${BASENAME}_atlas_cortex.nii.gz"


# =========================================================================
# ATLAS to SUBJECT T2 (Create Warped Atlas)
# =========================================================================

echo "Registering Atlas T2 to Subject T2..."

flirt \
    -in "${ATLAS_T2W}" \
    -ref "${T2W}" \
    -omat "$OUTPUT_DIR_TMP/${BASENAME}_Atlas_to_T2_12dof.mat" \
    -dof 12 

$C3D_TOOL_PATH \
    -ref "${T2W}" -src "${ATLAS_T2W}" \
   "$OUTPUT_DIR_TMP/${BASENAME}_Atlas_to_T2_12dof.mat" \
    -fsl2ras -oitk "$OUTPUT_DIR_TMP/${BASENAME}_Atlas_to_T2_12dof.txt"

PREFIX="$OUTPUT_DIR_TMP/${BASENAME}_Atlas_to_T2_"

antsRegistration \
    --verbose 0 --dimensionality 3 --float 1 \
    --output ["$PREFIX","${PREFIX}Warped_Atlas.nii.gz"] \
    --interpolation Linear \
    --winsorize-image-intensities [0.005,0.995] \
    --use-histogram-matching 1 \
    --initial-moving-transform "$OUTPUT_DIR_TMP/${BASENAME}_Atlas_to_T2_12dof.txt" \
    --transform SyN[0.1,3,0] \
    --metric Mattes["${T2W}","${ATLAS_T2W}",1,32] \
    --metric MeanSquares["${SUBJECT_CORTEX}","${ATLAS_CORTEX}",0.3,0] \
    --convergence [100x100x100x80,1e-6,10] \
    --shrink-factors 6x4x2x1 \
    --smoothing-sigmas 3x2x1x0vox \
    --masks ["${T2W_MASK}","${ATLAS_MASK}"] \
    --random-seed 42


# =========================================================================
# WARPED B1000 TEMPLATE
# =========================================================================

echo "Warping Atlas diffusion template..."


ATLAS_DWI=${ATLAS_DIR}/diffusion/dwi1000-t${GW}.00.nii.gz
WARPED_DWI_ATLAS="$OUTPUT_DIR_TMP/${BASENAME}_Warped_DWI_atlas.nii.gz"

# lets use the computed warp field and apply it to the dwi b1000 atlas template
antsApplyTransforms \
        --dimensionality 3 \
        --input "${ATLAS_DWI}" \
        --reference-image "${T2W}" \
        --output "${WARPED_DWI_ATLAS}" \
        --interpolation Linear \
        --transform "$OUTPUT_DIR_TMP/${BASENAME}_Atlas_to_T2_1Warp.nii.gz" \
        --transform "$OUTPUT_DIR_TMP/${BASENAME}_Atlas_to_T2_12dof.txt"


# =========================================================================
# WARPED B1000 TEMPLATE to SUBJECT B1000
# =========================================================================

SUBJECT_DWI="$OUTPUT_DIR_TMP/${BASENAME}_final_b1000.nii.gz"
SUBJECT_MASK="$OUTPUT_DIR_TMP/${BASENAME}_brain_mask.nii.gz"

# need to mask for better registration
SUBJECT_DWI_MASKED="$OUTPUT_DIR_TMP/${BASENAME}_final_b1000_for_reg.nii.gz"
fslmaths $SUBJECT_DWI -mul $SUBJECT_MASK $SUBJECT_DWI_MASKED

echo "Registering Warped diffusion Atlas to Subject DWI..."

flirt \
    -in "${WARPED_DWI_ATLAS}" \
    -ref "${SUBJECT_DWI_MASKED}" \
    -omat "$OUTPUT_DIR_TMP/${BASENAME}_WarpedAtlas_to_DWI_6dof.mat" \
    -out  "$OUTPUT_DIR_TMP/${BASENAME}_WarpedAtlas_to_DWI_6dof.nii.gz" \
    -dof 6 -cost mutualinfo -bins 64 \
    -searchrx -180 180 -searchry -180 180 -searchrz -180 180

$C3D_TOOL_PATH \
    -ref "${SUBJECT_DWI_MASKED}" -src "${WARPED_DWI_ATLAS}" \
    "$OUTPUT_DIR_TMP/${BASENAME}_WarpedAtlas_to_DWI_6dof.mat" \
    -fsl2ras -oitk "$OUTPUT_DIR_TMP/${BASENAME}_WarpedAtlas_to_DWI_6dof.txt"

PREFIX="$OUTPUT_DIR_TMP/${BASENAME}_WarpedAtlas_to_DWI_"

antsRegistration \
    --verbose 0 --dimensionality 3 --float 0 \
    --output ["$PREFIX","${PREFIX}Warped.nii.gz"] \
    --interpolation Linear \
    --winsorize-image-intensities [0.005,0.995] \
    --use-histogram-matching 1 \
    --initial-moving-transform "$OUTPUT_DIR_TMP/${BASENAME}_WarpedAtlas_to_DWI_6dof.txt" \
    --transform SyN[0.1,3,0] \
    --metric Mattes["${SUBJECT_DWI_MASKED}","${WARPED_DWI_ATLAS}",1,32] \
    --convergence [100x100x80x50,1e-6,10] \
    --shrink-factors 4x2x2x1 \
    --smoothing-sigmas 3x2x1x0vox \
    --masks ["${SUBJECT_MASK}","${T2W_MASK}"] \
    --random-seed 42


cp "$OUTPUT_DIR_TMP/${BASENAME}_WarpedAtlas_to_DWI_1Warp.nii.gz" "$OUTPUT_DIR_BIDS_XFM/${BASENAME}_T2w_to_DWI_Warp.nii.gz" 
cp "$OUTPUT_DIR_TMP/${BASENAME}_WarpedAtlas_to_DWI_6dof.txt" "$OUTPUT_DIR_BIDS_XFM/${BASENAME}_T2w_to_DWI_Rigid.nii.gz" 
