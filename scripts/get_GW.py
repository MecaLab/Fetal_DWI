import pandas as pd
import sys

# --- Arguments ---
subject = sys.argv[1]  
session = sys.argv[2]  

df = pd.read_csv('tools/2025_09_DWI_patients_clean.csv')

GW = df[(df.marsfet_subject_id == subject) & (df.marsfet_session_id == session)]['GW_rounded'].iloc[0]

# Cap GW at 36
GW_clipped = min(max(GW, 21), 36)
print(round(GW_clipped))
