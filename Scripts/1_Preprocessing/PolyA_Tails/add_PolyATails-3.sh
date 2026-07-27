#!/bin/bash

#SBATCH --export=NONE
#SBATCH --job-name=PolyA_TXBM21-26
#SBATCH --time=15:00:00
#SBATCH --ntasks-per-node=1
#SBATCH --cpus-per-task=5
#SBATCH --mem=8GB
#SBATCH --output=/scratch/group/genomic_predict/SNP_Calling/TXBM21-26/Logs/SNPCalling_logs/stdout.%x.%j
#SBATCH --error=/scratch/group/genomic_predict/SNP_Calling/TXBM21-26/Logs/SNPCalling_logs/stderr.%x.%j
#SBATCH --account=132740983163
#SBATCH --mail-user=luke.whiteley@ag.tamu.edu
#SBATCH --mail-type=all

# ***Refactored from add_PolyATails-2.sh on 07/23/2026***
# ***Used Claude Sonnet 4.6***

# === SETUP ===
ROOT=/scratch/group/genomic_predict/SNP_Calling
LOG_DIR="${ROOT}/TXBM21-26/Logs/SNPCalling_logs"
RAW_GENO="${ROOT}/Raw_genomic_data/Breeding_Lines/FASTQ"
POLYA_GENO="${ROOT}/PolyA_FASTQ"
POLYA_ADDER="${ROOT}/TXBM21-26/Scripts/1_SNPCalling/AddPolyA-new.sh"
# === END SETUP ===

# ensure log directory exists before SLURM tries to write to it
mkdir -p "${LOG_DIR}"

cd "${RAW_GENO}"

# list FASTQs that script will work on
echo "************************************** FASTQ.gz files to use:"
ls -lag *.fastq.gz
echo "========================================================="

# unzip then add PolyA tails
for file in *.fastq.gz; do
if [[ -f $file ]]; then

    # derive expected output filename that AddPolyA-new.sh would produce
    unzipped_file="${file%.gz}"
    expected_output="${POLYA_GENO}/AAAA-${unzipped_file}"

    # skip if already processed
    if [[ -f "${expected_output}" ]]; then
        echo "SKIPPING ${file} — output already exists: ${expected_output}"
        echo "-----------------------------------------------"
        continue
    fi

    # 1) force decompress, suppressing CRC errors
    echo "Unzipping $file..."
    gzip -dc "$file" > "${unzipped_file}" 2>/dev/null

    # 2) run Paul's PolyA script
    echo "Adding PolyA Tails..."
    bash "${POLYA_ADDER}" "$unzipped_file"

    # 3) delete the temporary fastq file
    echo "Removing temporary FASTQ: $unzipped_file"
    rm "$unzipped_file"

    echo "-----------------------------------------------"
fi
done

echo "========================================================="
echo "All Files have had Poly A Tails added."
echo "Logs can be found in: ${LOG_DIR}"
echo "Stdout:" 
echo "${LOG_DIR}/stdout.${SLURM_JOB_NAME}.${SLURM_JOB_ID}"
echo "---------------------------------------------------------"
echo "Stderr:"
echo "${LOG_DIR}/stderr.${SLURM_JOB_NAME}.${SLURM_JOB_ID}"