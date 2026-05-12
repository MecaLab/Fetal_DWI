source config/config.sh

FA="$OUTPUT_DIR_BIDS_QC/${BASENAME}_refspace_VEC.nii.gz"
MD="$OUTPUT_DIR_BIDS_QC/${BASENAME}_refspace_MD.nii.gz"
VEC="$OUTPUT_DIR_BIDS_QC/${BASENAME}_refspace_VEC.nii.gz"

# fa lightbox
PYTHONWARNINGS=ignore MPLBACKEND=Agg render \
    --scene lightbox -of "$OUTPUT_DIR_BIDS_QC/${BASENAME}_snapshot_lightbox_fa_axial.png" \
    -sz 2400 1200 -vl 28 38 35 -hc -hl -zx z \
    -zr 0 1 \
    "$FA" -ot volume -cm greyscale \
    -dr 0 1

PYTHONWARNINGS=ignore MPLBACKEND=Agg render \
    --scene lightbox -of "$OUTPUT_DIR_BIDS_QC/${BASENAME}_snapshot_lightbox_fa_coronal.png" \
    -sz 2400 1200 -vl 28 38 35 -hc -hl -zx y \
    -zr 0 1 \
    "$FA" -ot volume -cm greyscale \
    -dr 0 1

PYTHONWARNINGS=ignore MPLBACKEND=Agg render \
    --scene lightbox -of "$OUTPUT_DIR_BIDS_QC/${BASENAME}_snapshot_lightbox_fa_sagittal.png" \
    -sz 2400 1200 -vl 28 38 35 -hc -hl -zx x \
    -zr 0 1 \
    "$FA" -ot volume -cm greyscale \
    -dr 0 1



# md lightbox
PYTHONWARNINGS=ignore MPLBACKEND=Agg render \
    --scene lightbox -of "$OUTPUT_DIR_BIDS_QC/${BASENAME}_snapshot_lightbox_md_axial.png" \
    -sz 2400 1200 -vl 28 38 35 -hc -hl -zx z \
    -zr 0 1 \
    "$MD" -ot volume -cm greyscale \
    -dr 0 0.003

PYTHONWARNINGS=ignore MPLBACKEND=Agg render \
    --scene lightbox -of "$OUTPUT_DIR_BIDS_QC/${BASENAME}_snapshot_lightbox_md_coronal.png" \
    -sz 2400 1200 -vl 28 38 35 -hc -hl -zx y \
    -zr 0 1 \
    "$MD" -ot volume -cm greyscale \
    -dr 0 0.003

PYTHONWARNINGS=ignore MPLBACKEND=Agg render \
    --scene lightbox -of "$OUTPUT_DIR_BIDS_QC/${BASENAME}_snapshot_lightbox_md_sagittal.png" \
    -sz 2400 1200 -vl 28 38 35 -hc -hl -zx x \
    -zr 0 1 \
    "$MD" -ot volume -cm greyscale \
    -dr 0 0.003



# vec lightbox
PYTHONWARNINGS=ignore MPLBACKEND=Agg render \
    --scene lightbox -of "$OUTPUT_DIR_BIDS_QC/${BASENAME}_snapshot_lightbox_vec_axial.png" \
    -sz 2400 1200 -vl 28 38 35 -hc -hl -zx z \
    -zr 0 1 \
    "$VEC" -ot rgbvector \
    -b 60 -c 70 

PYTHONWARNINGS=ignore MPLBACKEND=Agg render \
    --scene lightbox -of "$OUTPUT_DIR_BIDS_QC/${BASENAME}_snapshot_lightbox_vec_coronal.png" \
    -sz 2400 1200 -vl 28 38 35 -hc -hl -zx y \
    -zr 0 1 \
    "$VEC" -ot rgbvector \
    -b 60 -c 70 

PYTHONWARNINGS=ignore MPLBACKEND=Agg render \
    --scene lightbox -of "$OUTPUT_DIR_BIDS_QC/${BASENAME}_snapshot_lightbox_vec_sagittal.png" \
    -sz 2400 1200 -vl 28 38 35 -hc -hl -zx x \
    -zr 0 1 \
    "$VEC" -ot rgbvector \
    -b 60 -c 70 
