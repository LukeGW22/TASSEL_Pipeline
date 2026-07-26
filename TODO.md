# TXBM21-25 SNP Calling To-Do List

## Setup

### Directory Setup

1. Make WD (`/scratch/group/genomic_predict/SNP_Calling/TXBM21-26`)
2. Make the following directories:
    * a) `Scripts/`
        * `cli_utils/` for working with files/folders
        * `SNPCalling/` for FASTQ pre-processing and calling SNPs
        * `Processing/` for processing called SNPs
    * b) `Logs/`
        * `cli_utils_logs/`
    * b) `Pre-Imputation_Filtering/`
    * c) `Imputation/`

3. Add reference genome files to WD
4. Add the fastq files to directory
    * a) transfer `PolyA_FASTQ/` (`/scratch/group/genomic_predict/SNP_Calling/TXBM21-25_AAA/PolyA_FASTQ/`) using `movePolyA.sh` 
5. Add the updated key to the directory
6. Add the following to `Scripts/`
    * a) `add_PolyATails-2.sh`
    * b.1) `TXBM21-25_Tassel5GBSv2_pipeline_Paulv3.sh` (`/scratch/group/genomic_predict/SNP_Calling/TXBM21-25_AAA/TXBM21-25_Tassel5GBSv2_pipeline_Paulv3.sh`)
    * b.2) `Call_SNPs_launch.sh` (`/scratch/group/genomic_predict/SNP_Calling/TXBM21-25_AAA/Call_SNPs_launch.sh`)
    * c) `SNP_FILTER-v2.sh` (`/scratch/group/genomic_predict/SNP_Calling/TXBM21-25_AAA/SNP_FILTER-v2.sh`)
    * d) `impute_TXBM21-25.sh` (`/scratch/group/genomic_predict/Imputation/Beagle/impute_TXBM21-25.sh`)


### Files
1) Update key to include 2026 sample barcodes
2) Run `add_PolyATails-2.sh` on the fastq.gz files

## SNP Calling
1) Run `

## Pre-Imputation Filtering

## Imputation

## Post-Imputation Filtering

## Save to File
