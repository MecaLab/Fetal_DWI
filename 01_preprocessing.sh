source config/config.sh

RAW_NII="${RAWDATA_DIR}/${SUBJECT_ID}/${SESSION_ID}/dwi/${BASENAME}_dwi.nii.gz"
RAW_BVEC="${RAWDATA_DIR}/${SUBJECT_ID}/${SESSION_ID}/dwi/${BASENAME}_dwi.bvec"
RAW_BVAL="${RAWDATA_DIR}/${SUBJECT_ID}/${SESSION_ID}/dwi/${BASENAME}_dwi.bval"
RAW_JSON="${RAWDATA_DIR}/${SUBJECT_ID}/${SESSION_ID}/dwi/${BASENAME}_dwi.json"


 # --- Step 0: Data Conversion ---
mrconvert \
    "$RAW_NII" "$OUTPUT_DIR_TMP/${BASENAME}_dwi.mif" \
    -fslgrad "$RAW_BVEC" "$RAW_BVAL" \
    -json_import "$RAW_JSON" \
    -export_pe_eddy "$OUTPUT_DIR_TMP/${BASENAME}_eddy_acqp.txt" "$OUTPUT_DIR_TMP/${BASENAME}_eddy_index.txt" \
    -nthreads $NTHR \
    -force


 # --- Step 1: Denoising ---
dwidenoise \
    "$OUTPUT_DIR_TMP/${BASENAME}_dwi.mif" \
    "$OUTPUT_DIR_TMP/${BASENAME}_dwi_denoised.mif" \
    -noise "$OUTPUT_DIR_TMP/${BASENAME}_noise.nii.gz"\
    -nthreads $NTHR \
    -force

mrconvert \
    "$OUTPUT_DIR_TMP/${BASENAME}_dwi_denoised.mif" \
    "$OUTPUT_DIR_TMP/${BASENAME}_dwi_denoised.nii.gz" \
    -nthreads $NTHR \
    -force


# --- Step 2: Extract b0 and b1O00 ---
dwiextract \
    "$OUTPUT_DIR_TMP/${BASENAME}_dwi_denoised.mif" \
    -bzero - | mrmath - mean -axis 3 "$OUTPUT_DIR_TMP/${BASENAME}_b0_denoised.nii.gz"\
    -nthreads $NTHR \
    -force

dwiextract \
    "$OUTPUT_DIR_TMP/${BASENAME}_dwi_denoised.mif" \
    -no_bzero - | mrmath - mean -axis 3 "$OUTPUT_DIR_TMP/${BASENAME}_b1000_denoised.nii.gz" \
    -nthreads $NTHR \
    -force


# --- Step 3: Brain Extraction using Fetal BET ---
BRAIN_MASK="$OUTPUT_DIR_TMP/${BASENAME}_brain_mask.nii.gz"
BRAIN_MASK_DILATED="$OUTPUT_DIR_TMP/${BASENAME}_brain_mask_dilated.nii.gz"
BRAIN_MASK_DILATED_2="$OUTPUT_DIR_TMP/${BASENAME}_brain_mask_dilated_2.nii.gz"

# FSL on the cluster has its own envirorment
# to use mine i need to purge
module purge

python3 \
    "$BET_SCRIPT" \
    --saved_model_path "$MODEL_PATH" \
    --input_path "$OUTPUT_DIR_TMP/${BASENAME}_b0_denoised.nii.gz" \
    --output_path "$OUTPUT_DIR_TMP" \
    --suffix mask

mv "$OUTPUT_DIR_TMP/${BASENAME}_b0_denoised_mask.nii.gz" "$BRAIN_MASK"
python3 "scripts/postprocess_mask.py" "$BRAIN_MASK" "$BRAIN_MASK"

module load all
module load ANTS/0.2.6.4
module load mrtrix/3.0.8
module load singularity
module load FSL/0.6.0.7.18


fslmaths "${BRAIN_MASK}" -kernel 3D -dilM "${BRAIN_MASK_DILATED}"
fslmaths "${BRAIN_MASK_DILATED}" -kernel 2D -dilM "${BRAIN_MASK_DILATED_2}"


# --- Step 4: N4 Bias Field Correction ---

# replicate the dwibiascorrect from mrtrix3
# for some reason when called from mrtrix there is ANTS error (origins dont match)
# doing it manually fix the issue (magic...)

echo "Running N4 Bias Field Correction..."

N4_CORRECTED_B0="$OUTPUT_DIR_TMP/${BASENAME}_b0_n4corrected.nii.gz"
N4_INITIAL_BIAS_FIELD="$OUTPUT_DIR_TMP/${BASENAME}_b0_initial_bias_field.nii.gz"
N4_FINAL_BIAS_FIELD="$OUTPUT_DIR_TMP/${BASENAME}_b0_final_bias_field.nii.gz"

N4BiasFieldCorrection \
    -d 3 \
    -i "$OUTPUT_DIR_TMP/${BASENAME}_b0_denoised.nii.gz" \
    -w "$BRAIN_MASK_DILATED" \
    -o "[$N4_CORRECTED_B0,$N4_INITIAL_BIAS_FIELD]" \
    -s 2 -b [100,3] -c [1000,0.0] \

# Compute the sum of intensities inside the mask before and after N4
S_ORIG=$(mrcalc "$OUTPUT_DIR_TMP/${BASENAME}_b0_denoised.nii.gz" "$BRAIN_MASK_DILATED" -mult - | mrmath - sum - -axis 0 | mrmath - sum - -axis 1 | mrmath - sum - -axis 2 | mrdump - | awk '{print $1}')
S_CORR=$(mrcalc "$N4_CORRECTED_B0" "$BRAIN_MASK_DILATED" -mult - | mrmath - sum - -axis 0 | mrmath - sum - -axis 1 | mrmath - sum - -axis 2 | mrdump - | awk '{print $1}')

# Calculate the global intensity scaling factor
SCALE=$(LC_NUMERIC=C awk "BEGIN {printf \"%.6f\", $S_ORIG == 0 ? 1.0 : $S_CORR / $S_ORIG}")

echo "Original intensity sum: $S_ORIG"
echo "Corrected intensity sum: $S_CORR"
echo "Global intensity scale factor: $SCALE"

# Scale the initial bias field to create the final, intensity-preserving field
mrcalc "$N4_INITIAL_BIAS_FIELD" "$SCALE" -mult "$N4_FINAL_BIAS_FIELD" -force

# Apply the final scaled bias field to the full denoised DWI series
mrcalc "$OUTPUT_DIR_TMP/${BASENAME}_dwi_denoised.mif" "$N4_FINAL_BIAS_FIELD" -div "$OUTPUT_DIR_TMP/${BASENAME}_dwi_biascorr.mif" -force

mrconvert \
    "$OUTPUT_DIR_TMP/${BASENAME}_dwi_biascorr.mif" \
    "$OUTPUT_DIR_TMP/${BASENAME}_dwi_biascorr.nii.gz" \
    -nthreads $NTHR \
    -force


# --- Step 5: Eddy Current and Motion Correction ---

MPORDER=$(python3 -c "import nibabel as nib; print(nib.load('$OUTPUT_DIR_TMP/${BASENAME}_dwi_biascorr.nii.gz').shape[2] - 1)")
echo "Using mporder = $MPORDER"

# Candidate values for --ol_nstd
OL_NSTD_VALUES=(2.5 3 3.5 4 4.5 5 5.5 6 6.5)

SUCCESS=0
for OL_NSTD in "${OL_NSTD_VALUES[@]}"; do
    echo "Trying eddy with --ol_nstd=${OL_NSTD}..."
    
EDDY_CMD="eddy diffusion \
    --imain=\"$OUTPUT_DIR_TMP/${BASENAME}_dwi_biascorr.nii.gz\" \
    --mask=\"$BRAIN_MASK_DILATED_2\" \
    --index=\"$OUTPUT_DIR_TMP/${BASENAME}_eddy_index.txt\" \
    --acqp=\"$OUTPUT_DIR_TMP/${BASENAME}_eddy_acqp.txt\" \
    --bvecs=\"$RAW_BVEC\" \
    --bvals=\"$RAW_BVAL\" \
    --json=\"$RAW_JSON\" \
    --out=\"$OUTPUT_DIR_TMP/${BASENAME}_dwi_eddycorr\" \
    --slm=linear \
    --repol \
    --ol_nstd=${OL_NSTD} \
    --ol_pos \
    --nvoxhp=5000\
    --niter=8 \
    --fwhm=10,8,4,2,0,0,0,0 \
    --ol_type=sw \
    --mporder=${MPORDER} \
    --s2v_niter=8 \
    --s2v_lambda=1 \
    --data_is_shelled \
    --nthr=$NTHR \
    --cnr_maps \
    --residuals \
    --verbose"

    eval $EDDY_CMD

    if [ -f "$OUTPUT_DIR_TMP/${BASENAME}_dwi_eddycorr.nii.gz" ]; then
        echo "Eddy succeeded with --ol_nstd=${OL_NSTD}"
        SUCCESS=1
        break
    else
        echo "Eddy failed with --ol_nstd=${OL_NSTD}"
    fi
done

if [ $SUCCESS -eq 0 ]; then
    echo "All eddy attempts failed."
    touch "$OUTPUT_DIR_TMP/${BASENAME}_eddy_failed.txt"
fi

# the interpolation with eddy uses spline, negative number can appear, set them to zero
fslmaths "$OUTPUT_DIR_TMP/${BASENAME}_dwi_eddycorr.nii.gz" -thr 0 "$OUTPUT_DIR_TMP/${BASENAME}_dwi_eddycorr.nii.gz"


EDDY_ROTATED_BVECS="$OUTPUT_DIR_TMP/${BASENAME}_dwi_eddycorr.eddy_rotated_bvecs"
mrconvert \
    "$OUTPUT_DIR_TMP/${BASENAME}_dwi_eddycorr.nii.gz" \
    "$OUTPUT_DIR_TMP/${BASENAME}_dwi_final.mif" \
    -fslgrad "$EDDY_ROTATED_BVECS" "$RAW_BVAL" \
    -json_import "$RAW_JSON" \
    -export_grad_mrtrix "$OUTPUT_DIR_TMP/${BASENAME}_gradients.b" \
    -nthreads $NTHR \
    -force

echo "Running eddy QC..."
rm -rf "$OUTPUT_DIR_TMP/${BASENAME}_dwi_eddycorr.qc"
eddy_quad \
    "$OUTPUT_DIR_TMP/${BASENAME}_dwi_eddycorr" \
    -idx "$OUTPUT_DIR_TMP/${BASENAME}_eddy_index.txt" \
    -par "$OUTPUT_DIR_TMP/${BASENAME}_eddy_acqp.txt" \
    -m "$BRAIN_MASK" \
    -b "$RAW_BVAL" \
    -g "$EDDY_ROTATED_BVECS" \
    -j "$RAW_JSON"


# --- Step 6: Final extractions ---

dwiextract "$OUTPUT_DIR_TMP/${BASENAME}_dwi_final.mif" -bzero - | mrmath - mean -axis 3 "$OUTPUT_DIR_TMP/${BASENAME}_final_b0.nii.gz" -force
dwiextract "$OUTPUT_DIR_TMP/${BASENAME}_dwi_final.mif" -no_bzero - | mrmath - mean -axis 3 "$OUTPUT_DIR_TMP/${BASENAME}_final_b1000.nii.gz" -force 

fslmaths "$OUTPUT_DIR_TMP/${BASENAME}_final_b0.nii.gz" -mul "${BRAIN_MASK_DILATED}" "$OUTPUT_DIR_TMP/${BASENAME}_final_b0_masked.nii.gz"
fslmaths "$OUTPUT_DIR_TMP/${BASENAME}_final_b1000.nii.gz" -mul "${BRAIN_MASK_DILATED}" "$OUTPUT_DIR_TMP/${BASENAME}_final_b1000_masked.nii.gz"

cp "$OUTPUT_DIR_TMP/${BASENAME}_dwi_eddycorr.nii.gz" "$OUTPUT_DIR_BIDS_DWI/${BASENAME}_desc-preproc_dwi.nii.gz"
cp $EDDY_ROTATED_BVECS "$OUTPUT_DIR_BIDS_DWI/${BASENAME}_desc-preproc_dwi.bvec"
cp $RAW_BVAL "$OUTPUT_DIR_BIDS_DWI/${BASENAME}_desc-preproc_dwi.bval"
cp $RAW_JSON "$OUTPUT_DIR_BIDS_DWI/${BASENAME}_desc-preproc_dwi.json"
cp "$BRAIN_MASK "$OUTPUT_DIR_BIDS_DWI/${BASENAME}_desc-brain_mask.nii.gz"
