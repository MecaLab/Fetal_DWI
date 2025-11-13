#!/usr/bin/env python3
"""
QC Metrics Extraction Script

Computes SNR, motion, SSIM, and other QC metrics for DWI data,
and saves them to a JSON file.
"""

import os
import sys
import json
import numpy as np
import pandas as pd
import nibabel as nib
from skimage.metrics import structural_similarity as ssim


# ----------------------------
# Utility Functions
# ----------------------------

def get_nonzero_bval_indices(bvals_path):
    """Return indices of non-zero b-values from a .bval file."""
    with open(bvals_path, "r") as f:
        bvals = list(map(int, f.read().strip().split()))
    return [i for i, b in enumerate(bvals) if b != 0]


def compute_snr(b0, b1000, noise, mask):
    """Compute raw SNR for b0 and b1000 images inside the brain mask."""
    mask_data = mask.get_fdata() > 0

    b0_mean = np.mean(b0.get_fdata()[mask_data])
    b1000_mean = np.mean(b1000.get_fdata()[mask_data])
    noise_mean = np.mean(noise.get_fdata()[mask_data])

    return b0_mean / noise_mean, b1000_mean / noise_mean


def compute_rotation(movements_file):
    """Compute mean overall rotation in degrees."""
    df = pd.read_csv(movements_file, sep=r"\s+", header=None)
    df["sqrt"] = np.sqrt(df[3] ** 2 + df[4] ** 2 + df[5] ** 2)
    return float(round(df["sqrt"].mean() * 180 / np.pi, 2))


def compute_ssim(dwi_path, bvals_path, mask_path):
    """Compute mean SSIM across slices and non-zero b-value volumes."""
    vol = nib.load(dwi_path).get_fdata()
    mask = nib.load(mask_path).get_fdata().astype(bool)
    idxs = get_nonzero_bval_indices(bvals_path)

    if len(idxs) < 2:
        return np.nan

    ref_idx, target_idxs = idxs[0], idxs[1:]
    num_slices = vol.shape[2]
    ssim_scores = []

    for tgt_idx in target_idxs:
        for z in range(num_slices):
            mask_slice = mask[:, :, z]
            if np.count_nonzero(mask_slice) < 10:
                continue

            ref_slice = vol[:, :, z, ref_idx]
            tgt_slice = vol[:, :, z, tgt_idx]

            ref_vals = ref_slice[mask_slice]
            data_range = ref_vals.max() - ref_vals.min()
            if data_range == 0:
                continue

            _, ssim_map = ssim(ref_slice, tgt_slice, full=True, data_range=data_range)
            ssim_scores.append(ssim_map[mask_slice].mean())

    return float(np.mean(ssim_scores)) if ssim_scores else np.nan


# ----------------------------
# Main Script
# ----------------------------

def main():
    # --- Arguments ---
    derivative_folder, subject, session, series = sys.argv[1:5]
    print("Processing:", subject, session, series)

    # --- Paths ---
    initial_qc = "/envau/work/meca/users/cazzolla.m/Marsfet_V2/derivatives/initial_QC/"
    series_path = os.path.join(initial_qc, subject, session, series)

    processing = os.path.join(derivative_folder, subject, session, series, "02_preprocessed_data")
    data_folder = os.path.join(derivative_folder, subject, session, series, "01_prepared_data")

    # --- Load Images ---
    b0 = nib.load(os.path.join(series_path, "b0.nii.gz"))
    b1000 = nib.load(os.path.join(series_path, "b1000.nii.gz"))
    noise = nib.load(os.path.join(processing, "noise.nii.gz"))
    mask = nib.load(os.path.join(processing, "original_brain_mask.nii.gz"))

    # --- Compute Metrics ---
    snr_b0, snr_b1000 = compute_snr(b0, b1000, noise, mask)
    rotation = compute_rotation(os.path.join(processing, "dwi_eddycorr.eddy_movement_over_time"))
    ssim_value = compute_ssim(
        os.path.join(processing, "dwi_eddycorr.nii.gz"),
        os.path.join(data_folder, "dwi.bval"),
        os.path.join(processing, "brain_mask.nii.gz"),
    )

    # --- Eddy QC Data ---
    with open(os.path.join(processing, "dwi_eddycorr.qc/qc.json")) as f:
        eddy_data = json.load(f)

    cnr = eddy_data["qc_cnr_avg"][1]
    translation = eddy_data["qc_mot_abs"]
    outliers = round(eddy_data["qc_outliers_tot"], 2)

    # --- Save QC JSON ---
    qc_folder = os.path.join(derivative_folder, subject, session, series, "99_QC")
    os.makedirs(qc_folder, exist_ok=True)

    output_file = os.path.join(qc_folder, "qc_metrics.json")
    qc_dict = {
        "ID": f"{subject}_{session}_{series}",
        "raw_snr_b0": round(snr_b0, 2),
        "raw_snr_b1000": round(snr_b1000, 2),
        "cnr": round(cnr, 2),
        "translation": round(translation, 2),
        "rotation": rotation,
        "outliers_perc": outliers,
        "SSIM": round(ssim_value, 3),
    }

    with open(output_file, "w") as f:
        json.dump(qc_dict, f, indent=4)

    print("QC metrics saved to:", output_file)


if __name__ == "__main__":
    main()
