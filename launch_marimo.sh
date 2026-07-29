#!/bin/bash

#SBATCH --export=NONE
#SBATCH --job-name=launch_marimo
#SBATCH --time=2-00:00:00
#SBATCH --ntasks-per-node=1
#SBATCH --cpus-per-task=25
#SBATCH --mem=200GB
#SBATCH --output=/scratch/group/genomic_predict/SNP_Calling/TXBM21-26/TASSEL_Workflow_Outputs/logs/%x.%j.out
#SBATCH --error=/scratch/group/genomic_predict/SNP_Calling/TXBM21-26/TASSEL_Workflow_Outputs/logs/%x.%j.err
#SBATCH --account=132740983163

# ── Configuration ─────────────────────────────────────────────────────────────
WORK_DIR="${WORK}/TXBM21-26/SNP_Pypeline"
MARIMO_PORT=2718   # change if this port is taken

# ── Environment ───────────────────────────────────────────────────────────────
module load uv/0.11.1

# ── Print tunnel instructions ──────────────────────────────────────────────────
NODE=$(hostname -s)
echo "================================================================"
echo "  Marimo is starting on: ${NODE}:${MARIMO_PORT}"
echo ""
echo "  On your LOCAL machine, open a NEW terminal and run:"
echo "    ssh -L ${MARIMO_PORT}:${NODE}:${MARIMO_PORT} luke.whiteley@grace.hprc.tamu.edu"
echo ""
echo "  Then open in your browser:"
echo "    http://localhost:${MARIMO_PORT}"
echo "================================================================"

# ── Launch marimo ─────────────────────────────────────────────────────────────
cd "${WORK_DIR}"
uv run marimo edit \
    --host 0.0.0.0 \
    --port "${MARIMO_PORT}" \
    --no-token
