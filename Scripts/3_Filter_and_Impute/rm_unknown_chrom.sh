#!/bin/bash

#SBATCH --export=NONE
#SBATCH --job-name=RM_UNK_CHROM
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

#-------------------------------------------------------------------------------
# Remove unknown chromosome
#-------------------------------------------------------------------------------

${TASSEL} -Xms${JAVA_MIN_MEM} -Xmx${JAVA_MAX_MEM} \
    -fork1 \
    -h5 "${WD}/${H5_IN}" \
    -FilterSiteBuilderPlugin \
        -siteRangeFilterType SITES \
        -startSite 0 \
        -endSite 2183031 \
        -endPlugin \
    -export "${WD}/${STUDY}_NoChrUNK.h5" \
    -exportType HDF5 \
    -runfork1
