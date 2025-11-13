module purge
module load all
module load ANTS mrtrix singularity

FSLDIR=/home/cazzolla.m/fsl
PATH=${FSLDIR}/share/fsl/bin:${PATH}
export FSLDIR PATH
. ${FSLDIR}/etc/fslconf/fsl.sh
export PATH="/home/cazzolla.m/share/fsl/bin:${PATH}"

eval "$(conda shell.bash hook)"
conda activate /envau/work/meca/users/cazzolla.m/conda_envs/eddy3

ROOT_DIR="/envau/work/meca/users/cazzolla.m/Marsfet_V2/rawdata/"

# These are now passed as arguments instead of being hardcoded
if [ "$#" -ne 3 ]; then
    echo "Usage: $0 <SUBJECT_ID> <SESSION_ID> <SERIE_ID>"
    exit 1
fi

SUBJECT_ID="$1"
SESSION_ID="$2"
SERIE_ID="$3"

export ROOT_DIR
export SUBJECT_ID SERIE_ID SESSION_ID
export DERIVATIVES_DIR="/envau/work/meca/users/cazzolla.m/Marsfet_V2/derivatives/eddy/${SUBJECT_ID}/${SESSION_ID}/${SERIE_ID}"
export TOOLS_DIR="./tools"
export SCRIPTS_DIR="./scripts"


echo "========================================="
echo "🚀 STARTING FETAL DWI PIPELINE"
echo "========================================="
echo "Subject: ${SUBJECT_ID}"
echo "Session: ${SESSION_ID}"
echo "Derivatives will be saved in: ${DERIVATIVES_DIR}"
echo "-----------------------------------------"

echo "STEP 1: Preparing and organizing data..."
bash ./01_prepare_data.sh
echo "✅ STEP 1 complete."
echo "-----------------------------------------"

echo "STEP 2: Preprocessing data..."
bash ./02_preprocessing.sh
echo "✅ STEP 2 complete."
echo "-----------------------------------------"

echo "STEP 3: Registering atlas..."
bash ./03_registration.sh
echo "✅ STEP 3 complete."
echo "-----------------------------------------"

echo "STEP 4: Fitting tensor..."
bash ./04_tensor_fitting.sh
echo "✅ STEP 4 complete."
echo "-----------------------------------------"

module purge
module load all
module load FSL

echo "STEP 5: QC metrics..."
bash ./99_qc.sh
echo "✅ STEP 5 complete."
echo "-----------------------------------------"

echo "========================================="
echo "🎉 PIPELINE FINISHED SUCCESSFULLY!"
echo "========================================="