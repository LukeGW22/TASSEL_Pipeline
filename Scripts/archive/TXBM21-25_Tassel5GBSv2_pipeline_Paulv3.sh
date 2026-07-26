#!/bin/bash

### Tassel Version: 5.2.42 installed on Feb 8.
### TASSEL-5 Ref-GBS pipeline for use on ION TORRENT-PROTON fastq files on the USDABioinformatics server.
### How to use this script (version 1):

### 1. This TASSEL5 Ref-GBS pipeline is for use ONLY with ION TORRENT-PROTON fastq files on the USDA-Bioinformatics server.
### 2. Login to the USDA-Bioinformatics server (129.130.90.3) via the ssh protocol using PUTTY (http://www.putty.org) or another similar application.
### 3. Create a working dir or subdir in your home folder and cd to your working dir.
### 4. Copy the following script to your working dir:
### 	/home/share/tools/Tassel5GBSv2_pipeline_Paulv3.sh
### 5. Copy the example KEY and LINES files to your working dir if you need to see example file layouts:
### 	/home/share/tools/Sample-Key.txt
### 	/home/share/tools/Sample-Lines.txt
### 6. Copy your fastq files to your working dir. You can use the curl command to copy fastq files directly from our sequencer to your working dir. First, copy the URL that is the direct file link from our sequencer web page. You then past that URL after this command: "curl --user ionuser:WheatIon -O "
### For example: "curl --user ionuser:WheatIon -O http://129.130.90.13/output/Home/Auto_user_usdaksproton-296-Sample_GBS_804/plugin_out/FileExporter_out.1186/Auto_user_usdaksproton-296-Sample_GBS_804.fastq"
### 7. Run the AddPolyA.sh script on EACH of your fastq files like this: "/home/share/tools/AddPolyA.sh FileName1.fastq" This will create a new file and add 80 poly-A bases to the 3' end of each read. TASSEL5 will not work with reads shorter than 79 bases and this insures all reads are at least 79 bases long. The poly-A end also improves marker finding. The original file will not be changed.
### 8. You MUST move (or rename) all of the original fastq files out of the working directory. Any directory ABOVE the working directory is fine. If you leave them in the working directory, the TASSEL5 pipeline will read them and the poly-A versions.
### 9. Ensure your file names are in the following format (the underscores are important): "flowcellName_laneNum_runNum.fastq". Example: "AAAA-Test_1_1.fastq" Remember that the "flowcellName" part of the filename MUST be identical to the "flowcellName" found in the KEY file.
### 10. Copy keyfiles and taxafile to your working dir. They MUST be UNIX file types. Remove dupes and blanks from the taxafile (LINES file). The GBSv2 key file has 8 required headers: Flowcell, Lane, Barcode, FullSampleName, PlateName, Row, Column, Well. You MUST have the correct barcode sequences for your samples. The key file may contain additional columns of data useful to the user. Entries in the FullSampleName column may be anything meaningful to the user as a unique identifier of the final genotype. Entries in this column are used to facilitate merging the sample if it was run multiple times. This will be useful for replicate sample runs. If the same entry appears in multiple rows of the FullSampleName column, all entries for those rows will be merged and processed together. The taxa/LINES file is a UNIX file with one header <NAME> and each line is one germplasm. Remove duplicates from this file. The lines file lists samples to be analyzed. This makes it possible to analyze a subset of the full set.
### 11. You MUST change the definitions for several items in the script before running it. Examine the script and set the following to proper values: working dir, study name, genome to use, keyfile name, production keyfile name, MCL, MAF, & taxafile name. You can copy the script to your computer and make the changes and copy the script back to your working directory. On a PC, edit the file using NotePad++ (DO NOT USE WORD OR NOTEPAD). On a Mac use TextWranger or BBedit (DO NOT USE WORD). MAKE SURE THAT THE FILE TYPE REMAINS UNIX WHEN YOU SAVE IT.
### 12. Make certain that the script is executable. Use "chmod +x Tassel5GBSv2_pipeline_Paulv3.sh" if needed.
### 13. From your working dir, run the script with this command: "nohup ./Tassel5GBSv2_pipeline_Paulv3.sh | tee -a Tassel5GBSv2_pipeline_Paulv3-log.txt" This will run the TASSEL5-Ref pipeline and create log files and the hapmap file in the hapmap directory.
### 14. Check terminal output for errors. You can cancel the script with Control-C. The script should take from 20 min to 2 hours.
### 15. Once the script is done, cd into the hapmap directory and run the GetMarkerCountsPerChrom.sh script like this: "/home/share/tools/GetMarkerCountsPerChrom.sh" This script will create a txt file with marker counts per genome and per chromosome.
### 16. While still in the hapmap directory, copy the full filename of your hmp.txt file and edit this command and run the GBSTagStats.sh script like this: "/home/share/tools/GBSTagStats.sh YourFileNameHere.hmp.txt | tee -a GBSTagStats.txt" This will create a txt file with stats on the markers.
### 17. While still in the hapmap directory, copy the full filename of your hmp.txt file and edit this command and run the PlotMarkerDistributionFromHapmapVarY.sh script like this: "/home/share/tools/PlotMarkerDistributionFromHapmapVarY.sh YourFileNameHere.hmp.txt 1.0".  This will plot marker distribution along each chromosome in 1.0 cm bins. You can can change the bin size to any cm size. 1.0cm and 0.25cm are useful bin sizes.(OPTIONAL, if you prefer a fixed Y-axis use: PlotMarkerDistributionFromHapmap.sh)
### 18. While still in the hapmap directory, run the GetRefSeqForALLGBSMarkers.sh script like this: "/home/share/tools/GetRefSeqForALLGBSMarkers.sh YourHapMapFileName.hmp.txt".  This will create "markerSeqs.fa" with 400 base sequences for each SNP from the reference. Base 200 in each sequence is the SNP position for each marker (insertions are between 199 and 200?). Copy the "markerSeqs.fa" file.
### 19. While still in the hapmap directory, if you plan to use FlapJack for any analysis of your data, then run the HapmapToFJ.sh script like this: "/home/share/tools/HapmapToFJ.sh YourFileNameHere.hmp.txt" This will create FlapJack style genotype and map files.

### If running two or more ref genomes, compare markers found using Venn diagrams... R?


### 20. If you want to see all found GBS TAGS (not all are used in final hapmap output), cd into the alignment dir, then run this script:
#  /home/share/tools/getGBSTAGSfromSAMfile.sh
# All potential GBS tags are now in" TAGlist.txt", copy this file.
### 21. From the hapmap directory, copy these files to your computer: GBSTagStats.txt, MarkersPerChrom.txt, YourFileNameHere.hmp.txt, markers.fa, and all of the marker plot PDFs.
### 22. From the working directory, copy 5 files to your computer: outputStats_uniqueTaxa.txt, summary1.txt, summary2.txt, summary3.txt, summary4.txt, and Tassel5GBSv2_pipeline_Paulv3-log.txt
### 23. From the working directory, copy all of the poly-A.fastq files to your computer.
### 24. From above the working directory, copy all of the original.fastq files to your computer.
### 25. Once you are done and are certain that you do not need to re-run any analysis on your fastq files, DELETE the entire working directory, including the poly-A.fastq and original.fastq files. Those files are 25 to 40 gb each and we do NOT have the room to store all of those on the USDA-Bioinformatics server. You MUST store your data elsewhere.


### Some of the output descriptions:
### A description of the data contained in the output file:
### aveDepth: Average taxon read depth at SNP.
### minorDepthProp � the percentage of total depth consisting of minor allele 1
### minorDepthProp2 � the percentage of total depth consisting of minor allele 2
### gapDepthProp � percentage of the total depth that represents a gap (allele = GAP_ALLELE, gapDepth/total_depths)
### propCovered � proportion of taxa with depth > 0 at SNP
### propCovered2 � proportion of taxa with depth > 1 at SNP
### taxaCntWithMinorAlleleGE2 � number of taxa containing the minor allele 1 at depth > 1
### If there is more than one allele, the following output is included:
### genotypeCnt: total number of taxa with a depth > 1
### minorAlleleFreqGE2 � minor allele frequency calculated from the taxa with depth > 1
### hetFreq_DGE2 � number of taxa with a depth > 1 that appear heterozygous
### inbredF_DGE2 � inbreeding coefficient for tax with depth > 1, calculated as: 1 - (proportion hets/expected heterozygosity)


### User MUST make the following changes before running script ***************************

#Define the working directory. Leave the "~/", but change the dir and or sub-dir names. Example: ~/gbs/study3
WD=/scratch/group/genomic_predict/SNP_Calling/TXBM21-25_AAA

#Define the study name
### Study=RPN+RGON-2021+2022-MRASeq_job502
Study=TXBM21-25_AAA


#Define the reference genome to use. You should use the CS genome and also re-run with the Jagger genome and compare results.
### Uncomment (remove pound sign only) ONLY 1 of the following to indicate which genome reference you want to use:
### THIS IS THE MOST RECENT WHEAT GENOME: RG=/home/share/tools/refs/iwgsc_refseqv2.0_all_chromosomes.fa

### We currently have multiple versions of the wheat reference genome:
### *****************  WHEAT GENOMES  ******************************************************************************************************
### We currently have multiple versions of the wheat reference genome:

### Wheat, iwgsc_refseqv2.1_all_chromosomes. Latest wheat whole genome reference V2.1, cultivar CS. Use this ref for most purposes. FASTA file with pseudomolecule sequences for the 21 bread wheat chromosomes and one pseudomolecule composed of unanchored scaffolds (chrUn).
RG=$WD/iwgsc_refseqv2.1_assembly.fa

### Wheat, iwgsc_refseqv2.0_all_chromosomes. Wheat whole genome reference V2.0, cultivar CS. FASTA file with pseudomolecule sequences for the 21 bread wheat chromosomes and one pseudomolecule composed of unanchored scaffolds (chrUn).
#RG=/home/share/tools/refs/iwgsc_refseqv2.0_all_chromosomes.fa
### Wheat, ArinaLrFor_pseudomolecules_v3.0.fa, Germplasm from Switzerland. Part of the "Wheat 10+Genome Project", file from: https://wheat.ipk-gatersleben.de/downloads/
#RG=/home/share/tools/refs/ArinaLrFor_pseudomolecules_v3.0.fa
### Wheat, Jagger_pseudomolecules_v1.1.fa, Cultivar from USA. Part of the "Wheat 10+Genome Project", file from: https://wheat.ipk-gatersleben.de/downloads/
#RG=/home/share/tools/refs/Jagger_pseudomolecules_v1.1.fa
### Wheat, Julius_pseudomolecules_v1.0.fa, Cultivar from Germany. Part of the "Wheat 10+Genome Project", file from: https://wheat.ipk-gatersleben.de/downloads/
#RG=/home/share/tools/refs/Julius_pseudomolecules_v1.0.fa
### Wheat, Lancer_pseudomolecules_v1.0.fa, Cultivar from Australia. Part of the "Wheat 10+Genome Project", file from: https://wheat.ipk-gatersleben.de/downloads/
#RG=/home/share/tools/refs/Lancer_pseudomolecules_v1.0.fa
### Wheat, Landmark_pseudomolecules_v1.0.fa, Cultivar from Canada. Part of the "Wheat 10+Genome Project", file from: https://wheat.ipk-gatersleben.de/downloads/
#RG=/home/share/tools/refs/Landmark_pseudomolecules_v1.0.fa
### Wheat, Mace_pseudomolecules_v1.0.fa, Cultivar from Australia. Part of the "Wheat 10+Genome Project", file from: https://wheat.ipk-gatersleben.de/downloads/
#RG=/home/share/tools/refs/Mace_pseudomolecules_v1.0.fa
### Wheat, Norin61_pseudomolecules_v1.1.fa, Cultivar from Japan. Part of the "Wheat 10+Genome Project", file from: https://wheat.ipk-gatersleben.de/downloads/
#RG=/home/share/tools/refs/Norin61_pseudomolecules_v1.1.fa
### Wheat, Spelt_pseudomolecules_v1.0.fa, Wheat subspecies, germplasm from ???. Part of the "Wheat 10+Genome Project", file from: https://wheat.ipk-gatersleben.de/downloads/
#RG=/home/share/tools/refs/Spelt_pseudomolecules_v1.0.fa
### Wheat, Stanley_pseudomolecules_v1.2.fa, Cultivar from Canada. Part of the "Wheat 10+Genome Project", file from: https://wheat.ipk-gatersleben.de/downloads/
#RG=/home/share/tools/refs/Stanley_pseudomolecules_v1.2.fa
### Wheat, SY_Mattis_pseudomolecules_v1.0.fa, Cultivar from Switzerland. Part of the "Wheat 10+Genome Project", file from: https://wheat.ipk-gatersleben.de/downloads/
#RG=/home/share/tools/refs/SY_Mattis_pseudomolecules_v1.0.fa
### Wheat(durum-tetraploid, A & B genomes), Svevo.v1.durum.chromosomes.fa, https://ftp.ncbi.nlm.nih.gov/genomes/all/GCA/900/231/445/GCA_900231445.1_Svevo.v1/GCA_900231445.1_Svevo.v1_genomic.fna.gz
#RG=/home/share/tools/refs/Svevo.v1.durum.chromosomes.fa
### Wheat(emmer-tetraploid, A & B genomes), Zavitan.v2.0.emmer.chromosomes.fa, https://ftp.ncbi.nlm.nih.gov/genomes/all/GCA/002/162/155/GCA_002162155.2_WEW_v2.0/GCA_002162155.2_WEW_v2.0_genomic.fna.gz
#RG=/home/share/tools/refs/Zavitan.v2.0.emmer.chromosomes.fa
### Goatgrass(wheat-relative diploid, D genome), Aegilops_tauschii_strangulata_AL8-78_v4.0.fa, ftp://ftp.ncbi.nlm.nih.gov/genomes/all/GCA/002/575/655/GCA_002575655.1_Aet_v4.0/GCA_002575655.1_Aet_v4.0_genomic.fna.gz
#RG=/home/share/tools/refs/Aegilops_tauschii_strangulata_AL8-78_v4.0.fa

### *****************  OTHER GENOMES  ******************************************************************************************************
### First draft of the rye genome http://onlinelibrary.wiley.com/doi/10.1111/tpj.13436/full   "Secale_cereale_Lo7_v2_ordered.fa"
#RG=/home/share/tools/refs/Secale_cereale_Lo7_v2_ordered.fa
### Hessian fly genome (HF, Mayetiola destructor, strain Kansas Great Plain, whole genome shotgun sequencing project. from https://i5k.nal.usda.gov/Mayetiola_destructor = hf_v1.0.merged.genome.fa)
#RG=/home/share/tools/refs/hf_v1.0.merged.genome.fa
### Pearl millet genome (doi:10.1038/nbt.3943) (http://ceg.icrisat.org/ipmgsc/genome.html)
#RG=/home/share/tools/refs/pearl_millet_v1.1.merged.genome.fa
### Barley genome, Hordeum_vulgare.Hv_IBSC_PGSB_v2.dna.all.fa, (ftp://ftp.ensemblgenomes.org/pub/plants/release-38/fasta/hordeum_vulgare/dna/)
#RG=/home/share/tools/refs/Hordeum_vulgare.Hv_IBSC_PGSB_v2.dna.all.fa 
### sugarcane. A mosaic monoploid reference sequence for the highly complex genome of sugarcane https://www.nature.com/articles/s41467-018-05051-5   http://sugarcane-genome.cirad.fr/content/download
#RG=/home/share/tools/refs/sugarcane_stp_v1.0.merged.genome.fa
### Rice genome: "Oryza sativa Japonica, NCBI Oryza sativa Japonica Group Annotation Release 102, 03-August-2018, finished chromosomes (excluded: unplaced, plastids, mitochondrion)" https://ftp.ncbi.nlm.nih.gov/genomes/refseq/plant/Oryza_sativa/latest_assembly_versions/GCF_001433935.1_IRGSP-1.0/GCF_001433935.1_IRGSP-1.0_cds_from_genomic.fna.gz
#RG=/home/share/tools/refs/Rice_Oryza_sativa_Japonica_GCF_001433935.1_IRGSPv1.0_genomic.fa
### Soybean genome: "Soybean, Glycine max, NCBI Glycine max Annotation Release 103, 06-September-2018, finished chromosomes (excluded: unplaced, plastids, mitochondrion)" https://ftp.ncbi.nlm.nih.gov/genomes/refseq/plant/Glycine_max/latest_assembly_versions/GCF_000004515.5_Glycine_max_v2.1/GCF_000004515.5_Glycine_max_v2.1_genomic.fna.gz
#RG=/home/share/tools/refs/Soybean_Glycine_max_GCF_000004515.5_v2.1_genomic.fa
### Corn genome: "Corn, Zea mays, NCBI Zea mays Annotation Release 103, 09-August-2020, finished chromosomes (excluded: unplaced, plastids, mitochondrion)" https://ftp.ncbi.nlm.nih.gov/genomes/refseq/plant/Zea_mays/latest_assembly_versions/GCF_902167145.1_Zm-B73-REFERENCE-NAM-5.0/GCF_902167145.1_Zm-B73-REFERENCE-NAM-5.0_genomic.fna.gz
#RG=/home/share/tools/refs/Corn_Zea_mays_GCF_902167145.1_Zm-B73-REFERENCE-NAMv5.0_genomic.fa
### Sorghum genome: "Sorghum, Sorghum bicolor, NCBI Sorghum bicolor Annotation Release 101, 02-June-2017, finished chromosomes (excluded: unplaced, plastids, mitochondrion)" https://ftp.ncbi.nlm.nih.gov/genomes/refseq/plant/Sorghum_bicolor/latest_assembly_versions/GCF_000003195.3_Sorghum_bicolor_NCBIv3/GCF_000003195.3_Sorghum_bicolor_NCBIv3_genomic.fna.gz
#RG=/home/share/tools/refs/Sorghum_Sorghum_bicolor_GCF_000003195.3_NCBIv3_genomic.fa

### ***************** OUTDATED/OBSOLETE REFS, DO NOT USE THESE ******************************************************************************************************
### 161010_Chinese_Spring_v1.0_pseudomolecules. Version 1 wheat whole genome reference. Use this ref for most purposes, except it cannot by indexed with "samtools index" so that random access to chromosomal regions is not possible. FASTA file with pseudomolecule sequences for the 21 bread wheat chromosomes and one pseudomolecule composed of unanchored scaffolds (chrUn). = 161010_Chinese_Spring_v1.0_pseudomolecules.fasta
#RG=/home/share/tools/refs/161010_Chinese_Spring_v1.0_pseudomolecules.fa
### 161010_Chinese_Spring_v1.0_pseudomolecules_parts. Version 1 wheat whole genome reference. This ref with "samtools index" so that random access to chromosomal regions is possible. FASTA file where the pseudomolecule sequences of each chromosome has been split (at a gap between scaffolds) into two parts each to make the sequence shorter than 512 Mb. The split points were chosen such that the size of part1 of each chromosome is ~450 Mb. = 161010_Chinese_Spring_v1.0_pseudomolecules_parts.fasta
#RG=/home/share/tools/refs/161010_Chinese_Spring_v1.0_pseudomolecules_parts.fa
### Wheat_IWGSC_WGA_v0.4, Chinese_Spring_v0.4_pseudomolecules FASTA file with pseudomolecule sequences for the 21 wheat chromosomes and one pseudomolecule composed of unanchored scaffolds (chrUn). All coordinates are 1-based (as opposed to 0-based as in second column of BED files). = "Wheat_IWGSC_WGA_v0.4_dna_genome.fa"
#RG=/home/share/tools/refs/Wheat_IWGSC_WGA_v0.4_dna_genome.fa
### IWGSC1.0 & popseq version 30, all genomic chromosome segments = "Triticum_aestivum.IWGSC1.0+popseq.30.dna.genome.MergedScaffolds.fa"
#RG=/home/share/tools/refs/Triticum_aestivum.IWGSC1.0+popseq.30.dna.genome.MergedScaffolds.fa
### IWGSC1.0 & popseq version 30, all genomic chromosome segments, repeat masked (repeats and low complexity regions masked by replacing repeats with 'N's) = "Triticum_aestivum.IWGSC1.0+popseq.30.dna_rm.genome.MergedScaffolds.fa"
#RG=/home/share/tools/refs/Triticum_aestivum.IWGSC1.0+popseq.30.dna_rm.genome.MergedScaffolds.fa
### Ref from Gina's lab and is likely identical to the IWGSC_WGA_v0.4 & popseq version 30, all genomic chromosome segments = "Triticum_aestivum.IWGSC1.0+popseq.30.dna.genome.gina.fa"
#RG=/home/share/tools/refs/Triticum_aestivum.IWGSC1.0+popseq.30.dna.genome.gina.fa
### New genome assembly of Chinese Spring, generated by The Genome Analysis Centre with additional RNA-seq data, scaffolds only, has 2X more seq than the IWGSC ref = "Triticum_aestivum.TGACv1.30.dna.genome.MergedScaffolds.fa"
#RG=/home/share/tools/refs/Triticum_aestivum.TGACv1.30.dna.genome.MergedScaffolds.fa
### New genome assembly of Chinese Spring, generated by The Genome Analysis Centre with additional RNA-seq data, scaffolds only, has 2X more seq than the IWGSC ref, repeat masked (repeats and low complexity regions masked by replacing repeats with 'N's) = "Triticum_aestivum.TGACv1.30.dna_rm.genome.MergedScaffolds.fa"
#RG=/home/share/tools/refs/Triticum_aestivum.TGACv1.30.dna_rm.genome.MergedScaffolds.fa
### Whole-genome shotgun of hexaploid wheat Synthetic W7984, from gatersleben.de. The assembly was done with meraculous, this is what we have been using for our imputation pipleline (it seems to be repeat-masked) = "w7984.meraculous.Mar28.MergedScaffolds.fa"
#RG=/home/share/tools/refs/w7984.meraculous.Mar28.MergedScaffolds.fa
### RYE genome assembly from 454 sequences from http://pgsb.helmholtz-muenchen.de/plant/rye/gz/download/ = sc454reads_PGSB_genomeZipper_merged.genome.fa
#RG=/home/share/tools/refs/sc454reads_PGSB_genomeZipper_merged.genome.fa

#Define the Discovery keyfile
# DKF=$WD/RPN+RGON-2021-2022-MRASeq-KEY.txt

DKF=$WD/TXBM21-25-PolyA-KEY.txt

#Define Production keyfile.
# PKF=$WD/RPN+RGON-2021-2022-MRASeq-KEY.txt
PKF=$WD/TXBM21-25-PolyA-KEY.txt

#Define the Enzyme. DO NOT CHANGE THIS UNLESS YOU KNOW WHAT YOU ARE DOING!!!
E=PstI-MspI

#Define the taxafile
# TF=$WD/RPN+RGON-2021-2022-MRASeq-LINES.txt
TF=$WD/TXBM21-25-LINES-3.txt

#Define the Minimum Read Count. GBS tags(or reads?) that do not appear this many times are not used.
# Should be 1 usually. Minimum count of reads for a tag to be output (Default: 1) This is a total of X count ACROSS ALL TAXA, NOT IN EACH INDIVIDUAL!! FOR RILS AND DH IN 2 PARENT POPS, THIS SHOULD BE MIN OF 1 READ FOR HALF OF THE INDIVIDUALS IN POP?????? Example: for 192 lines, an approx 5X read coverage would be 192 x 5 = 960 reads, but they are usually not evenly distributed... Maybe, remove number of weak/bad genotypes before calculation, then subtract 20% (or min locus coverage?) from final??
MRC=1

#Define the Minimum Quality Score. Minimum quality score within the barcode and read length to be accepted (Default: 0).
#KEEP 0 Do NOT use any other value if you have added poly-A to the rightside of the reads.
MQS=0

#Define the Minimum Locus Coverage for SNP calls (proportion of Taxa with a genotype)
#Use 0.2 for 80 % missing genotypes, use 0.8 for 20% missing genotypes. Use lower values to increase the number of SNPs called.
MLC=0.20

#Define the Minimum Minor Allele Frequency for SNP calls. 
#Default 0.01. Lower values alow more SNPs. Set near 0.5 (0.2-0.4) for expected 1:1 pops. Set very low for associtation mapping pops or for any high diversity pop.
MAF=0.001

### User should NOT change anything below this line ***************************
### User should NOT change anything below this line ***************************
### User should NOT change anything below this line ***************************
### User should NOT change anything below this line ***************************

#Define the path to the tassel run_pipeline.pl script.
#If you run short of memory, try changing these throughout: -Xms5g -Xmx50g
#TASSEL=/usr/local/bin/tassel-5-standalone/run_pipeline.pl
TASSEL=$CONDA_PREFIX/bin/run_pipeline.pl            # FOR RUNNING ON TAMU HPRC

#Change into the working directory
cd $WD

#Create TASSEL Working directories
echo
echo "************************************** Tassel Version below:"
$TASSEL -Xms5g -Xmx150g | head -n6 | tail -n3
echo "************************************** Working dir to be used: $WD"
echo "************************************** Study name to be used: $Study"
echo "************************************** Reference to be used: $RG"
echo "************************************** Keyfile to be used: $DKF"
echo "************************************** Production keyfile to be used: $PKF"
echo "************************************** Taxa file to be used: $TF"
echo "************************************** Minimum read count to be used: $MRC"
echo "************************************** Minimum quality score to be used: $MQS"
echo "************************************** Minimum locus coverage to be used: $MLC"
echo "************************************** Minimum minor allele frequency to be used: $MAF"
echo "************************************** Creating TASSEL Working directories"
for file in *.fastq; do
    if [[ -f $file ]]; then
	  echo "************************************** FASTQ files to use:"
	  ls -lag *.fastq
    fi
done

for file in *.fastq.gz; do
    if [[ -f $file ]]; then
	  echo "************************************** FASTQ.gz files to use:"
	  ls -lag *.fastq.gz
    fi
done
date
mkdir -p ./hapmap ./logs ./database ./alignment ./HDF5
echo "Reference to be used: $RG" > ./logs/discovery.log
echo "Working dir to be used: $WD" >> ./logs/discovery.log
echo "Study name to be used: $Study" >> ./logs/discovery.log
echo "Reference to be used: $RG" >> ./logs/discovery.log
echo "Keyfile to be used: $DKF" >> ./logs/discovery.log
echo "Production keyfile to be used: $PKF" >> ./logs/discovery.log
echo "Taxa file to be used: $TF" >> ./logs/discovery.log
echo "Minimum read count to be used: $MRC" >> ./logs/discovery.log
echo "Minimum quality score to be used: $MQS" >> ./logs/discovery.log
echo "Minimum locus coverage to be used: $MLC" >> ./logs/discovery.log
echo "Minimum minor allele frequency to be used: $MAF" >> ./logs/discovery.log
echo "Creating TASSEL Working directories" >> ./logs/discovery.log
date >> ./logs/discovery.log
       
echo "Identify tags and add them to database" >> ./logs/discovery.log
date >> ./logs/discovery.log
echo
echo "************************************** Identify tags and add them to database"
date
$TASSEL -Xms10g -Xmx150g -fork1 -GBSSeqToTagDBPlugin -e $E -i $WD -db ./database/$Study.db -k $DKF -kmerLength 64 -c 5 -mxKmerNum 100000000 -mnQS $MQS -deleteOldData true -batchSize 16 -endPlugin -runfork1 > ./logs/GBSSeqToTagDBPlugin.log

echo "Retrieve distinct tags from database and reformat to .fq" >> ./logs/discovery.log
echo
echo "************************************** Retrieve distinct tags from database and reformat to .fq"
date
date >> ./logs/discovery.log
$TASSEL -Xms10g -Xmx150g -fork1 -TagExportToFastqPlugin -c $MRC -db database/$Study.db -o alignment/$Study\_MasterGBStags.fa.gz -endPlugin -runfork1 > ./logs/TagExportToFastqPlugin.log

echo "Align the tags to the reference genome using BWA" >> ./logs/discovery.log
echo
echo "************************************** Align the tags to the reference genome using BWA"
date
date >> ./logs/discovery.log
bwa aln -t 24 $RG alignment/$Study\_MasterGBStags.fa.gz > alignment/$Study\_AlignedMasterTags.sai

echo "Convert the .sai file to a .sam file" >> ./logs/discovery.log
echo
echo "************************************** Convert the .sai file to a .sam file"
date
date >> ./logs/discovery.log
bwa samse $RG alignment/$Study\_AlignedMasterTags.sai alignment/$Study\_MasterGBStags.fa.gz > alignment/$Study\_AlignedMasterTags.sam

echo "Read SAM file to determine potential positions of Tags against Ref Genome" >> ./logs/discovery.log
echo
echo "************************************** Read SAM file to determine potential positions of Tags against Ref Genome"
date
date >> ./logs/discovery.log
$TASSEL -Xms10g -Xmx150g -fork1 -SAMToGBSdbPlugin -i alignment/$Study\_AlignedMasterTags.sam -db database/$Study.db -aLen 0 -aProp 0.0 -endPlugin -runfork1 > ./logs/SAMToGBSdbPlugin.log

echo "Call SNPs" >> ./logs/discovery.log
echo
echo "************************************** Call SNPs"
date
date >> ./logs/discovery.log
$TASSEL -Xms10g -Xmx150g -fork1 -DiscoverySNPCallerPluginV2 -db database/$Study.db -mnMAF $MAF -mnLCov $MLC -deleteOldData true -endPlugin -runfork1 > ./logs/DiscoverySNPCallerPluginV2.log

echo "Score SNPs" >> ./logs/discovery.log
echo
echo "************************************** Score SNPs"
date
date >> ./logs/discovery.log
$TASSEL -Xms10g -Xmx150g -fork1 -SNPQualityProfilerPlugin -db database/$Study.db -taxa $TF -tname "MNS_uniqueTaxa" -statFile "outputStats_uniqueTaxa.txt" -deleteOldData true -endPlugin -runfork1 > ./logs/SNPQualityProfilerPlugin.log

echo "Output HDF5 genotypes file" >> ./logs/discovery.log
echo
echo "************************************** Output HDF5 genotypes file"
date
date >> ./logs/discovery.log
$TASSEL -Xms10g -Xmx150g -fork1 -ProductionSNPCallerPluginV2 -db database/$Study.db -e $E -i $WD -k $PKF -kmerLength 64 -o HDF5/$Study\_productioHapMap_noKO.h5 -do true -batchSize 16 -endPlugin -runfork1 > ./logs/ProductionSNPCallerPluginV2.log

echo "Output VCF from HDF5" >> ./logs/discovery.log
echo
echo "************************************** Output VCF from HDF5"
date
date >> ./logs/discovery.log
$TASSEL -Xms10g -Xmx150g -fork1 -h5 HDF5/$Study\_productioHapMap_noKO.h5 -filterAlign -filterAlignMinFreq $MAF -filterAlignRemMinor -export ./hapmap/$Study.vcf -exportType VCF -runfork1 > ./logs/VCFFromHDF5.log

echo "Output Hapmap from HDF5" >> ./logs/discovery.log
echo
echo "************************************** Output Hapmap from HDF5"
date
date >> ./logs/discovery.log
$TASSEL -Xms10g -Xmx150g -h5 HDF5/$Study\_productioHapMap_noKO.h5 -filterAlign -filterAlignMinFreq $MAF -filterAlignRemMinor -export hapmap/$Study.hmp.txt -exportType Hapmap > ./logs/HapmapFromHDF5.log

echo "Output genotype summary files" >> ./logs/discovery.log
echo
echo "************************************** Output genotype summary files"
date
date >> ./logs/discovery.log
$TASSEL -Xms10g -Xmx150g -h5 HDF5/$Study\_productioHapMap_noKO.h5  -filterAlign -filterAlignMinFreq $MAF -filterAlignRemMinor -GenotypeSummaryPlugin -endPlugin -export summary

echo "Script finished at:" >> ./logs/discovery.log
date >> ./logs/discovery.log
echo
echo "************************************** Script finished at:"
date
