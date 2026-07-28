#!/bin/bash
#SBATCH --export=NONE
#SBATCH --job-name=TXBM21-26_filter_impute
#SBATCH --time=8:00:00
#SBATCH --ntasks-per-node=1
#SBATCH --cpus-per-task=48
#SBATCH --mem=300GB
#SBATCH --output=stdout.%x.%j
#SBATCH --error=stderr.%x.%j
#SBATCH --account=132740983644
#SBATCH --mail-user=luke.whiteley@ag.tamu.edu
#SBATCH --mail-type=all
#===============================================================================
# TASSEL Filter + BEAGLE Imputation (TXBM21-26)
#
# Stage 1: Remove taxa with >95% missing data   (FilterTaxaPropertiesPlugin)
# Stage 2: Site filters — MLC=20, MAF=0.02      (FilterSiteBuilderPlugin)
# Stage 3: Impute with BEAGLE default params
# Stage 4: Genotype summary on imputed VCF
#
# Input:  pipeline HDF5 (OUTPUT_DIR/HDF5/${STUDY}_productionHapMap.h5)
# Output: OUTPUT_DIR/filtering/geno95_MLC20_MAF02/
#===============================================================================

set -euo pipefail

#-------------------------------------------------------------------------------
# CONFIG — source shared paths from config.env
#-------------------------------------------------------------------------------

CONFIG_FILE="${PROJECT_ROOT:-$(dirname "$(dirname "$(dirname "$0")")")}/config.env"
if [[ ! -f "${CONFIG_FILE}" ]]; then
    echo "ERROR: config.env not found at: ${CONFIG_FILE}"
    echo "       Copy config.env.template → config.env and fill in values."
    exit 1
fi
# shellcheck source=/dev/null
source "${CONFIG_FILE}"

#-------------------------------------------------------------------------------
# FILTER PARAMETERS — edit here
#-------------------------------------------------------------------------------

GENO_MIN_NOT_MISSING=0.05   # Minimum non-missing fraction per taxon (0.05 → drop >95% missing)
MLC_FRACTION=0.20            # MLC = this fraction × number of taxa passing the geno filter
MAF=0.02                     # Minimum minor allele frequency
MAX_HET=0.0156               # Maximum heterozygosity per site
PARAM_LABEL="geno95_MLC20pct_MAF02"

# Path to BEAGLE jar — update to match cluster location
BEAGLE_JAR="${DATA_ROOT}/Software/beagle.jar"

#-------------------------------------------------------------------------------
# DERIVED PATHS
#-------------------------------------------------------------------------------

Study="${STUDY}"
TASSEL="${CONDA_PREFIX}/bin/run_pipeline.pl"

H5_IN="${OUTPUT_DIR}/HDF5/${Study}_productionHapMap.h5"

FILT_DIR="${OUTPUT_DIR}/filtering/${PARAM_LABEL}"
LOG_DIR="${FILT_DIR}/logs"
SUM_DIR="${FILT_DIR}/summaries"

GENO_FILT_H5="${FILT_DIR}/${Study}_geno95.h5"
SITE_FILT_VCF="${FILT_DIR}/${Study}_${PARAM_LABEL}_filtered"
IMP_VCF="${FILT_DIR}/${Study}_${PARAM_LABEL}_IMPUTED"

mkdir -p "${FILT_DIR}" "${LOG_DIR}" "${SUM_DIR}"

#-------------------------------------------------------------------------------
# STAGE 1: Filter taxa — drop genotypes with >95% missing data
#-------------------------------------------------------------------------------

echo ""
echo "======================================================================"
echo "[$(date '+%Y-%m-%d %H:%M:%S')] Stage 1: Filter taxa (minNotMissing=${GENO_MIN_NOT_MISSING})"
echo "======================================================================"

module purge
module load GCC/13.2.0
module load Java/1.8.0_292-OpenJDK

"${TASSEL}" -Xms${JAVA_MIN_MEM} -Xmx${JAVA_MAX_MEM} \
    -log "${LOG_DIR}/01_FilterTaxa.log" \
    -fork1 \
    -h5 "${H5_IN}" \
    -FilterTaxaPropertiesPlugin \
    -minNotMissing "${GENO_MIN_NOT_MISSING}" \
    -endPlugin \
    -export "${GENO_FILT_H5}" \
    -exportType HDF5 \
    -runfork1

echo "[$(date '+%Y-%m-%d %H:%M:%S')] Taxa filtering complete: ${GENO_FILT_H5}"

# Count surviving taxa and compute MLC = ceil(taxa * MLC_FRACTION)
echo "[$(date '+%Y-%m-%d %H:%M:%S')] Counting taxa to compute MLC..."
TAXA_SUMMARY="${FILT_DIR}/.taxa_count"
"${TASSEL}" -Xms1g -Xmx4g \
    -fork1 \
    -h5 "${GENO_FILT_H5}" \
    -GenotypeSummaryPlugin \
    -overview true \
    -endPlugin \
    -export "${TAXA_SUMMARY}" \
    -runfork1 > /dev/null 2>&1
TAXA_COUNT=$(awk -F'\t' '/^Number of Taxa/{print $2}' "${TAXA_SUMMARY}1_GenotypeSummary.txt")
# ceiling( taxa * fraction ) via bc
MLC=$(echo "scale=0; (${TAXA_COUNT} * ${MLC_FRACTION} + 0.9999) / 1" | bc)
echo "[$(date '+%Y-%m-%d %H:%M:%S')] Taxa after geno filter: ${TAXA_COUNT}  →  MLC = ${MLC} (${MLC_FRACTION} × ${TAXA_COUNT})"

#-------------------------------------------------------------------------------
# STAGE 2: Filter sites — MLC=20% of filtered taxa, MAF=0.02, remove multiallelic/indels, set hets to missing
#-------------------------------------------------------------------------------

echo ""
echo "======================================================================"
echo "[$(date '+%Y-%m-%d %H:%M:%S')] Stage 2: Filter sites (MLC=${MLC}, MAF=${MAF})"
echo "======================================================================"

"${TASSEL}" -Xms${JAVA_MIN_MEM} -Xmx${JAVA_MAX_MEM} \
    -log "${LOG_DIR}/02_FilterSites.log" \
    -fork1 \
    -h5 "${GENO_FILT_H5}" \
    -FilterSiteBuilderPlugin \
    -siteMinCount "${MLC}" \
    -siteMinAlleleFreq "${MAF}" \
    -siteMaxAlleleFreq 1.0 \
    -maxHeterozygous "${MAX_HET}" \
    -removeMinorSNPStates true \
    -removeSitesWithIndels true \
    -endPlugin \
    -homozygous \
    -export "${SITE_FILT_VCF}" \
    -exportType VCF \
    -runfork1

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
    -log "${LOG_DIR}/04_Summary.log" \
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
