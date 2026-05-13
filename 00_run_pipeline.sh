source config/config.sh

module purge
module load all
module load ANTS/0.2.6.4
module load mrtrix/3.0.8
module load singularity
module load FSL/0.6.0.7.18

eval "$(conda shell.bash hook)"
conda activate FetalDiffusion

if [ "$#" -ne 3 ]; then
    echo "Usage: $0 <SUBJECT_ID> <SESSION_ID> <RUN_ID>"
    exit 1
fi

SUBJECT_ID="$1"
SESSION_ID="$2"
RUN_ID="$3"

export BASENAME="${SUBJECT_ID}_${SESSION_ID}_${RUN_ID}"
export SUBJECT_ID SESSION_ID RUN_ID

export OUTPUT_DIR_BIDS_DWI="${DERIVATIVES_DIR}/output/${SUBJECT_ID}/${SESSION_ID}/dwi"
export OUTPUT_DIR_BIDS_XFM="${DERIVATIVES_DIR}/output/${SUBJECT_ID}/${SESSION_ID}/xfm"
export OUTPUT_DIR_BIDS_QC="${DERIVATIVES_DIR}/output/${SUBJECT_ID}/${SESSION_ID}/qc"
export OUTPUT_DIR_BIDS_PARCELLATIONS="${DERIVATIVES_DIR}/output/${SUBJECT_ID}/${SESSION_ID}/parcellations"
export OUTPUT_DIR_BIDS_TENSOR="${DERIVATIVES_DIR}/output/${SUBJECT_ID}/${SESSION_ID}/tensor"


export OUTPUT_DIR_TMP=$INTERMEDIATE_DIR/${SUBJECT_ID}/${SESSION_ID}
mkdir -p ${OUTPUT_DIR_TMP}
mkdir -p ${OUTPUT_DIR_BIDS_DWI}
mkdir -p ${OUTPUT_DIR_BIDS_XFM}
mkdir -p ${OUTPUT_DIR_BIDS_QC}
mkdir -p ${OUTPUT_DIR_BIDS_PARCELLATIONS}
mkdir -p ${OUTPUT_DIR_BIDS_TENSOR}


export GW=$(python3 ./scripts/get_GW.py ${SUBJECT_ID} ${SESSION_ID})

echo "========================================="
echo "STARTING FETAL DWI PIPELINE"
echo "========================================="
echo "Subject: ${SUBJECT_ID}"
echo "Session: ${SESSION_ID}"
echo "Run: ${RUN_ID}"
echo "Gestational Week (GW): ${GW}"
echo "-----------------------------------------"

skip_already_processed=true

# skip if already processed
if [ -f "$OUTPUT_DIR_BIDS_QC/${BASENAME}_refspace_MD.nii.gz" ] && [ "$skip_already_processed" = true ]; then
    echo "✅ Subject ${BASENAME} already processed. Skipping..."
    exit 0
fi

echo "STEP 1: Preprocessing data..."
bash ./01_preprocessing.sh
echo "✅ STEP 1 complete."
echo "-----------------------------------------"

echo "STEP 2a: Registration T2w..."
bash ./02a_registration_T2w.sh
echo "✅ STEP 2a complete."
echo "-----------------------------------------"

echo "STEP 2a: Registration Atlas..."
bash ./02b_registration_atlas.sh
echo "✅ STEP 2b complete."
echo "-----------------------------------------"

echo "STEP 3: Propagating labels..."
bash ./03_propagate_labels.sh
echo "✅ STEP 3 complete."
echo "-----------------------------------------"

echo "STEP 4: Fitting tensor..."
bash ./04_fit_tensor.sh
echo "✅ STEP 4 complete."
echo "-----------------------------------------"

module purge
module load all
module load FSL

echo "STEP 5: QC snapshots..."
bash ./99_qc.sh
echo "✅ STEP 5 complete."
echo "-----------------------------------------"

echo "========================================="
echo "🎉 PIPELINE FINISHED SUCCESSFULLY!"
echo "========================================="
