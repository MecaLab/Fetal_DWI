# compute or extract qc metrics
DERIVATIVES_BASE="/envau/work/meca/users/cazzolla.m/Marsfet_V2/derivatives/eddy"

QC_DIR="${DERIVATIVES_DIR}/99_QC"
mkdir -p "${QC_DIR}"

python3 "${SCRIPTS_DIR}/get_QC_metrics.py" "${DERIVATIVES_BASE}" "${SUBJECT_ID}" "${SESSION_ID}" "${SERIE_ID}"
python3 "${SCRIPTS_DIR}/plot_outliers.py" "${DERIVATIVES_BASE}" "${SUBJECT_ID}" "${SESSION_ID}" "${SERIE_ID}"


FA="${DERIVATIVES_DIR}/04_tensor/template_fa.nii.gz"
ADC="${DERIVATIVES_DIR}/04_tensor/template_adc.nii.gz"
VEC="${DERIVATIVES_DIR}/04_tensor/template_vec.nii.gz"

ADC_IMAGE="${DERIVATIVES_DIR}/04_tensor/image_adc.nii.gz"
PARCELLATIONS="${DERIVATIVES_DIR}/03_registration/bounti_symmetrical_warped.nii.gz"


# cortex lightbox
LABEL_MASK_TMP=$(mktemp -p "$QC_DIR" --suffix=.nii.gz)
fslmaths "$PARCELLATIONS" -thr 2 -uthr 2 -bin "$LABEL_MASK_TMP"

PYTHONWARNINGS=ignore MPLBACKEND=Agg render \
    --scene lightbox -of "$QC_DIR/cortex_axial.png" \
    -sz 2400 1200  -hc -hl -zx z \
    -zr 0 1 \
    "$ADC_IMAGE" -ot volume -cm greyscale \
    -dr 0 0.003 \
    "$LABEL_MASK_TMP" -ot mask --maskColour 1 0 0 -a 30


# fa lightbox
PYTHONWARNINGS=ignore MPLBACKEND=Agg render \
    --scene lightbox -of "$QC_DIR/snapshot_lightbox_fa_axial.png" \
    -sz 2400 1200 -vl 28 38 35 -hc -hl -zx z \
    -zr 0 1 \
    "$FA" -ot volume -cm greyscale \
    -dr 0 1 

PYTHONWARNINGS=ignore MPLBACKEND=Agg render \
    --scene lightbox -of "$QC_DIR/snapshot_lightbox_fa_coronal.png" \
    -sz 2400 1200 -vl 28 38 35 -hc -hl -zx y \
    -zr 0 1 \
    "$FA" -ot volume -cm greyscale \
    -dr 0 1 

PYTHONWARNINGS=ignore MPLBACKEND=Agg render \
    --scene lightbox -of "$QC_DIR/snapshot_lightbox_fa_sagittal.png" \
    -sz 2400 1200 -vl 28 38 35 -hc -hl -zx x \
    -zr 0 1 \
    "$FA" -ot volume -cm greyscale \
    -dr 0 1 



# md lightbox
PYTHONWARNINGS=ignore MPLBACKEND=Agg render \
    --scene lightbox -of "$QC_DIR/snapshot_lightbox_adc_axial.png" \
    -sz 2400 1200 -vl 28 38 35 -hc -hl -zx z \
    -zr 0 1 \
    "$ADC" -ot volume -cm greyscale \
    -dr 0 0.003

PYTHONWARNINGS=ignore MPLBACKEND=Agg render \
    --scene lightbox -of "$QC_DIR/snapshot_lightbox_adc_coronal.png" \
    -sz 2400 1200 -vl 28 38 35 -hc -hl -zx y \
    -zr 0 1 \
    "$ADC" -ot volume -cm greyscale \
    -dr 0 0.003

PYTHONWARNINGS=ignore MPLBACKEND=Agg render \
    --scene lightbox -of "$QC_DIR/snapshot_lightbox_adc_sagittal.png" \
    -sz 2400 1200 -vl 28 38 35 -hc -hl -zx x \
    -zr 0 1 \
    "$ADC" -ot volume -cm greyscale \
    -dr 0 0.003



# vec lightbox
PYTHONWARNINGS=ignore MPLBACKEND=Agg render \
    --scene lightbox -of "$QC_DIR/snapshot_lightbox_vec_axial.png" \
    -sz 2400 1200 -vl 28 38 35 -hc -hl -zx z \
    -zr 0 1 \
    "$VEC" -ot rgbvector \
    -b 60 -c 70 

PYTHONWARNINGS=ignore MPLBACKEND=Agg render \
    --scene lightbox -of "$QC_DIR/snapshot_lightbox_vec_coronal.png" \
    -sz 2400 1200 -vl 28 38 35 -hc -hl -zx y \
    -zr 0 1 \
    "$VEC" -ot rgbvector \
    -b 60 -c 70 

PYTHONWARNINGS=ignore MPLBACKEND=Agg render \
    --scene lightbox -of "$QC_DIR/snapshot_lightbox_vec_sagittal.png" \
    -sz 2400 1200 -vl 28 38 35 -hc -hl -zx x \
    -zr 0 1 \
    "$VEC" -ot rgbvector \
    -b 60 -c 70 



# cfa lighbox
PYTHONWARNINGS=ignore MPLBACKEND=Agg render \
    --scene lightbox -of "$QC_DIR/snapshot_lightbox_cfa_axial.png" \
    -sz 2400 1200 -vl 28 38 35 -hc -hl -zx z \
    -zr 0 1 \
    "$FA" -ot volume \
    "$VEC" -ot rgbvector -b 80 -c 85 -mo "$FA"

PYTHONWARNINGS=ignore MPLBACKEND=Agg render \
    --scene lightbox -of "$QC_DIR/snapshot_lightbox_cfa_coronal.png" \
    -sz 2400 1200 -vl 28 38 35 -hc -hl -zx y \
    -zr 0 1 \
    "$FA" -ot volume \
    "$VEC" -ot rgbvector -b 80 -c 85 -mo "$FA"

PYTHONWARNINGS=ignore MPLBACKEND=Agg render \
    --scene lightbox -of "$QC_DIR/snapshot_lightbox_cfa_sagittal.png" \
    -sz 2400 1200 -vl 28 38 35 -hc -hl -zx x \
    -zr 0 1 \
    "$FA" -ot volume \
    "$VEC" -ot rgbvector -b 80 -c 85 -mo "$FA"


