# --------- Directories Parameters ---------
MARSFET_BIDS_DIR=/envau/work/meca/data/Fetus/datasets/Marsfet_Diffusion/
RAWDATA_DIR=${MARSFET_BIDS_DIR}/rawdata_renamed
DERIVATIVES_DIR=${MARSFET_BIDS_DIR}/derivatives
INTERMEDIATE_DIR=${DERIVATIVES_DIR}/intermediate
SCRIPTS_DIR=scripts

ATLAS_DIR='/envau/work/meca/data/Fetus/datasets/atlas_fetus/fetal_brain_mri_atlas'
T2W_DIR='/envau/work/meca/data/Fetus/datasets/MarsFet_V2/fetpype_output/fetpype_V2_05/results/haste/derivatives/nesvor_bounti_surfpype'

# --------- SOFTWARE ---------
C3D_TOOL_PATH=tools/c3d_affine_tool

# --------- Brain extraction tool ---------
MODEL_PATH="tools/AttUNet.pth"
BET_SCRIPT="tools/inference.py"
MASK_POSTPROCESS_SCRIPT="${SCRIPTS_DIR}/postprocess_mask.py"

# --------- Other Parameters ---------
NTHR=64
