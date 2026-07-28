#!/bin/bash
#SBATCH --export=NONE
#SBATCH --job-name=TXBM21-25--geno_miss05-MLC35-MAF03-HET015
#SBATCH --time=8:00:00
#SBATCH --ntasks-per-node=1
#SBATCH --cpus-per-task=10
#SBATCH --mem=75GB
#SBATCH --output=stdout.%x.%j
#SBATCH --error=stderr.%x.%j
#SBATCH --account=132740983644
#SBATCH --mail-user=luke.whiteley@ag.tamu.edu
#SBATCH --mail-type=all

# === 1. CONFIGURE FILTER ===
## name of output vcf
VCF_NAME="TXBM21-25--geno_miss05-MLC35-MAF03-HET015"

## configure filtering parameters
#MISS=0.05              # filter out genotypes based on missing data (PREV. SCRIPT "GENO_FILTER")
MLC=799                 # calc MLC for the number of remaining genotypes (ex. 1,000 genotypes * 0.2 MLC = 200 minimum site count)
MAF=0.03
HET=0.0156
RM_MINOR_SNP=TRUE
RM_INDELS=TRUE

# === 2. SET UP WORKFLOW ===
## load modules
module purge
module load GCC/13.2.0
module load Java/1.8.0_292-OpenJDK

## Working dir
WD="/scratch/group/genomic_predict/SNP_Calling/TXBM21-25_AAA"
HD5="/scratch/group/genomic_predict/SNP_Calling/TXBM21-25_AAA/Pre-Imputation_Filtering/FAST_TXBM21-25.05geno_miss.h5"

## Navigate to wd
cd $WD

## log directory
LOG_OUT="$WD/Pre-Imputation_Filtering/Logs"
SUM_OUT="$WD/Pre-Imputation_Filtering/Summaries"
VCF_OUT="$WD/Pre-Imputation_Filtering/VCF"
mkdir -p "$LOG_OUT"
mkdir -p "$SUM_OUT"
mkdir -p "$VCF_OUT"

## TASSEL v5 location
TASSEL="/scratch/group/genomic_predict/SNP_Calling/TXBM21-25/Optimization/TASSEL/tassel-5-standalone/run_pipeline.pl"

# === 3. RUN FILTER ===
## export to VCF
"$TASSEL" -Xmx67g -fork1 -h5 "$HD5" \
-FilterSiteBuilderPlugin \
-siteMinCount $MLC \
-siteMinAlleleFreq $MAF \
-siteMaxAlleleFreq 1.0 \
-maxHeterozygous $HET \
-removeMinorSNPStates $RM_MINOR_SNP \
-removeSitesWithIndels $RM_INDELS \
-endPlugin \
-export $VCF_OUT/$VCF_NAME.vcf \
-exportType VCF \
-runfork1

## get statistics separately (they take a while)
"$TASSEL" -Xmx67g -fork1 -h5 "$HD5" \
-FilterSiteBuilderPlugin \
-siteMinCount $MLC \
-siteMinAlleleFreq $MAF \
-siteMaxAlleleFreq 1.0 \
-maxHeterozygous $HET \
-removeMinorSNPStates $RM_MINOR_SNP \
-removeSitesWithIndels $RM_INDELS \
-endPlugin \
-GenotypeSummaryPlugin \
-endPlugin \
-runfork1
