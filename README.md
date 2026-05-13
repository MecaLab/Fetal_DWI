# Fetal DWI Pipeline

An automated, end-to-end preprocessing and processing pipeline for Fetal Diffusion-Weighted MRI (DWI) data.

## 🚀 Features

- **Preprocessing**: Denoising (MRtrix), N4 bias field correction, and comprehensive FSL Eddy correction (including motion, distortion, and slice-to-volume correction).

- **Brain Extraction**: Automated fetal brain masking using a custom deep-learning model (FetalBET / Attention U-Net).

- **Alignment**: Multi-step non-linear registration (via ANTs) mapping native DWI to the subject's structural T2w image, and to Gestational Week (GW)-matched fetal atlases.

- **Parcellation**: Automatic propagation of cortical and regional labels (e.g., Bounti, Harvard) from template space directly to the subject's native diffusion space.

- **Microstructure**: Tensor fitting (FA, MD, AD, RD, VEC) in both native image space and template space via MRtrix3.

- **Quality Control**: Automated generation of multi-planar lightbox snapshots for rapid visual inspection.

---

## 🛠️ Prerequisites

Before installing the Python dependencies, ensure you have the following software installed and accessible in your $PATH (or via HPC modules):

- FSL (Tested with v6.0.7.18)

- MRtrix3 (Tested with v3.0.8)

- ANTs (Tested with v0.2.6.4)

---
## ⚙️ Installation

### 1. Clone the repository
```
git clone https://github.com/MecaLab/Fetal_DWI.git
cd Fetal_DWI
```

## 2. Add FetalBET and External Tools

This pipeline requires external scripts and model weights for FetalBET ([brain extraction](https://github.com/bchimagine/fetal-brain-extractio)), as well as the c3d_affine_tool. You must manually obtain these files and place them into the tools/ directory so the structure looks exactly like this:

```
tools/
├── AttUNet.pth         # Pre-trained FetalBET model weights
├── c3d_affine_tool     # Executable for matrix conversion
└── inference.py        # FetalBET execution script
```

## 3. Set up the Python Environment

All required Python packages for deep learning inference, masking, and calculations must be installed.
```
conda create -n FetalDiffusion python=3.12
conda activate FetalDiffusion
pip install -r requirements.txt
```

Can now install pytorch:
```
pip3 install torch torchvision --index-url https://download.pytorch.org/whl/cpu
```

## 📂 Configuration


Before running, update ```config/config.sh``` to match your directory structure and hardware limits. By default, it points to specific cluster paths:

```bash
# config/config.sh variables
export MARSFET_BIDS_DIR="/path/to/your/bids_dataset"
export ATLAS_DIR="/path/to/dhcp_fetal_atlas"
export T2W_DIR="/path/to/your/t2w_derivatives"
```

## 🏃 Usage
### Running Locally / Interactive Node

To run the pipeline on a single subject, session, and run, execute the master script with the three required arguments:
```bash
bash 00_run_pipeline.sh <SUBJECT_ID> <SESSION_ID> <RUN_ID>

# Example:
bash 00_run_pipeline.sh sub-01 ses-01 run-01
```


### Running Batch on a SLURM Cluster

An example SLURM submission script is provided (sbatch_run.sh). It reads from a CSV file (formatted as Subject,Session,Run).

```bash
sbatch sbatch_run.sh
```

## Run Specific Steps

If a step fails or you want to skip certain parts of the pipeline (e.g., skipping preprocessing if it is already done), you need to comment out the respective execution lines in 00_run_pipeline.sh:
```bash
# Example: skip preprocessing

#echo "STEP 1: Preprocessing data..."
#bash ./01_preprocessing.sh
#echo "✅ STEP 1 complete."
#echo "-----------------------------------------"

echo "STEP 2a: Registration T2w..."
bash ./02a_registration_T2w.sh
echo "✅ STEP 2a complete."
echo "-----------------------------------------"

echo "STEP 2b: Registration Atlas..."
bash ./02b_registration_atlas.sh
echo "✅ STEP 2b complete."
echo "-----------------------------------------"
...
```