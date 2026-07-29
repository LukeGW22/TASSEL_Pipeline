#!/bin/bash
#SBATCH --export=NONE
#SBATCH --job-name=TXBM21-26_filter_impute
#SBATCH --time=16:00:00
#SBATCH --ntasks-per-node=1
#SBATCH --cpus-per-task=48
#SBATCH --mem=300GB
#SBATCH --output=/scratch/group/genomic_predict/SNP_Calling/TXBM21-26/Logs/%x.%j.out
#SBATCH --error=/scratch/group/genomic_predict/SNP_Calling/TXBM21-26/Logs/%x.%j.err
#SBATCH --account=132740983163
#SBATCH --mail-user=luke.whiteley@ag.tamu.edu
#SBATCH --mail-type=all
# NOTE: Logs directory must exist before submitting:
#   mkdir -p /scratch/group/genomic_predict/SNP_Calling/TXBM21-26/Logs
#   (Keep --output/--error paths in sync with LOG_DIR in config.env)
#===============================================================================
# TASSEL Filter + BEAGLE Imputation (TXBM21-26)
#
# Stage 1: Remove UNKNOWN chromosome sites & taxa with >95% missing data   (FilterSiteBuilderPlugin + FilterTaxaPropertiesPlugin)
# Stage 2: Site filters — MLC=20, MAF=0.02      (FilterSiteBuilderPlugin)
# Stage 3: Impute with BEAGLE default params
# Stage 4: Genotype summary on imputed VCF
#
# Input:  OUTPUT_DIR/HDF5/${STUDY}_productionHapMap.h5
# Output: PI_FILTER_DIR/${PARAM_LABEL}/   (filtered VCF)
#         IMPUTE_DIR/                      (imputed VCF)
#===============================================================================

set -euo pipefail

#-------------------------------------------------------------------------------
# CONFIG — source shared paths from config.env
#
# PROJECT_ROOT is hardcoded because SLURM copies this script to /var/spool/
# before execution, making $0-relative path resolution unreliable.
# Keep this value in sync with the #SBATCH --output/--error paths above.
#-------------------------------------------------------------------------------

PROJECT_ROOT="/scratch/group/genomic_predict/SNP_Calling/TXBM21-26"

CONFIG_FILE="${PROJECT_ROOT}/config.env"
if [[ ! -f "${CONFIG_FILE}" ]]; then
    echo "ERROR: config.env not found at: ${CONFIG_FILE}"
    echo "       Copy config.env.template → config.env and fill in values."
    exit 1
fi
# shellcheck source=/dev/null
source "${CONFIG_FILE}"

#-------------------------------------------------------------------------------
# ENVIRONMENT SETUP (must happen after config is sourced so CONDA_PREFIX is set)
#-------------------------------------------------------------------------------

#module load Anaconda3/2024.02-1
#source "$(conda info --base)/etc/profile.d/conda.sh"
# Conda's openjdk activate.d script references JAVA_HOME before setting it,
# which trips set -u. Temporarily disable nounset around conda activate.
#set +u
#conda activate TASSEL
#set -u

#-------------------------------------------------------------------------------
# FILTER PARAMETERS — edit here
#-------------------------------------------------------------------------------

GENO_MIN_NOT_MISSING=0.05    # Minimum non-missing fraction per taxon (0.05 → drop >95% missing)
MLC_FRACTION=0.20            # MLC = this fraction × number of taxa passing the geno filter
MAF=0.02                     # Minimum minor allele frequency
MAX_HET=0.0156               # Maximum heterozygosity per site
PARAM_LABEL="geno95_MLC20_MAF02_qc_first"
START_SITE=0                 # start site for Chr 1A (usually 0)
END_SITE=2695770             # end site for Chr 7D.

# Java heap for the filtering stages — larger than the config default to handle
# the full in-memory genotype matrix during FilterTaxa and FilterSites.
# SLURM allocation is 300 GB; leave ~50 GB for OS/JVM overhead.
FILTER_JAVA_MIN_MEM="20g"
FILTER_JAVA_MAX_MEM="250g"

# Path to BEAGLE jar — update to match cluster location
BEAGLE_JAR="${DATA_ROOT}/Software/beagle.jar"

#-------------------------------------------------------------------------------
# DERIVED PATHS
#-------------------------------------------------------------------------------

Study="${STUDY}"
#TASSEL="${CONDA_PREFIX}/bin/run_pipeline.pl"
TASSEL="${DATA_ROOT}/Software/tassel-5-standalone/run_pipeline.pl"

H5_IN="${OUTPUT_DIR}/HDF5/${Study}_productionHapMap.h5"

# Filtering outputs → PI_FILTER_DIR (pre-imputation filtering) from config.env
FILT_DIR="${PI_FILTER_DIR}/${PARAM_LABEL}"
STEP_LOG_DIR="${FILT_DIR}/logs"   # TASSEL plugin logs; LOG_DIR (from config) is for SLURM job logs
SUM_DIR="${FILT_DIR}/summaries"

GENO_QC1_FILT_H5="${FILT_DIR}/${Study}_snpQC_all_genotypes.h5"
GENO_QC2_FILT_H5="${FILT_DIR}/${Study}_QC_geno95.h5"
SITE_FILT_VCF="${FILT_DIR}/${Study}_${PARAM_LABEL}_filtered"

# Imputation outputs → IMPUTE_DIR from config.env
IMP_VCF="${IMPUTE_DIR}/${Study}_${PARAM_LABEL}_IMPUTED"

mkdir -p "${FILT_DIR}" "${STEP_LOG_DIR}" "${SUM_DIR}" "${IMPUTE_DIR}"

#-------------------------------------------------------------------------------
# STAGE 1: QUALITY CONTROL
# 1. Remove UNKNOWN chromosome sites
# 2. Drop SNPs with >1.56% heterozygosity
# 3. Drop monomorphs/multialleles/indels
# 4. Drop taxa with >95% missing data
#-------------------------------------------------------------------------------
echo ""
echo "================================================================================================================="
echo "[$(date '+%Y-%m-%d %H:%M:%S')] STAGE 1: Remove UNKNOWN chromosome sites & drop taxa with >95% missing data"
echo "================================================================================================================="

module purge
module load GCC/13.2.0
module load Java/1.8.0_292-OpenJDK

# STAGE 1.a: QUALITY CONTROL - sites
"${TASSEL}" -Xms${FILTER_JAVA_MIN_MEM} -Xmx${FILTER_JAVA_MAX_MEM} \
    -fork1 \
    -h5 "${H5_IN}" \
    -FilterSiteBuilderPlugin \
        -siteRangeFilterType SITES \
        -startSite "${START_SITE}" \
        -endSite "${END_SITE}" \
        -maxHeterozygous "${MAX_HET}" \
        -removeMinorSNPStates true \
        -removeSitesWithIndels true \
        -endPlugin \
    -export "${GENO_QC1_FILT_H5}" \
    -exportType HDF5 \
    -runfork1

# TASSEL exits 0 even on plugin errors — verify output was actually created.
if [[ ! -f "${GENO_QC1_FILT_H5}" ]]; then
    echo "ERROR: Stage 1.a failed — ${GENO_QC1_FILT_H5} was not created."
    echo "       Check TASSEL log output above for details."
    exit 1
fi
echo "[$(date '+%Y-%m-%d %H:%M:%S')] Stage 1.a complete: ${GENO_QC1_FILT_H5}"

# STAGE 1.b: QUALITY CONTROL - taxa
# Tee stdout to a log so we can parse the taxa count TASSEL prints when writing HDF5:
#   "Number of taxa in HDF5 file:<N>"
# This avoids a separate GenotypeSummaryPlugin invocation (and the fragile file-glob parsing).
STAGE1B_LOG="${STEP_LOG_DIR}/01b_FilterTaxa.log"
"${TASSEL}" -Xms${FILTER_JAVA_MIN_MEM} -Xmx${FILTER_JAVA_MAX_MEM} \
    -fork1 \
    -h5 "${GENO_QC1_FILT_H5}" \
    -FilterTaxaPropertiesPlugin \
        -minNotMissing "${GENO_MIN_NOT_MISSING}" \
        -endPlugin \
    -export "${GENO_QC2_FILT_H5}" \
    -exportType HDF5 \
    -runfork1 2>&1 | tee "${STAGE1B_LOG}"

# TASSEL exits 0 even on plugin errors — verify output was actually created.
if [[ ! -f "${GENO_QC2_FILT_H5}" ]]; then
    echo "ERROR: Stage 1.b failed — ${GENO_QC2_FILT_H5} was not created."
    echo "       Check ${STAGE1B_LOG} for details."
    exit 1
fi
echo "[$(date '+%Y-%m-%d %H:%M:%S')] Stage 1.b complete: ${GENO_QC2_FILT_H5}"

# Parse taxa count from Stage 1.b output — TASSEL prints "Number of taxa in HDF5 file:<N>"
TAXA_COUNT=$(grep -oP '(?<=Number of taxa in HDF5 file:)\d+' "${STAGE1B_LOG}" | tail -1)

if [[ -z "${TAXA_COUNT}" || ! "${TAXA_COUNT}" =~ ^[0-9]+$ ]]; then
    echo "ERROR: Could not parse taxa count from ${STAGE1B_LOG}."
    echo "       Expected a line matching 'Number of taxa in HDF5 file:<N>'."
    exit 1
fi

# ceiling( taxa * fraction ) via awk (avoids bc hanging on empty/non-numeric input)
MLC=$(awk -v taxa="${TAXA_COUNT}" -v frac="${MLC_FRACTION}" \
    'BEGIN { mlc = taxa * frac; print (mlc == int(mlc)) ? int(mlc) : int(mlc) + 1 }')
echo "[$(date '+%Y-%m-%d %H:%M:%S')] Taxa after geno filter: ${TAXA_COUNT}  →  MLC = ${MLC} (${MLC_FRACTION} × ${TAXA_COUNT})"

#-------------------------------------------------------------------------------
# STAGE 2: Filter sites — MLC=20% of filtered taxa, MAF=0.02, set hets to missing
#-------------------------------------------------------------------------------

echo ""
echo "======================================================================"
echo "[$(date '+%Y-%m-%d %H:%M:%S')] Stage 2: Filter sites (MLC=${MLC}, MAF=${MAF})"
echo "======================================================================"

"${TASSEL}" -Xms${FILTER_JAVA_MIN_MEM} -Xmx${FILTER_JAVA_MAX_MEM} \
    -log "${STEP_LOG_DIR}/02_FilterSites.log" \
    -fork1 \
    -h5 "${GENO_QC2_FILT_H5}" \
        -FilterSiteBuilderPlugin \
        -siteMinCount "${MLC}" \
        -siteMinAlleleFreq "${MAF}" \
        -siteMaxAlleleFreq 1.0 \
        -endPlugin \
    -homozygous \
    -export "${SITE_FILT_VCF}" \
    -exportType VCF \
    -runfork1

if [[ ! -f "${SITE_FILT_VCF}.vcf" ]]; then
    echo "ERROR: Stage 2 failed — ${SITE_FILT_VCF}.vcf was not created."
    echo "       Check ${STEP_LOG_DIR}/02_FilterSites.log for details."
    exit 1
fi
echo "[$(date '+%Y-%m-%d %H:%M:%S')] Site filtering complete: ${SITE_FILT_VCF}.vcf"

#-------------------------------------------------------------------------------
# STAGE 3: Impute with BEAGLE (default parameters)
#-------------------------------------------------------------------------------

echo ""
echo "======================================================================"
echo "[$(date '+%Y-%m-%d %H:%M:%S')] Stage 3: BEAGLE imputation"
echo "======================================================================"

module purge
module load Java/21.0.2

java -Xmx${JAVA_MAX_MEM} -jar "${BEAGLE_JAR}" \
    gt="${SITE_FILT_VCF}.vcf" \
    out="${IMP_VCF}"

echo "[$(date '+%Y-%m-%d %H:%M:%S')] Imputation complete: ${IMP_VCF}.vcf.gz"

#-------------------------------------------------------------------------------
# STAGE 4: Genotype summary on imputed VCF
#-------------------------------------------------------------------------------

echo ""
echo "======================================================================"
echo "[$(date '+%Y-%m-%d %H:%M:%S')] Stage 4: Genotype summary"
echo "======================================================================"

module purge
module load GCC/13.2.0
module load Java/1.8.0_292-OpenJDK

"${TASSEL}" -Xms${JAVA_MIN_MEM} -Xmx${JAVA_MAX_MEM} \
    -log "${STEP_LOG_DIR}/04_Summary.log" \
    -fork1 \
    -vcf "${IMP_VCF}.vcf.gz" \
    -GenotypeSummaryPlugin \
    -endPlugin \
    -export "${SUM_DIR}/${Study}_${PARAM_LABEL}" \
    -runfork1

echo ""
echo "[$(date '+%Y-%m-%d %H:%M:%S')] Pipeline complete."
echo "  Filtered VCF:  ${SITE_FILT_VCF}.vcf"
echo "  Imputed VCF:   ${IMP_VCF}.vcf.gz"
echo "  Summary:       ${SUM_DIR}/${Study}_${PARAM_LABEL}"
