#!/bin/bash
# =============================================================================
# Git Setup for TXBM21-26 (Local)
# Run this script from the local project root:
#   cd /home/lgw/TAMU/TXBM21-26
#   bash setup_git.sh
#
# Workflow: Local (edit) → GitHub (sync) → Grace HPRC (run jobs)
# After running this script, push to GitHub and clone on Grace.
# =============================================================================

set -euo pipefail

PROJECT_ROOT="/home/lgw/TAMU/TXBM21-26"

echo "=== Setting up TXBM21-26 project structure ==="

# -----------------------------------------------------------------------------
# Phase 1: Directory Structure
# -----------------------------------------------------------------------------
echo "Creating directory structure..."

mkdir -p "$PROJECT_ROOT"/{Scripts/{1_Preprocessing,2_SNPCalling,3_Filtering,4_Imputation},Config,Logs,GBS_Metadata,Data/{FASTQ,VCF,H5},Results}

# -----------------------------------------------------------------------------
# Phase 2: Git Initialization
# -----------------------------------------------------------------------------
cd "$PROJECT_ROOT"

if [ -d ".git" ]; then
    echo "Git repository already initialized."
else
    echo "Initializing git repository..."
    git init
fi

# Configure git identity
git config user.name "Logan Wilson"
git config user.email "loganwilson@tamu.edu"

# Set default branch name
git config init.defaultBranch main

# -----------------------------------------------------------------------------
# Create .gitignore
# -----------------------------------------------------------------------------
echo "Creating .gitignore..."

cat > .gitignore << 'EOF'
# =============================================================================
# TXBM21-26 .gitignore
# =============================================================================

# ----- Large Data Files (never track) -----
*.fastq
*.fastq.gz
*.fq
*.fq.gz
*.bam
*.bam.bai
*.sam
*.vcf
*.vcf.gz
*.vcf.gz.csi
*.vcf.gz.tbi
*.bcf
*.h5
*.hdf5

# ----- Data Directories -----
Data/
Results/
PolyA_FASTQ/

# ----- SLURM Job Outputs -----
*.stdout
*.stderr
slurm-*.out
*.out.[0-9]*
*.err.[0-9]*

# ----- Python -----
__pycache__/Loga
*.py[cod]
*$py.class
.venv/
venv/
*.egg-info/

# ----- OS/Editor -----
.DS_Store
._.DS_Store
*.swp
*.swo
*~
.vscode/

# ----- Temporary/Intermediate Files -----
*.tmp
*.temp
*.log
EOF

# -----------------------------------------------------------------------------
# Create config.env template
# -----------------------------------------------------------------------------
echo "Creating Config/config.env..."

cat > Config/config.env << 'EOF'
#!/bin/bash
# =============================================================================
# TXBM21-26 Configuration (Grace HPRC paths)
# Source this file at the top of all scripts on Grace:
#   source "${PROJECT_ROOT}/Config/config.env"
# =============================================================================

# ----- Grace HPRC Paths -----
export PROJECT_ROOT="/scratch/group/genomic_predict/SNP_Calling/TXBM21-26"
export DATA_ROOT="/scratch/group/genomic_predict/Data"
export REF_GENOME="${DATA_ROOT}/Reference_Genomes/iwgsc_refseqv2.1_assembly.fa"
export FASTQ_DIR="${DATA_ROOT}/PolyA_FASTQ"
export KEY_FILE="${PROJECT_ROOT}/GBS_Metadata/TXBM21-26_KEY.txt"
export LINES_FILE="${PROJECT_ROOT}/GBS_Metadata/TXBM21-26_LINES.txt"

# ----- TASSEL -----
export TASSEL_HOME="/scratch/group/genomic_predict/Software/tassel-5-standalone"
export TASSEL_PL="${TASSEL_HOME}/run_pipeline.pl"

# ----- Log Directory (auto-created by date) -----
export LOG_DIR="${PROJECT_ROOT}/Logs/$(date +%Y-%m-%d)"
mkdir -p "$LOG_DIR"

# ----- Helper function for job output redirection -----
# Usage in SLURM script:
#   #SBATCH --output=${LOG_DIR}/%x.%j.out
#   #SBATCH --error=${LOG_DIR}/%x.%j.err
EOF

# -----------------------------------------------------------------------------
# Create params.yaml template
# -----------------------------------------------------------------------------
echo "Creating Config/params.yaml..."

cat > Config/params.yaml << 'EOF'
# =============================================================================
# TXBM21-26 SNP Calling Parameters
# =============================================================================

snp_calling:
  # Minimum locus coverage (MLC) - minimum reads per locus
  min_locus_coverage: 30
  
  # Minor allele frequency (MAF) threshold
  min_allele_freq: 0.04
  
  # Maximum heterozygosity
  max_het: 0.15

filtering:
  # Genotype missingness threshold (0.05 = 5% missing allowed)
  geno_miss: 0.05
  
  # Sample missingness threshold
  sample_miss: 0.20

imputation:
  # Beagle parameters
  window: 40
  overlap: 4
  ne: 10000
EOF

# -----------------------------------------------------------------------------
# Create placeholder README
# -----------------------------------------------------------------------------
echo "Creating README.md..."

cat > README.md << 'EOF'
# TXBM21-26 SNP Calling Pipeline

## Directory Structure

```
TXBM21-26/
├── Scripts/           # All pipeline scripts (version controlled)
│   ├── 1_Preprocessing/
│   ├── 2_SNPCalling/
│   ├── 3_Filtering/
│   └── 4_Imputation/
├── Config/            # Configuration files (version controlled)
│   ├── config.env     # Path variables - source in all scripts
│   └── params.yaml    # Run parameters
├── Logs/              # SLURM job outputs (gitignored, organized by date)
├── GBS_Metadata/      # Key and lines files (version controlled)
├── Data/              # Raw/intermediate data (gitignored)
└── Results/           # Final outputs (gitignored)
```

## Quick Start

1. Source the config in your scripts:
   ```bash
   source "${PROJECT_ROOT}/Config/config.env"
   ```

2. Run jobs with output redirection:
   ```bash
   #SBATCH --output=${LOG_DIR}/%x.%j.out
   #SBATCH --error=${LOG_DIR}/%x.%j.err
   ```

## Data Locations (not in git)

- FASTQ files: `Data/FASTQ/`
- VCF outputs: `Data/VCF/`
- Final genotypes: `Results/`
EOF

# -----------------------------------------------------------------------------
# Initial Commit
# -----------------------------------------------------------------------------
echo "Creating initial commit..."

git add .gitignore Config/ README.md Scripts/ GBS_Metadata/ 2>/dev/null || git add .gitignore Config/ README.md
git commit -m "Initial project setup: directory structure, config templates, gitignore"

echo ""
echo "=== Local setup complete! ==="
echo "Project root: $PROJECT_ROOT"
echo ""
echo "Next steps:"
echo "  1. Create a GitHub repo (e.g. github.com/new → TXBM21-26)"
echo "  2. Add the remote and push:"
echo "       git remote add origin https://github.com/<your-username>/TXBM21-26.git"
echo "       git push -u origin main"
echo "  3. On Grace, clone the repo:"
echo "       cd /scratch/group/genomic_predict/SNP_Calling"
echo "       git clone https://github.com/<your-username>/TXBM21-26.git"
echo "  4. Review Config/config.env — paths are set for Grace HPRC"
echo "  5. Copy key/lines files to GBS_Metadata/ and commit"
