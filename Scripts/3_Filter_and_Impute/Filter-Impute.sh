#!/bin/bash
#SBATCH --job-name=MLC30_MAF04
#SBATCH --time=8:00:00
#SBATCH --ntasks-per-node=1
#SBATCH --cpus-per-task=48
#SBATCH --mem=75GB
#SBATCH --output=stdout.%x.%j
#SBATCH --error=stderr.%x.%j
#SBATCH --account=132740983644
#SBATCH --mail-user=luke.whiteley@ag.tamu.edu
#SBATCH --mail-type=all

# === 1. SET UP ==
# --- BEGIN EDITS ---
## params to run
CALC_MLC=685            ## MLC% x Total # of genos (2283 here)
MAF=0.04

## File names for saving
PARAM_LABEL="MLC30_MAF04"
PREFIX="TXBM21-25_${PARAM_LABEL}"

## Working directory
WD="/scratch/group/genomic_predict/SNP_Calling/GENOPT"

## HD5 (Genomic) database to use
HD5_DB="FAST_TXBM21-25.05geno_miss.h5"

# --- END EDITS ---

## log directory
RUN_DIR="$WD/$PARAM_LABEL"
LOG_OUT="$RUN_DIR/TASSEL_Logs"
SUM_OUT="$RUN_DIR/TASSEL_Summaries"

mkdir -p "$RUN_DIR"
mkdir -p "$LOG_OUT"
mkdir -p "$SUM_OUT"

echo "$RUN_DIR Created!"
echo "------------------------------"

## VCF
VCF_PATH="$RUN_DIR/VCF"
FILT_VCF="$VCF_PATH/${PREFIX}_filtered"
IMP_VCF="$VCF_PATH/${PREFIX}_IMPUTED"
#VCF_OUT="$VCF_PATH/$IMP_VCF"

mkdir -p "$VCF_PATH"

## TASSEL v5 location
TASSEL="/scratch/group/genomic_predict/SNP_Calling/TXBM21-25/Optimization/TASSEL/tassel-5-standalone/run_pipeline.pl"

## location of imputer (BEAGLE)
IMPUTER="$WD/Software/beagle.27Feb25.75f.jar"

## === 2. FILTER w/ TASSEL ===
## load modules
module purge
module load GCC/13.2.0
module load Java/1.8.0_292-OpenJDK

"$TASSEL" -Xmx70g \
    -log "${LOG_OUT}/${PREFIX}.log" \
    -fork1 \
    -h5 "$HD5_DB" \
    -FilterSiteBuilderPlugin \
    -siteMinCount "${CALC_MLC}" \
    -siteMinAlleleFreq "${MAF}" \
    -siteMaxAlleleFreq 1.0 \
    -maxHeterozygous 0.0156 \
    -removeMinorSNPStates true \
    -removeSitesWithIndels true \
    -endPlugin \
    -homozygous \
    -export "$FILT_VCF" \
    -exportType VCF \
    -runfork1

# === 3. IMPUTE w/ BEAGLE ===
## modules for BEAGLE
module purge
module load Java/21.0.2

## impute missing data
java -Xmx70g -jar "$IMPUTER" \
gt="${FILT_VCF}.vcf" \
out="$IMP_VCF"

# === 4. DATA SUMMARY ===
## load modules
module purge
module load GCC/13.2.0
module load Java/1.8.0_292-OpenJDK

## run summary
"$TASSEL" -Xmx70g \
    -log "${LOG_OUT}/${PREFIX}_FILT_IMP.log" \
    -fork1 \
    -vcf "${IMP_VCF}.vcf.gz" \
    -genotypeSummary all \
    -export "${SUM_OUT}/${PREFIX}" \
    -runfork1

