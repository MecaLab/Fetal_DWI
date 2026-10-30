#!/bin/bash
 
#SBATCH --partition=bch-gpu                                # queue to be used
#SBATCH --time=150:00:00                         # Running time (in hours-minutes-seconds)
#SBATCH --job-name=meca                      # Job name
#SBATCH --mail-type=BEGIN,END,FAIL              # send and email when the job begins, ends or fails
#SBATCH --mail-user=clemente.velasco-annis@childrens.harvard.edu          # Email address to send the job status
#SBATCH --output=slurmlogs/output_%j.txt                  # Name of the output file
#SBATCH --nodes=1                              # Number of compute nodes
#SBATCH --ntasks=16                             # Number of cpu cores on one node
#SBATCH --gpus=1
#SBATCH --mem=50G

# Activate Conda environment
eval "$(conda shell.bash hook)"
conda activate FetalDiffusion

bash ./00_run_pipeline.sh ${1} ${2} ${3}
