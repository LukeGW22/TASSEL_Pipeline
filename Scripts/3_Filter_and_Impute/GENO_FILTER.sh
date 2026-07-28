#!/bin/bash
#SBATCH --export=NONE
#SBATCH --job-name=TXBM21-25.05geno_miss
#SBATCH --time=8:00:00
#SBATCH --ntasks-per-node=1
#SBATCH --cpus-per-task=10
#SBATCH --mem=75GB
#SBATCH --output=stdout.%x.%j
#SBATCH --error=stderr.%x.%j
#SBATCH --account=132740983644
#SBATCH --mail-user=luke.whiteley@ag.tamu.edu
#SBATCH --mail-type=all

## outfile name
Study="FAST_TXBM21-25.05geno_miss"

## configure filter
MISS=0.05

## load modules
module purge
module load GCC/13.2.0
module load Java/1.8.0_292-OpenJDK

## Working dir
WD="/scratch/group/genomic_predict/SNP_Calling/TXBM21-25_AAA"
HD5="TXBM21-25_AAA_productioHapMap_noKO.h5"

## Navigate to wd
cd $WD

## log directory
LOG_OUT="$WD/Pre-Imputation_Filtering/Logs"
SUM_OUT="$WD/Pre-Imputation_Filtering/Summaries"
mkdir -p "$LOG_OUT"
mkdir -p "$SUM_OUT"

## TASSEL v5 location
TASSEL="/scratch/group/genomic_predict/SNP_Calling/TXBM21-25/Optimization/TASSEL/tassel-5-standalone/run_pipeline.pl"

# === 2. RUN FILTER ===
## Fast run (no stats)
"$TASSEL" -Xmx67g -fork1 -h5 "$HD5" \
-FilterTaxaPropertiesPlugin \
-minNotMissing $MISS \
-endPlugin \
-export ./Pre-Imputation_Filtering/$Study.h5 \
-exportType HDF5 \
-runfork1

## Run with stats
#"$TASSEL" -Xmx14g -fork1 -h5 "$HD5" \
#-FilterTaxaPropertiesPlugin \
#-minNotMissing $MISS \
#-endPlugin \
#-GenotypeSummaryPlugin \
#-overview true \
#-siteSummary true \
#-endPlugin \
#-export ./Pre-Imputation_Filtering/$Study.vcf \
#-exportType VCF \
#-runfork1
