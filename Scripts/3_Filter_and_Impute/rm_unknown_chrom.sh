#!/bin/bash

#SBATCH --export=NONE
#SBATCH --job-name=method_comparison_RM_UNK_CHROM_
#SBATCH --time=03:00:00
#SBATCH --ntasks-per-node=1
#SBATCH --cpus-per-task=5
#SBATCH --mem=150GB
#SBATCH --output=%x.%j.stdout
#SBATCH --error=%x.%j.stderr
#SBATCH --account=132740983163
#SBATCH --mail-user=luke.whiteley@ag.tamu.edu
#SBATCH --mail-type=ALL

#-------------------------------------------------------------------------------
# Environment Setup
#-------------------------------------------------------------------------------

module purge
#module load Anaconda3/2024.02-1
module load GCCcore/13.2.0
module load BWA/0.7.18
module load Java/1.8.0_292-OpenJDK

# Initialize conda and activate TASSEL environment
#source "$(conda info --base)/etc/profile.d/conda.sh"
#conda activate TASSEL
TASSEL="/scratch/group/genomic_predict/SNP_Calling/Software/tassel-5-standalone/run_pipeline.pl"

# Configure inputs/outputs
WD="/scratch/group/genomic_predict/SNP_Calling/TXBM21-26_AMA_ONLY/TASSEL_Workflow_Outputs/HDF5"
H5_IN="TXBM21-26_productionHapMap.h5"
STUDY="TXBM21-26"


# Java memory settings
JAVA_MIN_MEM="10g"
JAVA_MAX_MEM="140g"

# Genotype missingness threshold for filtering taxa
GENO_MIN_NOT_MISSING=0.05 

#-------------------------------------------------------------------------------
# Remove unknown chromosome
#-------------------------------------------------------------------------------

# 1-step pre-site filtering
${TASSEL} -Xms${JAVA_MIN_MEM} -Xmx${JAVA_MAX_MEM} \
    -fork1 \
    -h5 "${WD}/${H5_IN}" \
    -FilterSiteBuilderPlugin \
        -siteRangeFilterType SITES \
        -startSite 0 \
        -endSite 2183031 \
        -endPlugin \
    -FilterTaxaPropertiesPlugin \
        -minNotMissing "${GENO_MIN_NOT_MISSING}" \
        -endPlugin \
    -export "${WD}/${STUDY}_chrunk_and_geno95_same_time.h5" \
    -exportType HDF5 \
    -runfork1

# 2-step pre-site filtering method (first rm chr unknown, then filter taxa)
${TASSEL} -Xms${JAVA_MIN_MEM} -Xmx${JAVA_MAX_MEM} \
    -fork1 \
    -h5 "${WD}/${H5_IN}" \
    -FilterSiteBuilderPlugin \
        -siteRangeFilterType SITES \
        -startSite 0 \
        -endSite 2183031 \
        -endPlugin \
    -export "${WD}/${STUDY}_chrunk_first.h5" \
    -exportType HDF5 \
    -runfork1

${TASSEL} -Xms${JAVA_MIN_MEM} -Xmx${JAVA_MAX_MEM} \
    -fork1 \
    -h5 "${WD}/${STUDY}_chrunk_first.h5" \
    -FilterTaxaPropertiesPlugin \
    -minNotMissing "${GENO_MIN_NOT_MISSING}" \
        -endPlugin \
    -export "${WD}/${STUDY}_chrunk_first_geno95.h5" \
    -exportType HDF5 \
    -runfork1