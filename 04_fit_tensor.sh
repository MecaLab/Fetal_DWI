source config/config.sh

# --- Step 1: Fit tensor in image space ---

DWI_NII="$OUTPUT_DIR_BIDS_DWI/${BASENAME}_desc-preproc_dwi.nii.gz"
BVECS="$OUTPUT_DIR_BIDS_DWI/${BASENAME}_desc-preproc_dwi.bvec"
BVAL="$OUTPUT_DIR_BIDS_DWI/${BASENAME}_desc-preproc_dwi.bval"
JSON="$OUTPUT_DIR_BIDS_DWI/${BASENAME}_desc-preproc_dwi.json"

# rotate the bvecs to have proper colors in image space
# need to use the rotation component of the inverse affine transform

convert_xfm \
    -omat "$OUTPUT_DIR_TMP/${BASENAME}_Atlas_to_B1000_12dof_Inverse.mat" \
    -inverse "$OUTPUT_DIR_TMP/${BASENAME}_Atlas_to_B1000_12dof.mat"

python3 "${SCRIPTS_DIR}/rotate_bvecs.py" \
    -i "$BVECS" \
    -t "$OUTPUT_DIR_TMP/${BASENAME}_Atlas_to_B1000_12dof_Inverse.mat" \
    -o "$OUTPUT_DIR_TMP/${BASENAME}_bvecs_rotated_for_tensor.bvec"

mrconvert \
    "$DWI_NII" \
    "$OUTPUT_DIR_TMP/${BASENAME}_desc-preproc_dwi_for_tensor.mif" \
    -fslgrad "$OUTPUT_DIR_TMP/${BASENAME}_bvecs_rotated_for_tensor.bvec" "$BVAL" -json_import "$JSON" -force

dwi2tensor \
    "$OUTPUT_DIR_TMP/${BASENAME}_desc-preproc_dwi_for_tensor.mif" \
    "$OUTPUT_DIR_TMP/${BASENAME}_tensor.mif" \
    -mask "$OUTPUT_DIR_TMP/${BASENAME}_brain_mask.nii.gz" -force

mrconvert \
    "$OUTPUT_DIR_TMP/${BASENAME}_tensor.mif" \
    "$OUTPUT_DIR_TMP/${BASENAME}_tensor.nii.gz" \
    -nthreads $NTHR \
    -force

tensor2metric \
    "$OUTPUT_DIR_TMP/${BASENAME}_tensor.mif" \
    -vector "$OUTPUT_DIR_TMP/${BASENAME}_tensor_imagespace_vec.nii.gz" \
    -fa "$OUTPUT_DIR_TMP/${BASENAME}_tensor_imagespace_fa.nii.gz" \
    -adc "$OUTPUT_DIR_TMP/${BASENAME}_tensor_imagespace_md.nii.gz" \
    -rd "$OUTPUT_DIR_TMP/${BASENAME}_tensor_imagespace_rd.nii.gz" \
    -ad "$OUTPUT_DIR_TMP/${BASENAME}_tensor_imagespace_ad.nii.gz" -force

cp "$OUTPUT_DIR_TMP/${BASENAME}_tensor_imagespace_vec.nii.gz" "$OUTPUT_DIR_BIDS_TENSOR/${BASENAME}_VEC.nii.gz"
cp "$OUTPUT_DIR_TMP/${BASENAME}_tensor_imagespace_fa.nii.gz" "$OUTPUT_DIR_BIDS_TENSOR/${BASENAME}_FA.nii.gz"
cp "$OUTPUT_DIR_TMP/${BASENAME}_tensor_imagespace_md.nii.gz" "$OUTPUT_DIR_BIDS_TENSOR/${BASENAME}_MD.nii.gz"
cp "$OUTPUT_DIR_TMP/${BASENAME}_tensor_imagespace_rd.nii.gz" "$OUTPUT_DIR_BIDS_TENSOR/${BASENAME}_RD.nii.gz"
cp "$OUTPUT_DIR_TMP/${BASENAME}_tensor_imagespace_ad.nii.gz" "$OUTPUT_DIR_BIDS_TENSOR/${BASENAME}_AD.nii.gz"    
cp "$OUTPUT_DIR_TMP/${BASENAME}_tensor.nii.gz" "$OUTPUT_DIR_BIDS_TENSOR/${BASENAME}_tensor.nii.gz"



# --- Step 2: Fit tensor in template space ---
# for now we use the atlas registration
# this should be changed to T2 reg if we are sure the T2 are good quality (only the qc ones)
# this is only for QC purposes (carefull may look bad due to misregistration, not actual tensor fitting issues)
# also if looks bad need to check the propagation from the T2 (look at the parcellations in diffusion space)

# original template is too high resolution (image is blurry)
# we resample to more reasonable resolution
ResampleImageBySpacing 3 \
    ${ATLAS_DIR}/diffusion/dwi1000-t${GW}.00.nii.gz \
    "$OUTPUT_DIR_TMP/${BASENAME}_atlas_15mm.nii.gz" \
    1.5 1.5 1.5 0

ATLAS_DWI=${ATLAS_DIR}/diffusion/dwi1000-t${GW}.00.nii.gz

# convert the affine to ITK format for antsApplyTransforms
$C3D_TOOL_PATH \
    -ref "$OUTPUT_DIR_TMP/${BASENAME}_atlas_15mm.nii.gz" \
    -src "${ATLAS_DWI}" \
    "$OUTPUT_DIR_TMP/${BASENAME}_Atlas_to_B1000_12dof.mat" \
    -fsl2ras -oitk "$OUTPUT_DIR_TMP/${BASENAME}_Atlas_to_B1000_12dof_Inverse.txt" 

# apply deformation and inverse affine to the DWI data
antsApplyTransforms \
    --dimensionality 3 \
    -e 3 \
    --input "$DWI_NII" \
    --reference-image "$OUTPUT_DIR_TMP/${BASENAME}_atlas_15mm.nii.gz" \
    --output "$OUTPUT_DIR_TMP/${BASENAME}_dwi_in_reference_space.nii.gz" \
    --interpolation BSpline \
    --transform ["$OUTPUT_DIR_TMP/${BASENAME}_Atlas_to_B1000_12dof.txt", 1] \
    --transform "$OUTPUT_DIR_TMP/${BASENAME}_Atlas_to_B1000_1InverseWarp.nii.gz"

# 3. Apply the same to the brain mask (NearestNeighbor so it stays binary 0/1)
antsApplyTransforms \
    --dimensionality 3 \
    --input "$OUTPUT_DIR_TMP/${BASENAME}_brain_mask.nii.gz" \
    --reference-image "$OUTPUT_DIR_TMP/${BASENAME}_atlas_15mm.nii.gz" \
    --output "$OUTPUT_DIR_TMP/${BASENAME}_brain_mask_template.nii.gz" \
    --interpolation NearestNeighbor \
    --transform ["$OUTPUT_DIR_TMP/${BASENAME}_Atlas_to_B1000_12dof.txt", 1] \
    --transform "$OUTPUT_DIR_TMP/${BASENAME}_Atlas_to_B1000_1InverseWarp.nii.gz"


mrconvert \
    "$OUTPUT_DIR_TMP/${BASENAME}_dwi_in_reference_space.nii.gz" \
    "$OUTPUT_DIR_TMP/${BASENAME}_dwi_in_reference_space.mif" \
    -fslgrad "$OUTPUT_DIR_TMP/${BASENAME}_bvecs_rotated_for_tensor.bvec" "$BVAL" \
    -json_import "$JSON" -force

dwi2tensor \
    "$OUTPUT_DIR_TMP/${BASENAME}_dwi_in_reference_space.mif" \
    "$OUTPUT_DIR_TMP/${BASENAME}_tensor_reference_space.mif" \
    -mask "$OUTPUT_DIR_TMP/${BASENAME}_brain_mask_template.nii.gz" -force

tensor2metric "$OUTPUT_DIR_TMP/${BASENAME}_tensor_reference_space.mif" \
    -vector "$OUTPUT_DIR_TMP/${BASENAME}_tensor_refspace_vec.nii.gz" \
    -fa "$OUTPUT_DIR_TMP/${BASENAME}_tensor_refspace_fa.nii.gz" \
    -adc "$OUTPUT_DIR_TMP/${BASENAME}_tensor_refspace_md.nii.gz" \
    -force

cp "$OUTPUT_DIR_TMP/${BASENAME}_tensor_refspace_vec.nii.gz" "$OUTPUT_DIR_BIDS_QC/${BASENAME}_refspace_VEC.nii.gz"
cp "$OUTPUT_DIR_TMP/${BASENAME}_tensor_refspace_fa.nii.gz" "$OUTPUT_DIR_BIDS_QC/${BASENAME}_refspace_FA.nii.gz"
cp "$OUTPUT_DIR_TMP/${BASENAME}_tensor_refspace_md.nii.gz" "$OUTPUT_DIR_BIDS_QC/${BASENAME}_refspace_MD.nii.gz"