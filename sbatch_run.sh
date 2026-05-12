#!/bin/bash
#SBATCH -J marsfet
#SBATCH -p batch
#SBATCH --ntasks-per-node=1
#SBATCH --mem=50GB 
#SBATCH -t 150:00:00
#SBATCH -N 1
#SBATCH -o ./logs/%j.out
#SBATCH -e ./logs/%j.err

mkdir -p ./logs

# Activate Conda environment
eval "$(conda shell.bash hook)"
conda activate /envau/work/meca/users/cazzolla.m/conda_envs/eddy3

# Cases to process
LIST="/envau/work/meca/users/cazzolla.m/Marsfet_Diffusion/utils/Marsfet_diffusion_control.csv"

# read csv
mapfile -t LINES < <(tail -n +2 "$LIST")  # Skip header

for LINE in "${LINES[@]}"; do
    SUBJECT_ID=$(echo "$LINE" | cut -d',' -f1)
    SESSION_ID=$(echo "$LINE" | cut -d',' -f2)
    RUN_ID=$(echo "$LINE" | cut -d',' -f3)

    bash ./00_run_pipeline.sh ${SUBJECT_ID} ${SESSION_ID} ${RUN_ID}
done
