PREPARED_DIR="${DERIVATIVES_DIR}/01_prepared_data"
PREPROC_DIR="${DERIVATIVES_DIR}/02_preprocessed_data"

# Paths to external scripts and models
MODEL_PATH="${TOOLS_DIR}/Fetal_BET/AttUNet.pth"
BET_SCRIPT="${TOOLS_DIR}/Fetal_BET/inference.py"
MASK_POSTPROCESS_SCRIPT="${SCRIPTS_DIR}/postprocess_mask.py"

mkdir -p "${PREPROC_DIR}"

NII="${PREPARED_DIR}/dwi.nii.gz"
BVEC="${PREPARED_DIR}/dwi.bvec"
BVAL="${PREPARED_DIR}/dwi.bval"
JSON="${PREPARED_DIR}/dwi.json"


 # --- Step 0: Data Conversion ---
mrconvert "$NII" "$PREPROC_DIR/dwi.mif" -fslgrad "$BVEC" "$BVAL" -json_import "$JSON" \
        -export_pe_eddy "$PREPROC_DIR/eddy_acqp.txt" "$PREPROC_DIR/eddy_index.txt" -force


 # --- Step 1: Denoising ---
dwidenoise "$PREPROC_DIR/dwi.mif" "$PREPROC_DIR/dwi_denoised.mif" -noise "$PREPROC_DIR/noise.nii.gz" -force
mrconvert "$PREPROC_DIR/dwi_denoised.mif" "$PREPROC_DIR/dwi_denoised.nii.gz" -force


# --- Step 2: Extract b0 and b1O00 ---
dwiextract "$PREPROC_DIR/dwi_denoised.mif" -bzero - | mrmath - mean -axis 3 "$PREPROC_DIR/b0_denoised.nii.gz" -force
dwiextract "$PREPROC_DIR/dwi_denoised.mif" -no_bzero - | mrmath - mean -axis 3 "$PREPROC_DIR/b1000_denoised.nii.gz" -force


# --- Step 3: Brain Extraction using Fetal BET ---
ORIGINAL_BRAIN_MASK="$PREPROC_DIR/b0_denoised_mask.nii.gz"

python3 "$BET_SCRIPT" --saved_model_path "$MODEL_PATH" --input_path "$PREPROC_DIR/b0_denoised.nii.gz" --output_path "$PREPROC_DIR" --suffix mask
python3 "$SCRIPTS_DIR/postprocess_mask.py" "$ORIGINAL_BRAIN_MASK" "$ORIGINAL_BRAIN_MASK"

cp "$ORIGINAL_BRAIN_MASK" "$PREPROC_DIR/original_brain_mask.nii.gz"
mv "$ORIGINAL_BRAIN_MASK" "$PREPROC_DIR/brain_mask.nii.gz"
BRAIN_MASK="$PREPROC_DIR/brain_mask.nii.gz"

fslmaths "${BRAIN_MASK}" -kernel 3D -dilM "${BRAIN_MASK}"


# --- Step 4: N4 Bias Field Correction ---

# replicate the dwibiascorrect from mrtrix3
# for some reason when called from mrtrix there is ANTS error (origins dont match)
# doing it manually fix the issue (magic...)

echo "Running N4 Bias Field Correction..."

DWI_DENOISED_NII="$PREPROC_DIR/dwi_denoised.nii.gz"
B0_FOR_N4="$PREPROC_DIR/b0_denoised.nii.gz"
DWI_BIASCORR_NII="$PREPROC_DIR/dwi_biascorr.nii.gz"

# Define intermediate files for clarity
N4_INPUT_B0_STD="${PREPROC_DIR}/n4_input_b0_std.nii.gz"
N4_INPUT_MASK_STD="${PREPROC_DIR}/n4_input_mask_std.nii.gz"
N4_CORRECTED_B0="${PREPROC_DIR}/n4_corrected_b0.nii.gz"
N4_INITIAL_BIAS_FIELD="${PREPROC_DIR}/n4_initial_bias_field.nii.gz"
N4_FINAL_BIAS_FIELD="${PREPROC_DIR}/n4_final_scaled_bias_field.nii.gz"

# Convert images to a standard stride representation for N4
mrconvert "$B0_FOR_N4" "$N4_INPUT_B0_STD" -strides +1,+2,+3 -force
mrconvert "$BRAIN_MASK" "$N4_INPUT_MASK_STD" -strides +1,+2,+3 -force
fslcpgeom "$N4_INPUT_B0_STD" "$N4_INPUT_MASK_STD" # Ensure geometry headers match

# Apply N4BiasFieldCorrection on the b0 to estimate the field
N4BiasFieldCorrection -d 3 -i "$N4_INPUT_B0_STD" -w "$N4_INPUT_MASK_STD" \
    -o "[$N4_CORRECTED_B0,$N4_INITIAL_BIAS_FIELD]" -s 3 -b [100,3] -c [1000,0.0]

# Compute the sum of intensities inside the mask before and after N4
S_ORIG=$(mrcalc "$N4_INPUT_B0_STD" "$N4_INPUT_MASK_STD" -mult - | mrmath - sum - -axis 0 | mrmath - sum - -axis 1 | mrmath - sum - -axis 2 | mrdump - | awk '{print $1}')
S_CORR=$(mrcalc "$N4_CORRECTED_B0" "$N4_INPUT_MASK_STD" -mult - | mrmath - sum - -axis 0 | mrmath - sum - -axis 1 | mrmath - sum - -axis 2 | mrdump - | awk '{print $1}')

# Calculate the global intensity scaling factor
SCALE=$(LC_NUMERIC=C awk "BEGIN {printf \"%.6f\", $S_ORIG == 0 ? 1.0 : $S_CORR / $S_ORIG}")

echo "Original intensity sum: $S_ORIG"
echo "Corrected intensity sum: $S_CORR"
echo "Global intensity scale factor: $SCALE"

# Scale the initial bias field to create the final, intensity-preserving field
mrcalc "$N4_INITIAL_BIAS_FIELD" "$SCALE" -mult "$N4_FINAL_BIAS_FIELD" -force
mrcalc "$DWI_DENOISED_NII" "$N4_FINAL_BIAS_FIELD" -div "$DWI_BIASCORR_NII" -force

rm "$N4_INPUT_B0_STD" "$N4_INPUT_MASK_STD" "$N4_INITIAL_BIAS_FIELD" "$N4_FINAL_BIAS_FIELD" "$N4_CORRECTED_B0"
echo "✅ Bias correction completed."


# --- Step 5: Eddy Current and Motion Correction ---

MPORDER=$(python3 -c "import nibabel as nib; print(nib.load('$DWI_BIASCORR_NII').shape[2] - 1)")
echo "Using mporder = $MPORDER"

# Candidate values for --ol_nstd
OL_NSTD_VALUES=(2.5 3 3.5 4 4.5 5 5.5 6 6.5)

SUCCESS=0
for OL_NSTD in "${OL_NSTD_VALUES[@]}"; do
    echo "Trying eddy with --ol_nstd=${OL_NSTD}..."
    
    EDDY_CMD="eddy diffusion \
        --imain=\"$DWI_BIASCORR_NII\" \
        --mask=\"$BRAIN_MASK\" \
        --index=\"$PREPROC_DIR/eddy_index.txt\" \
        --acqp=\"$PREPROC_DIR/eddy_acqp.txt\" \
        --bvecs=\"$BVEC\" \
        --bvals=\"$BVAL\" \
        --json=\"$JSON\" \
        --out=\"$PREPROC_DIR/dwi_eddycorr\" \
        --slm=linear --repol --ol_nstd=${OL_NSTD} --ol_pos \
        --nvoxhp=5000 --niter=8 \
        --fwhm=10,8,4,2,0,0,0,0 \
        --ol_type=sw --mporder=${MPORDER} \
        --s2v_niter=8 --s2v_lambda=1 \
        --data_is_shelled --nthr=64 --cnr_maps --residuals --verbose"

    eval $EDDY_CMD

    if [ -f "$PREPROC_DIR/dwi_eddycorr.nii.gz" ]; then
        echo "Eddy succeeded with --ol_nstd=${OL_NSTD}"
        SUCCESS=1
        break
    else
        echo "Eddy failed with --ol_nstd=${OL_NSTD}"
    fi
done

if [ $SUCCESS -eq 0 ]; then
    echo "All eddy attempts failed."
    touch "$PREPROC_DIR/eddy_failed.txt"
fi


EDDY_ROTATED_BVECS="$PREPROC_DIR/dwi_eddycorr.eddy_rotated_bvecs"
mrconvert "$PREPROC_DIR/dwi_eddycorr.nii.gz" "$PREPROC_DIR/dwi_final.mif" \
            -fslgrad "$EDDY_ROTATED_BVECS" "$BVAL" -json_import "$JSON" \
            -export_grad_mrtrix "$PREPROC_DIR/gradients.b" -force

rm -rf "$PREPROC_DIR/dwi_eddycorr.qc"
eddy_quad "$PREPROC_DIR/dwi_eddycorr" -idx "$PREPROC_DIR/eddy_index.txt" -par "$PREPROC_DIR/eddy_acqp.txt" \
    -m "$BRAIN_MASK" -b "$BVAL" -g "$EDDY_ROTATED_BVECS" -j "$JSON"


# --- Step 6: Final extractions ---

dwiextract "$PREPROC_DIR/dwi_final.mif" -bzero - | mrmath - mean -axis 3 "$PREPROC_DIR/final_b0.nii.gz" -force
dwiextract "$PREPROC_DIR/dwi_final.mif" -no_bzero - | mrmath - mean -axis 3 "$PREPROC_DIR/final_b1000.nii.gz" -force 

fslmaths "$PREPROC_DIR/final_b0.nii.gz" -mul "${BRAIN_MASK}" "$PREPROC_DIR/final_b0_masked.nii.gz"
fslmaths "$PREPROC_DIR/final_b1000.nii.gz" -mul "${BRAIN_MASK}" "$PREPROC_DIR/final_b1000_masked.nii.gz"