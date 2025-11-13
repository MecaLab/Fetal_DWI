import pandas as pd
import nibabel as nib
import numpy as np
import os
import sys
import re
import matplotlib.pyplot as plt


derivative_folder = sys.argv[1] # folder of series
subject = sys.argv[2]  
session = sys.argv[3]
series = sys.argv[4]

processing_folder = os.path.join(derivative_folder, subject, session, series, '02_preprocessed_data')

# Load outlier info with mean std deviation
outlier_report = os.path.join(processing_folder, "dwi_eddycorr.eddy_outlier_report")

outliers = []
with open(outlier_report, 'r') as f:
    for line in f:
        match = re.search(
            r"Slice (\d+) in scan (\d+) is an outlier with mean ([\-\d\.]+) standard deviations off",
            line)
        if match:
            slice_idx = int(match.group(1))
            scan_idx = int(match.group(2))
            mean_dev = float(match.group(3))
            outliers.append((slice_idx, scan_idx, mean_dev))

# Sort by absolute value of mean deviation (descending)
outliers.sort(key=lambda x: abs(x[2]), reverse=True)

nifti_pre = os.path.join(processing_folder, "dwi_biascorr.nii.gz")
nifti_post = os.path.join(processing_folder, "dwi_eddycorr.nii.gz")

pre_data = nib.load(nifti_pre).get_fdata()
post_data = nib.load(nifti_post).get_fdata()

# Plot in grid: 4 columns (before/after pairs), i.e., 2 outliers per row
n = len(outliers)
cols = 4  # 2 outliers x (before/after)
rows = int(np.ceil(n / 2))

fig, axes = plt.subplots(rows, cols, figsize=(16, 4 * rows))
axes = axes.reshape(-1, cols)

for i, (slice_idx, scan_idx, mean_dev) in enumerate(outliers):
    row = i // 2
    col_offset = (i % 2) * 2

    pre_slice = pre_data[:, :, slice_idx, scan_idx]
    post_slice = post_data[:, :, slice_idx, scan_idx]

    ax_pre = axes[row, col_offset]
    ax_post = axes[row, col_offset + 1]

    ax_pre.imshow(pre_slice.T, cmap='gray', origin='lower')
    ax_pre.set_title(f"Before\nScan {scan_idx}, Slice {slice_idx}\nMean: {mean_dev:.2f}")
    ax_pre.axis('off')

    ax_post.imshow(post_slice.T, cmap='gray', origin='lower')
    ax_post.set_title("After Correction")
    ax_post.axis('off')

# Hide any unused axes
for j in range(i + 1, rows * 2):
    row = j // 2
    col_offset = (j % 2) * 2
    axes[row, col_offset].axis('off')
    axes[row, col_offset + 1].axis('off')

plt.tight_layout()

output_path = os.path.join(derivative_folder, subject, session, series,  '99_QC', 'outliers_plot.png')
plt.savefig(output_path)