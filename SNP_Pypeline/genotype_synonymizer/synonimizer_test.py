## TEMPORARY FOR PERFORMANCE EVAL
import time

start_time = time.perf_counter()
# ---
import os
import pandas as pd
from genotype_synonymizer import GenotypeSynonymizer

# number of separators between sections (character width)
CHARWIDTH = 100

## working directory
if os.name == "posix":
    # Configure Mac/Linux machine WD
    WD = os.getcwd().replace('/Scripts/Pre-Processing', '')
else: 
    # Configure Windows machine WD
    WD = os.getcwd().replace('\\Scripts\\Pre-Processing', '')

## input directories  
PHENO_DATA_DIR = os.path.join(WD, 'Data', 'Pheno')
GENO_DATA_DIR = os.path.join(WD, 'Data', 'Geno')

## input files
key_filepath = os.path.join(PHENO_DATA_DIR, 'GenoSynonimizer-KEY.txt')
trial_filepath = os.path.join(PHENO_DATA_DIR, 'Tariq_FinalData_GP.txt')
geno_filepath = os.path.join(GENO_DATA_DIR, 'USE-NUMERIC_TXBM21-25_MLC30_MAF04_IMPUTED.txt')

## import files
key_file = pd.read_csv(key_filepath, sep='\t', encoding='latin-1')
trials = pd.read_csv(trial_filepath, sep='\t', encoding='latin-1')

# Geno Check - Read header only first to see column names
header = pd.read_csv(geno_filepath, sep='\t', skiprows=1, nrows=3, encoding='latin-1')

geno_df = pd.read_table(
    geno_filepath,
    sep=r'\s+',   # any whitespace (spaces or tabs)
    header=1      # skip the "<Numeric>" line, use the next line as header
).rename(columns={'<Marker>':'Genotype'}) 

print("Key File:")
print(key_file.iloc[:5, :3], '\n')

print("MET Df:")
print(trials.columns,'\n')

print("Genotype Data:")
print(geno_df.iloc[:3, :5],'\n')

synonymizer = GenotypeSynonymizer(
    key_df               = key_file,                # Cvar names & aliases
    trial_df             = trials,                  # Phenotype data
    geno_input           = geno_df,                 # SNP matrix (or a plain taxa list[str])
    key_cultivar_col     = "Cultivar_Name",
    key_experimental_col = "Experimental_Name",
    key_preferred_col    = "Preferred_Name",
    trial_id_col         = "Name1",
    geno_id_col          = "Genotype",
)

## check files for genotype naming compliance
synonymizer.check_all_files()

## check for presence across files
presence = synonymizer.check_name_presence()

all_present = presence[
    #(presence['in_key'] == True) &
    (presence['in_trial'] == True) &
    (presence['in_geno_list'] == True)
]

print('='*CHARWIDTH)
print("Names present across all files:")
print(all_present[['preferred_name', 'trial_name_used', 'geno_list_name_used']])

## find matches
matches = synonymizer.find_matches()

## standardize names
### trial df
trial_std = synonymizer.standardize_names(
    df=trials, 
    name_col="Name1",
    new_col="New_Name"
    )

check_trial_std_df = pd.DataFrame({
    'Old_Name': trial_std["Name1"],
    'New_Name': trial_std["New_Name"],
    'Old_New_Match': trial_std['Name1'] == trial_std['New_Name']
    })

# look for rows where the new and old cols dont match, it means they were updated
check_trial_std_df = check_trial_std_df[check_trial_std_df['Old_New_Match'] == False] 
unique_updated_trial_names = check_trial_std_df['Old_Name'].unique()

### genotype df
geno_std = synonymizer.standardize_names(
    df=geno_df, 
    name_col="Genotype",
    new_col="Std_Genotype")

check_geno_std_df = pd.DataFrame({
    'Old_Name': geno_std['Genotype'],
    'New_Name': geno_std['Std_Genotype'],
    'Old_New_Match': geno_std['Genotype'] == geno_std['Std_Genotype']
    })

# look for rows where the new and old cols dont match, it means they were updated
check_geno_std_df = check_geno_std_df[check_geno_std_df['Old_New_Match'] == False] 
unique_updated_geno_names = check_geno_std_df['Old_Name'].unique()

print('='*CHARWIDTH)
print(f"Trial DF: \n\t {len(unique_updated_trial_names)} Unique Old Names Updated.")
print(f"\t {len(check_trial_std_df)} Total Entry Names Updated. \n") 
print(check_trial_std_df[['Old_Name', 'New_Name']].value_counts())

print('='*CHARWIDTH)
print(f"Genotype DF: \n\t {len(unique_updated_geno_names)} Unique Old Names Updated.")
print(f"\t {len(check_geno_std_df)} Total Entry Names Updated. \n") 
print(check_geno_std_df[['Old_Name', 'New_Name']].value_counts())

# save dfs with updated names


# === END SCRIPT ===
print('*'*CHARWIDTH)
end_time = time.perf_counter()
print(f"Execution time: {end_time - start_time:.4f} seconds")
