PREPARED_DIR="${DERIVATIVES_DIR}/01_prepared_data"
PREPROC_DIR="${DERIVATIVES_DIR}/02_preprocessed_data"
REG_DIR="${DERIVATIVES_DIR}/03_registration"

ATLAS_DIR="/envau/work/meca/data/Fetus/datasets/atlas_fetus/fetal_brain_mri_atlas/diffusion/"
ATLAS_MASK_DIR="/envau/work/meca/data/Fetus/datasets/atlas_fetus/fetal_brain_mri_atlas/masks/"

mkdir -p "${REG_DIR}"

# --- Step 0: Get the GW ---
GW_SCRIPT="${SCRIPTS_DIR}/get_GW.py"
GW=$(python3 "${GW_SCRIPT}" "${SUBJECT_ID}" "${SESSION_ID}")
echo "Gestational Week ${GW}"


# --- Step 1: Rigid and Affine ---
MOVING="${ATLAS_DIR}/dwi1000-t${GW}.00.nii.gz"
REFERENCE="${PREPROC_DIR}/final_b1000_masked.nii.gz"

cp "${REFERENCE}" "${REG_DIR}/b1000.nii.gz"
cp "${MOVING}" "${REG_DIR}/atlas.nii.gz"

echo "Registering atlas (GW ${GW}) to subject space..."
echo "Rigid registration (6 DOF)..."
flirt \
    -in "${MOVING}" \
    -ref "${REFERENCE}" \
    -omat "${REG_DIR}/6dof.mat" \
    -dof 6 \
    -cost mutualinfo \
    -bins 64 \
    -searchrx -180 180 -searchry -180 180 -searchrz -180 180 \

echo "Affine registration (12 DOF)..."
flirt \
    -in "${MOVING}" \
    -ref "${REFERENCE}" \
    -omat "${REG_DIR}/12dof.mat" \
    -init "${REG_DIR}/6dof.mat" \
    -out "${REG_DIR}/atlas_affined.nii.gz" \
    -dof 12 \
    -cost mutualinfo \
    -bins 64 \
    -searchrx -25 25 -searchry -25 25 -searchrz -25 25 \
    


# --- Step 2: Non linear ---
echo "Non-linear registration..."

ATLAS_MASK="${ATLAS_MASK_DIR}/mask-t${GW}.00_dhcp-19.nii.gz"

tools/c3d_affine_tool \
    -ref "$REFERENCE" \
    -src "$MOVING" \
    "${REG_DIR}/12dof.mat" \
    -fsl2ras -oitk "${REG_DIR}/12dof.txt"

prefix="${REG_DIR}/atlas_non_linear_"
warped_image="${prefix}Image.nii.gz"

antsRegistration \
    --verbose 0 --dimensionality 3 --float 0 \
    --output ["${prefix}","${warped_image}"] \
    --interpolation BSpline --use-histogram-matching 1 \
    --winsorize-image-intensities [0.005,0.995] \
    --initial-moving-transform "${REG_DIR}/12dof.txt" \
    --transform SyN[0.1,3,0] \
    --metric Mattes["${REFERENCE}","${MOVING}",1,32] \
    --convergence [200x200x200x200x200x200,1e-7,10] \
    --shrink-factors 4x4x2x2x1x1 \
    --smoothing-sigmas 6x5x4x2x1x0 \
    --masks ["${PREPROC_DIR}/brain_mask.nii.gz","${ATLAS_MASK}"]


# --- Step 3: Parcellation propagation ---

PARCELLATIONS_DIR="/envau/work/meca/data/Fetus/datasets/atlas_fetus/fetal_brain_mri_atlas/extra_parcellations/"

BOUNTI="${PARCELLATIONS_DIR}/bounti-t${GW}.00_dhcp-19.nii.gz"
BOUNTI_SYM="${PARCELLATIONS_DIR}/bounti_symmetrical-t${GW}.00_dhcp-19.nii.gz"
HARVARD_TISSUE="${PARCELLATIONS_DIR}/harvard_tissue-t${GW}.00_dhcp-19.nii.gz"
HARVARD_REGIONAL="${PARCELLATIONS_DIR}/harvard_regional-t${GW}.00_dhcp-19.nii.gz"
NEONATAL_REGIONAL="${PARCELLATIONS_DIR}/neonatal_regional-t${GW}.00_dhcp-19.nii.gz"
NEONATAL_WM="${PARCELLATIONS_DIR}/neonatal_WM-t${GW}.00_dhcp-19.nii.gz"

# define output names
OUT_BOUNTI="${REG_DIR}/bounti_warped.nii.gz"
OUT_BOUNTI_SYM="${REG_DIR}/bounti_symmetrical_warped.nii.gz"
OUT_HARVARD_TISSUE="${REG_DIR}/harvard_tissue_warped.nii.gz"
OUT_HARVARD_REGIONAL="${REG_DIR}/harvard_regional_warped.nii.gz"
OUT_NEONATAL_REGIONAL="${REG_DIR}/neonatal_regional_warped.nii.gz"
OUT_NEONATAL_WM="${REG_DIR}/neonatal_WM_warped.nii.gz"

# loop over parcellations and outputs in parallel
for PARCELLATIONS in \
    "$BOUNTI" "$BOUNTI_SYM" "$HARVARD_TISSUE" "$HARVARD_REGIONAL" "$NEONATAL_REGIONAL" "$NEONATAL_WM"
do
    case "$PARCELLATIONS" in
        "$BOUNTI") OUT="$OUT_BOUNTI" ;;
        "$BOUNTI_SYM") OUT="$OUT_BOUNTI_SYM" ;;
        "$HARVARD_TISSUE") OUT="$OUT_HARVARD_TISSUE" ;;
        "$HARVARD_REGIONAL") OUT="$OUT_HARVARD_REGIONAL" ;;
        "$NEONATAL_REGIONAL") OUT="$OUT_NEONATAL_REGIONAL" ;;
        "$NEONATAL_WM") OUT="$OUT_NEONATAL_WM" ;;
    esac

    echo "Warping parcellation: $(basename "${PARCELLATIONS}") → $(basename "${OUT}")"
    antsApplyTransforms \
        --verbose 0 \
        --dimensionality 3 \
        --input "${PARCELLATIONS}" \
        --reference-image "${REFERENCE}" \
        --output "${OUT}" \
        --interpolation GenericLabel \
        --transform "${prefix}1Warp.nii.gz" \
        --transform "${REG_DIR}/12dof.txt"
done

