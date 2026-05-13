import pandas as pd
import sys

# --- Arguments ---
subject = sys.argv[1]  
session = sys.argv[2]  

marsfet_info = ''

df = pd.read_csv('/envau/work/meca/data/Fetus/datasets/Marsfet_Diffusion/Marsfet_diffusion_info.csv')
GW = df[(df.Subject == subject) & (df.Session == session)]['GW_rounded'].iloc[0]

# Cap GW at 36
GW_clipped = min(max(GW, 21), 36)
print(round(GW_clipped))
