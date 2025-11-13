PREPARED_DIR="${DERIVATIVES_DIR}/01_prepared_data"
PREPROC_DIR="${DERIVATIVES_DIR}/02_preprocessed_data"
REG_DIR="${DERIVATIVES_DIR}/03_registration"

TENSOR_DIR="${DERIVATIVES_DIR}/04_tensor"

mkdir -p "${TENSOR_DIR}"


# --- Step 1: Fit tensor in image space ---

DWI_NII="$PREPROC_DIR/dwi_eddycorr.nii.gz"
EDDY_ROTATED_BVECS="$PREPROC_DIR/dwi_eddycorr.eddy_rotated_bvecs"
BVAL="$PREPARED_DIR/dwi.bval"
JSON="$PREPARED_DIR/dwi.json"

# rotate the bvecs to have proper colors in image space
# need to use the rotation component of the inverse affine transform

convert_xfm -omat "$TENSOR_DIR/12dof_inverse.mat" -inverse "$REG_DIR/12dof.mat"
python3 "${SCRIPTS_DIR}/rotate_bvecs.py" -i "$EDDY_ROTATED_BVECS" -t "$TENSOR_DIR/12dof_inverse.mat" -o "$TENSOR_DIR/rotated_bvecs.bvec"

mrconvert "$PREPROC_DIR/dwi_eddycorr.nii.gz" "$TENSOR_DIR/reoriented_dwi.mif" \
            -fslgrad "$TENSOR_DIR/rotated_bvecs.bvec" "$BVAL" -json_import "$JSON" -force

dwi2tensor "$TENSOR_DIR/reoriented_dwi.mif" "$TENSOR_DIR/image_tensor.mif" -mask "$PREPROC_DIR/brain_mask.nii.gz" -force

tensor2metric "$TENSOR_DIR/image_tensor.mif" \
    -vector "$TENSOR_DIR/image_vec.nii.gz" \
    -fa "$TENSOR_DIR/image_fa.nii.gz" \
    -adc "$TENSOR_DIR/image_adc.nii.gz" \
    -rd "$TENSOR_DIR/image_rd.nii.gz" \
    -ad "$TENSOR_DIR/image_ad.nii.gz" -force



# --- Step 2: Fit tensor in template space ---

# convert flirt affine to ants format
tools/c3d_affine_tool \
    -ref $REG_DIR/atlas.nii.gz \
    -src "$PREPROC_DIR/final_b1000_masked.nii.gz" \
    $TENSOR_DIR/12dof_inverse.mat \
    -fsl2ras -oitk $TENSOR_DIR/12dof_inverse.txt

# original template is too high resolution (image is blurry)
# we resample to more reasonable resolution
ResampleImageBySpacing 3 \
    $REG_DIR/atlas.nii.gz \
    $REG_DIR/atlas_15mm.nii.gz \
    1.5 1.5 1.5 0

# apply deformation and inverse affine to the DWI data
antsApplyTransforms \
    --dimensionality 3 \
    -e 3 \
    --input "$PREPROC_DIR/dwi_eddycorr.nii.gz" \
    --reference-image $REG_DIR/atlas_15mm.nii.gz \
    --output $TENSOR_DIR/dwi_unwarped.nii.gz \
    --interpolation BSpline \
    --transform $TENSOR_DIR/12dof_inverse.txt \
    --transform "${REG_DIR}/atlas_non_linear_1InverseWarp.nii.gz"


antsApplyTransforms \
    --dimensionality 3 \
    --input "$PREPROC_DIR/brain_mask.nii.gz" \
    --reference-image $REG_DIR/atlas_15mm.nii.gz \
    --output $TENSOR_DIR/brain_mask_template.nii.gz \
    --interpolation NearestNeighbor \
    --transform $TENSOR_DIR/12dof_inverse.txt \
    --transform "${REG_DIR}/atlas_non_linear_1InverseWarp.nii.gz"


mrconvert $TENSOR_DIR/dwi_unwarped.nii.gz "$TENSOR_DIR/dwi_unwarped.mif" \
            -fslgrad "$TENSOR_DIR/rotated_bvecs.bvec" "$BVAL" -json_import "$JSON" -force

dwi2tensor "$TENSOR_DIR/dwi_unwarped.mif" "$TENSOR_DIR/template_tensor.mif" -mask $TENSOR_DIR/brain_mask_template.nii.gz -force

tensor2metric "$TENSOR_DIR/template_tensor.mif" \
    -vector "$TENSOR_DIR/template_vec.nii.gz" \
    -fa "$TENSOR_DIR/template_fa.nii.gz" \
    -adc "$TENSOR_DIR/template_adc.nii.gz" \
    -rd "$TENSOR_DIR/template_rd.nii.gz" \
    -ad "$TENSOR_DIR/template_ad.nii.gz" -force