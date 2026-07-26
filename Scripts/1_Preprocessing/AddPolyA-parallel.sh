#!/bin/bash

#SBATCH --export=NONE
#SBATCH --job-name=PolyA_TXBM21-26
#SBATCH --time=15:00:00
#SBATCH --ntasks-per-node=1
#SBATCH --cpus-per-task=5
#SBATCH --mem=8GB
# NOTE: #SBATCH directives cannot expand shell variables — keep these paths in sync with config.env
# On Grace: PROJECT_ROOT=$WORK/TXBM21-26 → update these two lines accordingly
#SBATCH --output=/scratch/group/genomic_predict/SNP_Calling/TXBM21-26/Logs/stdout.%x.%j
#SBATCH --error=/scratch/group/genomic_predict/SNP_Calling/TXBM21-26/Logs/stderr.%x.%j
#SBATCH --account=132740983163
#SBATCH --mail-user=luke.whiteley@ag.tamu.edu
#SBATCH --mail-type=all

# ***Refactored on 07/25/2026 — aligned with organization_plan.md + tasselWorkflowRefactor.md***
# ***Used Claude Sonnet 4.6***
# Changes from AddPolyA-parallel.sh (prev version):
#   - Paths sourced from config.env instead of hardcoded
#   - Log directory uses dated subdirectory (Logs/YYYY-MM-DD/)
#   - No hardcoded /scratch paths in script body

# === LOAD PROJECT CONFIG ===
# config.env defines: DATA_ROOT, PROJECT_ROOT
# On Grace: DATA_ROOT=$SCRATCH/..., PROJECT_ROOT=$WORK/TXBM21-26
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CONFIG="${SCRIPT_DIR}/../../config.env"
if [[ ! -f "${CONFIG}" ]]; then
    echo "ERROR: config.env not found at ${CONFIG}" >&2
    echo "       Create it from config.env.template before submitting this job." >&2
    exit 1
fi
source "${CONFIG}"
# === END CONFIG ===

# Derived paths (computed from config.env variables)
RAW_GENO="${DATA_ROOT}/Raw_genomic_data/Breeding_Lines/FASTQ"
POLYA_GENO="${DATA_ROOT}/PolyA_FASTQ"
LOG_DIR="${PROJECT_ROOT}/Logs/$(date +%Y-%m-%d)"
MAX_JOBS=${SLURM_CPUS_PER_TASK:-5}
POLYA_BASES="AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA"

mkdir -p "${LOG_DIR}" "${POLYA_GENO}"

# --- worker function (runs in a background subshell per file) ---
process_file() {
    local gz_file="$1"
    local base="${gz_file%.gz}"
    local output="${POLYA_GENO}/AAAA-${base}"
    local begin
    begin=$(date +%s)

    if [[ -f "${output}" ]]; then
        echo "SKIPPING ${gz_file} — output already exists: ${output}"
        return 0
    fi

    echo "Processing: ${gz_file} → $(basename "${output}")"

    # decompress and append poly-A in one pipeline (no temp file)
    gzip -dc "${gz_file}" 2>/dev/null \
        | sed "2~4s/\$/${POLYA_BASES}/" \
        > "${output}"

    local finish
    finish=$(date +%s)
    local elapsed=$(( finish - begin ))
    local minutes=$(( elapsed / 60 ))
    local num_reads=$(( $(wc -l < "${output}") / 4 ))

    printf "Done: %-40s | %d min | %'d reads\n" "$(basename "${output}")" "${minutes}" "${num_reads}"
    echo "-----------------------------------------------"
}
export -f process_file
export POLYA_GENO POLYA_BASES

# --- main ---
cd "${RAW_GENO}"

echo "========================================================="
echo "FASTQ.gz files to process:"
ls -lag *.fastq.gz
echo "========================================================="
echo "Max parallel jobs: ${MAX_JOBS}"
echo "========================================================="

for gz_file in *.fastq.gz; do
    [[ -f "${gz_file}" ]] || continue

    process_file "${gz_file}" &

    # throttle: block until a slot is free
    while (( $(jobs -r | wc -l) >= MAX_JOBS )); do
        wait -n 2>/dev/null || sleep 0.5
    done
done

# wait for all remaining background jobs
wait

echo "========================================================="
echo "All files processed. PolyA FASTQ files are in: ${POLYA_GENO}"
echo "Runtime logs: ${LOG_DIR}"
echo "SLURM stdout/stderr: see #SBATCH --output/--error paths"
echo "========================================================="
