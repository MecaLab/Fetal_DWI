import sys
import os
import pandas as pd

# --- Arguments ---
derivative_folder = sys.argv[1]  

rows = []

for sub in os.listdir(derivative_folder):
    for ses in os.listdir(os.path.join(derivative_folder, sub)):
        for ser in os.listdir(os.path.join(derivative_folder, sub, ses)):
                
            preprocessing = os.path.join(derivative_folder, sub, ses, ser, '02_preprocessed_data/final_b1000_masked.nii.gz')       
            registration = os.path.join(derivative_folder, sub, ses, ser, '03_registration/atlas_non_linear_Image.nii.gz')
            tensor = os.path.join(derivative_folder, sub, ses, ser, '04_tensor/image_fa.nii.gz')
            qc = os.path.join(derivative_folder, sub, ses, ser, '99_QC/snapshot_lightbox_fa_axial.png')

            row = {
                "subject": sub,
                "session": ses,
                "series": ser,
                "preprocessing": "OK" if os.path.exists(preprocessing) else "FAILED",
                "registration": "OK" if os.path.exists(registration) else "FAILED",
                "tensor": "OK" if os.path.exists(tensor) else "FAILED",
                "qc": "OK" if os.path.exists(qc) else "FAILED"
            }

            rows.append(row)


df = pd.DataFrame(rows)
out_file = os.path.join('logs', "processing_status.csv")
df.to_csv(out_file, index=False)

print(f"✅ Saved results to {out_file}")