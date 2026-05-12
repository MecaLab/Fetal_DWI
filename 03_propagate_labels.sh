source config/config.sh

# define the parcellations to map
PARCELLATIONS=(
    "bounti_symmetrical"
    "bounti"
    "harvard_cortical"
    "harvard_regional"
    "harvard_tissue"
    "neonatal_regional"
    "neonatal_WM"
)

# original space (will do chain of transformations)
ATLAS_T2W=${ATLAS_DIR}/structural/t2-t${GW}.00.nii.gz
SUBJECT_DWI="$OUTPUT_DIR_TMP/${BASENAME}_final_b1000_masked.nii.gz"

for PARCEL in "${PARCELLATIONS[@]}"; do
    ATLAS_PARCEL=${ATLAS_DIR}/extended_parcellations/${PARCEL}-t${GW}.00_dhcp-19.nii.gz

    echo "Propagating ${PARCEL}"

    PROPAGATED_PARCEL="$OUTPUT_DIR_BIDS_PARCELLATIONS/${BASENAME}_${PARCEL}_from_T2w.nii.gz"
    antsApplyTransforms \
        --verbose 0 \
        --dimensionality 3 \
        --input "${ATLAS_PARCEL}" \
        --reference-image "${SUBJECT_DWI}" \
        --output "${PROPAGATED_PARCEL}" \
        --interpolation GenericLabel \
        --transform "$OUTPUT_DIR_TMP/${BASENAME}_WarpedAtlas_to_DWI_1Warp.nii.gz" \
        --transform "$OUTPUT_DIR_TMP/${BASENAME}_WarpedAtlas_to_DWI_6dof.txt" \
        --transform "$OUTPUT_DIR_TMP/${BASENAME}_Atlas_to_T2_1Warp.nii.gz" \
        --transform "$OUTPUT_DIR_TMP/${BASENAME}_Atlas_to_T2_12dof.txt"


    PROPAGATED_PARCEL="$OUTPUT_DIR_BIDS_PARCELLATIONS/${BASENAME}_${PARCEL}_from_ATLAS.nii.gz"
    antsApplyTransforms \
        --verbose 0 \
        --dimensionality 3 \
        --input "${ATLAS_PARCEL}" \
        --reference-image "${SUBJECT_DWI}" \
        --output "${PROPAGATED_PARCEL}" \
        --interpolation GenericLabel \
        --transform "$OUTPUT_DIR_TMP/${BASENAME}_Atlas_to_B1000_1Warp.nii.gz" \
        --transform "$OUTPUT_DIR_TMP/${BASENAME}_Atlas_to_B1000_12dof.txt" \

done



