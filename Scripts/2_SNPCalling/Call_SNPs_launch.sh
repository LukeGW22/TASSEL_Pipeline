#!/bin/bash
#===============================================================================
# SLURM Launch Script: TXBM21-26 TASSEL GBS SNP Calling
#
# Submit from Grace:
#   sbatch Call_SNPs_launch.sh
#
# NOTE: TASSEL_Workflow_Outputs/logs/ must exist before submitting.
#   mkdir -p /scratch/group/genomic_predict/SNP_Calling/TXBM21-26/TASSEL_Workflow_Outputs/logs
#===============================================================================

#SBATCH --export=NONE
#SBATCH --job-name=TXBM21-26_Call_SNPs
#SBATCH --time=24:00:00
#SBATCH --ntasks-per-node=1
#SBATCH --cpus-per-task=24
#SBATCH --mem=250GB
#SBATCH --output=/scratch/group/genomic_predict/SNP_Calling/TXBM21-26/TASSEL_Workflow_Outputs/logs/%x.%j.out
#SBATCH --error=/scratch/group/genomic_predict/SNP_Calling/TXBM21-26/TASSEL_Workflow_Outputs/logs/%x.%j.err
#SBATCH --account=132740983644
#SBATCH --mail-user=luke.whiteley@ag.tamu.edu
#SBATCH --mail-type=ALL
# NOTE: SLURM directives above cannot be dynamic. After sourcing config.env,
#       the pipeline script reads all threshold/path variables from there.

#-------------------------------------------------------------------------------
# Environment Setup
#-------------------------------------------------------------------------------

module purge
module load Anaconda3/2024.02-1
module load GCCcore/13.2.0
module load BWA/0.7.18

# Initialize conda and activate TASSEL environment
source "$(conda info --base)/etc/profile.d/conda.sh"
conda activate TASSEL

#-------------------------------------------------------------------------------
# Project Paths (sourced from config.env)
#-------------------------------------------------------------------------------

CONFIG_ENV="$(dirname "$(dirname "$(dirname "$(realpath "$0")")")")/config.env"
if [[ ! -f "${CONFIG_ENV}" ]]; then
    echo "ERROR: config.env not found at ${CONFIG_ENV}"
    echo "       Copy config.env.template → config.env and fill in values."
    exit 1
fi
# shellcheck source=/dev/null
source "${CONFIG_ENV}"

PIPELINE_SCRIPT="${PROJECT_ROOT}/Scripts/2_SNPCalling/TXBM21-26_TASSEL_GBS_Pipeline.sh"

#-------------------------------------------------------------------------------
# Run Pipeline
#-------------------------------------------------------------------------------

cd "${PROJECT_ROOT}"

echo "Job started: $(date)"
echo "Node: $(hostname)"
echo "Running pipeline: ${PIPELINE_SCRIPT}"

bash "${PIPELINE_SCRIPT}"

echo "Job finished: $(date)"
