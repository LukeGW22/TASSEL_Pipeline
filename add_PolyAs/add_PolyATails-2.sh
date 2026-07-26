#!/bin/bash

#SBATCH --export=NONE
#SBATCH --job-name=PolyA_TXBM24-25
#SBATCH --time=15:00:00
#SBATCH --ntasks-per-node=1
#SBATCH --cpus-per-task=5
#SBATCH --mem=8GB
#SBATCH --output=stdout.%x.%j
#SBATCH --error=stderr.%x.%j
#SBATCH --account=132740983644
#SBATCH --mail-user=luke.whiteley@ag.tamu.edu
#SBATCH --mail-type=all

# navigate to WD
WD=/scratch/group/genomic_predict/SNP_Calling/TXBM21-25_AAA
cd $WD

# list FASTQs that script will work on
echo "************************************** FASTQ.gz files to use:"
ls -lag *.fastq.gz
echo "========================================================="

# unzip then add PolyA tails
for file in *.fastq.gz; do
if [[ -f $file ]]; then

    # 1) force decompress, suppressing CRC errors
    echo "Unzipping $file..."
    gzip -dc "$file" > "${file%.gz}" 2>/dev/null

    # 2) remove the ".gz" from the file name
    unzipped_file="${file%.gz}"

    # 3) run Paul's PolyA script
    echo "Adding PolyA Tails..."
    bash ./AddPolyA-new.sh "$unzipped_file"

    # 4) delete the temporary fastq file
    echo "Removing temporary FASTQ: $unzipped_file"
    rm "$unzipped_file"

    echo "-----------------------------------------------"
fi
done

echo "========================================================="
echo "All Files have had Poly A Tails added."

