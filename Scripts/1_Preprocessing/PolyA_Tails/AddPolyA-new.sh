#!/bin/bash
# NOTE: FILE MUST BE A UNIX FILE TYPE.
# NOTE: CALL THIS SCRIPT WITH THE FILENAME ON COMMANDLINE! ./AddPolyA-illumina.sh SampleFile.fastq
# NOTE: RUN THIS SCRIPT ON EACH FASTQ FILE.

begin=$(date +%s) 
echo ""
echo "************************************************************************************************"
echo "******  Creating a new file: AAAA-$1"
echo "******  Adding 80 poly-A bases to the right, 3' end, of each read from file: $1"
echo "******  Depending on file size, this will take a few minutes. Please wait..."
echo "******  Script started at:"
date
echo  "************************************************************************************************"


### Add 80 poly-A bases to the right, 3' end, of each read
sed '2~4s/$/AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA/' $1 > AAAA-$1

atime=$(date +%s)
midtime=$(expr $atime - $begin)
midminutes=$(expr $midtime / 60)

echo "******  This file took about $midminutes minutes to convert to poly-A."
echo "******  Counting reads."
echo "************************************************************************************************"

# count number of lines in AAAA-fastq. NOTE: wc will output count and filename
WcOutput=($(wc -l AAAA-$1))
#get ONLY linecount from WcOutput
NumLines=${WcOutput[0]}
#divide number of lines by 4 to get read count
TotReads=$((NumLines/4))

printf "Total number of reads: %'d\n" $TotReads

#Note: PstI site CTGCA^G modified upon ligation into: GATTGCA^G
#Note: MspI site C^CGG modified upon ligation into: C^CGAGAT


finish=$(date +%s)
tottime=$(expr $finish - $begin)
minutes=$(expr $tottime / 60)

echo "************************************************************************************************"
echo "******  File AAAA-$1 is ready for use."
echo "******  This script took about $minutes minutes."
echo "******  WARNING: Quality string in fastq has NOT been addjusted for new seq length."
echo "************************************************************************************************"
echo ""
date
