#!/bin/bash

#SBATCH --export=NONE
#SBATCH --job-name=PolyA-21-25_Call_SNPs
#SBATCH --time=10:30:00
#SBATCH --ntasks-per-node=1
#SBATCH --cpus-per-task=48
#SBATCH --mem=250GB
#SBATCH --output=stdout.%x.%j
#SBATCH --error=stderr.%x.%j
#SBATCH --account=132740983644
#SBATCH --mail-user=luke.whiteley@ag.tamu.edu
#SBATCH --mail-type=all

module purge
module load Anaconda3/2024.02-1
module load GCCcore/13.2.0
module load BWA/0.7.18
#module load bwa-mem2/2.2.1-Linux64     # a more efficient BWA algorithm

# initialize conda
source $(conda info --base)/etc/profile.d/conda.sh

# activate TASSEL env
conda activate TASSEL

# navigate to project directory
cd '/scratch/group/genomic_predict/SNP_Calling/TXBM21-25_AAA'

# execute TASSEL workflow
#bash TXBM19-25_Tassel5GBSv2_pipeline_Paulv3.sh
nohup ./TXBM21-25_Tassel5GBSv2_pipeline_Paulv3.sh | tee -a TXBM21-25_Tassel5GBSv2_pipeline_Paulv3-log.txt
