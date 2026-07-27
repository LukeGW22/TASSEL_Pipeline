#!/bin/bash
#===============================================================================
# TASSEL 5 GBS v2 SNP Calling Pipeline (Refactored)
# 
# Decoupled input/output structure for TAMU HPRC Grace cluster.
# Based on Tassel5GBSv2_pipeline_Paulv3 with path reorganization.
#
# Usage: nohup ./TXBM21-26_TASSEL_GBS_Pipeline.sh 2>&1 | tee pipeline.log
#===============================================================================

set -euo pipefail  # Exit on error, undefined vars, pipe failures

#-------------------------------------------------------------------------------
# CONFIGURATION: sourced from config.env (copy from config.env.template)
#-------------------------------------------------------------------------------

CONFIG_FILE="${PROJECT_ROOT:-$(dirname "$(dirname "$(dirname "$0")")")}/config.env"
if [[ ! -f "${CONFIG_FILE}" ]]; then
    echo "ERROR: config.env not found at: ${CONFIG_FILE}"
    echo "       Copy config.env.template → config.env and fill in values."
    exit 1
fi
# shellcheck source=/dev/null
source "${CONFIG_FILE}"

# Alias STUDY → Study for internal use
Study="${STUDY}"

#-------------------------------------------------------------------------------
# DERIVED PATHS (no need to edit)
#-------------------------------------------------------------------------------

# TASSEL executable
TASSEL="${CONDA_PREFIX}/bin/run_pipeline.pl"

# Output subdirectories
HAPMAP_DIR="${OUTPUT_DIR}/hapmap"
LOGS_DIR="${OUTPUT_DIR}/logs"
DB_DIR="${OUTPUT_DIR}/database"
ALIGN_DIR="${OUTPUT_DIR}/alignment"
HDF5_DIR="${OUTPUT_DIR}/HDF5"
STATS_DIR="${OUTPUT_DIR}/stats"
SUMMARY_DIR="${OUTPUT_DIR}/summaries"

# Database and output files
DB_FILE="${DB_DIR}/${Study}.db"
H5_FILE="${HDF5_DIR}/${Study}_productionHapMap.h5"

#-------------------------------------------------------------------------------
# HELPER FUNCTIONS
#-------------------------------------------------------------------------------

log() {
    local msg="$1"
    local timestamp
    timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    echo "[${timestamp}] ${msg}"
    echo "[${timestamp}] ${msg}" >> "${LOGS_DIR}/discovery.log"
}

step() {
    local msg="$1"
    echo ""
    echo "======================================================================"
    log "${msg}"
    echo "======================================================================"
}

validate_paths() {
    local errors=0
    
    log "Validating input paths..."
    
    [[ -d "${DATA_ROOT}" ]] || { log "ERROR: DATA_ROOT not found: ${DATA_ROOT}"; ((++errors)); }
    [[ -d "${FASTQ_DIR}" ]] || { log "ERROR: FASTQ_DIR not found: ${FASTQ_DIR}"; ((++errors)); }
    [[ -d "${REF_GENOME_DIR}" ]] || { log "ERROR: REF_GENOME_DIR not found: ${REF_GENOME_DIR}"; ((++errors)); }
    [[ -f "${RG}" ]] || { log "ERROR: Reference genome not found: ${RG}"; ((++errors)); }
    [[ -f "${RG}.bwt" ]] || { log "ERROR: BWA index not found for: ${RG}"; ((++errors)); }
    [[ -f "${DKF}" ]] || { log "ERROR: Discovery keyfile not found: ${DKF}"; ((++errors)); }
    [[ -f "${PKF}" ]] || { log "ERROR: Production keyfile not found: ${PKF}"; ((++errors)); }
    [[ -f "${TF}" ]] || { log "ERROR: Taxa file not found: ${TF}"; ((++errors)); }
    
    # Check for FASTQ files
    local fastq_count
    fastq_count=$(find "${FASTQ_DIR}" -maxdepth 1 \( -name "*.fastq" -o -name "*.fastq.gz" \) 2>/dev/null | wc -l)
    [[ ${fastq_count} -gt 0 ]] || { log "ERROR: No FASTQ files found in: ${FASTQ_DIR}"; ((++errors)); }
    
    if [[ ${errors} -gt 0 ]]; then
        log "Validation failed with ${errors} error(s). Exiting."
        exit 1
    fi
    
    log "All paths validated successfully."
}

print_config() {
    log "Configuration Summary:"
    echo "  Study:              ${Study}"
    echo "  DATA_ROOT:          ${DATA_ROOT}"
    echo "  PROJECT_ROOT:       ${PROJECT_ROOT}"
    echo "  FASTQ_DIR:          ${FASTQ_DIR}"
    echo "  Reference:          ${RG}"
    echo "  Discovery keyfile:  ${DKF}"
    echo "  Production keyfile: ${PKF}"
    echo "  Taxa file:          ${TF}"
    echo "  Output directory:   ${OUTPUT_DIR}"
    echo "  Min read count:     ${MIN_READ_COUNT}"
    echo "  Min quality score:  ${MIN_QUALITY_SCORE}"
    echo "  Min locus coverage: ${MIN_LOCUS_COVERAGE}"
    echo "  Min MAF:            ${MIN_MINOR_ALLELE_FREQ}"
    
    # List FASTQ files
    echo ""
    echo "  FASTQ files found:"
    if [[ -d "${FASTQ_DIR}" ]]; then
        find "${FASTQ_DIR}" -maxdepth 1 \( -name "*.fastq" -o -name "*.fastq.gz" \) -exec basename {} \; | head -10 | sed 's/^/    /'
        local count
        count=$(find "${FASTQ_DIR}" -maxdepth 1 \( -name "*.fastq" -o -name "*.fastq.gz" \) | wc -l)
        if [[ ${count} -gt 10 ]]; then echo "    ... and $((count - 10)) more"; fi
    else
        echo "    ✘ FASTQ_DIR does not exist: ${FASTQ_DIR}"
    fi
}

#-------------------------------------------------------------------------------
# PIPELINE STAGES
#-------------------------------------------------------------------------------

stage_init() {
    step "Initializing pipeline"
    
    # Create output directories
    mkdir -p "${HAPMAP_DIR}" "${LOGS_DIR}" "${DB_DIR}" "${ALIGN_DIR}" "${HDF5_DIR}" "${STATS_DIR}" "${SUMMARY_DIR}"
    
    # Initialize log
    echo "# TASSEL GBS Pipeline Log - ${Study}" > "${LOGS_DIR}/discovery.log"
    echo "# Started: $(date)" >> "${LOGS_DIR}/discovery.log"
    
    # Print TASSEL version
    log "TASSEL Version:"
    ${TASSEL} -Xms1g -Xmx4g 2>&1 | head -n6 | tail -n3 || true
    
    print_config
}

stage_1_tag_discovery() {
    step "Stage 1: Identify tags and add to database"
    
    ${TASSEL} -Xms${JAVA_MIN_MEM} -Xmx${JAVA_MAX_MEM} \
        -fork1 -GBSSeqToTagDBPlugin \
        -e "${ENZYME}" \
        -i "${FASTQ_DIR}" \
        -db "${DB_FILE}" \
        -k "${DKF}" \
        -kmerLength 64 \
        -c 5 \
        -mxKmerNum 100000000 \
        -mnQS ${MIN_QUALITY_SCORE} \
        -deleteOldData true \
        -batchSize 16 \
        -endPlugin -runfork1 \
        > "${LOGS_DIR}/01_GBSSeqToTagDBPlugin.log" 2>&1
    
    log "Tag discovery complete."
}

stage_2_tag_export() {
    step "Stage 2: Export distinct tags to FASTA"
    
    ${TASSEL} -Xms${JAVA_MIN_MEM} -Xmx${JAVA_MAX_MEM} \
        -fork1 -TagExportToFastqPlugin \
        -c ${MIN_READ_COUNT} \
        -db "${DB_FILE}" \
        -o "${ALIGN_DIR}/${Study}_MasterGBStags.fa.gz" \
        -endPlugin -runfork1 \
        > "${LOGS_DIR}/02_TagExportToFastqPlugin.log" 2>&1
    
    log "Tag export complete."
}

stage_3_bwa_align() {
    step "Stage 3: Align tags to reference genome (BWA)"
    
    log "Running BWA aln..."
    bwa aln -t ${BWA_THREADS} \
        "${RG}" \
        "${ALIGN_DIR}/${Study}_MasterGBStags.fa.gz" \
        > "${ALIGN_DIR}/${Study}_AlignedMasterTags.sai" \
        2> "${LOGS_DIR}/03a_bwa_aln.log"
    
    log "Running BWA samse..."
    bwa samse \
        "${RG}" \
        "${ALIGN_DIR}/${Study}_AlignedMasterTags.sai" \
        "${ALIGN_DIR}/${Study}_MasterGBStags.fa.gz" \
        > "${ALIGN_DIR}/${Study}_AlignedMasterTags.sam" \
        2> "${LOGS_DIR}/03b_bwa_samse.log"
    
    log "BWA alignment complete."
}

stage_4_sam_to_db() {
    step "Stage 4: Import SAM alignments to database"
    
    ${TASSEL} -Xms${JAVA_MIN_MEM} -Xmx${JAVA_MAX_MEM} \
        -fork1 -SAMToGBSdbPlugin \
        -i "${ALIGN_DIR}/${Study}_AlignedMasterTags.sam" \
        -db "${DB_FILE}" \
        -aLen 0 \
        -aProp 0.0 \
        -endPlugin -runfork1 \
        > "${LOGS_DIR}/04_SAMToGBSdbPlugin.log" 2>&1
    
    log "SAM import complete."
}

stage_5_snp_discovery() {
    step "Stage 5: Discover SNPs"
    
    ${TASSEL} -Xms${JAVA_MIN_MEM} -Xmx${JAVA_MAX_MEM} \
        -fork1 -DiscoverySNPCallerPluginV2 \
        -db "${DB_FILE}" \
        -mnMAF ${MIN_MINOR_ALLELE_FREQ} \
        -mnLCov ${MIN_LOCUS_COVERAGE} \
        -deleteOldData true \
        -endPlugin -runfork1 \
        > "${LOGS_DIR}/05_DiscoverySNPCallerPluginV2.log" 2>&1
    
    log "SNP discovery complete."
}

stage_6_snp_quality() {
    step "Stage 6: Score SNP quality"
    
    ${TASSEL} -Xms${JAVA_MIN_MEM} -Xmx${JAVA_MAX_MEM} \
        -fork1 -SNPQualityProfilerPlugin \
        -db "${DB_FILE}" \
        -taxa "${TF}" \
        -tname "${Study}_uniqueTaxa" \
        -statFile "${STATS_DIR}/outputStats_uniqueTaxa.txt" \
        -deleteOldData true \
        -endPlugin -runfork1 \
        > "${LOGS_DIR}/06_SNPQualityProfilerPlugin.log" 2>&1
    
    log "SNP quality profiling complete."
}

stage_7_production_snps() {
    step "Stage 7: Production SNP calling (HDF5 output)"
    
    ${TASSEL} -Xms${JAVA_MIN_MEM} -Xmx${JAVA_MAX_MEM} \
        -fork1 -ProductionSNPCallerPluginV2 \
        -db "${DB_FILE}" \
        -e "${ENZYME}" \
        -i "${FASTQ_DIR}" \
        -k "${PKF}" \
        -kmerLength 64 \
        -o "${H5_FILE}" \
        -do true \
        -batchSize 16 \
        -endPlugin -runfork1 \
        > "${LOGS_DIR}/07_ProductionSNPCallerPluginV2.log" 2>&1
    
    log "Production SNP calling complete."
}

stage_8_export_vcf() {
    step "Stage 8: Export VCF from HDF5"
    
    ${TASSEL} -Xms${JAVA_MIN_MEM} -Xmx${JAVA_MAX_MEM} \
        -fork1 \
        -h5 "${H5_FILE}" \
        -filterAlign \
        -filterAlignMinFreq ${MIN_MINOR_ALLELE_FREQ} \
        -filterAlignRemMinor \
        -export "${HAPMAP_DIR}/${Study}.vcf" \
        -exportType VCF \
        -runfork1 \
        > "${LOGS_DIR}/08_VCFFromHDF5.log" 2>&1
    
    log "VCF export complete: ${HAPMAP_DIR}/${Study}.vcf"
}

stage_9_export_hapmap() {
    step "Stage 9: Export HapMap from HDF5"
    
    ${TASSEL} -Xms${JAVA_MIN_MEM} -Xmx${JAVA_MAX_MEM} \
        -h5 "${H5_FILE}" \
        -filterAlign \
        -filterAlignMinFreq ${MIN_MINOR_ALLELE_FREQ} \
        -filterAlignRemMinor \
        -export "${HAPMAP_DIR}/${Study}.hmp.txt" \
        -exportType Hapmap \
        > "${LOGS_DIR}/09_HapmapFromHDF5.log" 2>&1
    
    log "HapMap export complete: ${HAPMAP_DIR}/${Study}.hmp.txt"
}

stage_10_genotype_summary() {
    step "Stage 10: Generate genotype summary"
    
    ${TASSEL} -Xms${JAVA_MIN_MEM} -Xmx${JAVA_MAX_MEM} \
        -h5 "${H5_FILE}" \
        -filterAlign \
        -filterAlignMinFreq ${MIN_MINOR_ALLELE_FREQ} \
        -filterAlignRemMinor \
        -GenotypeSummaryPlugin \
        -endPlugin \
        -export "${SUMMARY_DIR}/${Study}_summary" \
        > "${LOGS_DIR}/10_GenotypeSummary.log" 2>&1
    
    log "Genotype summary complete."
}

print_summary() {
    step "Pipeline Complete"
    
    log "Output files:"
    echo "  VCF:      ${HAPMAP_DIR}/${Study}.vcf"
    echo "  HapMap:   ${HAPMAP_DIR}/${Study}.hmp.txt"
    echo "  HDF5:     ${H5_FILE}"
    echo "  Database: ${DB_FILE}"
    echo "  Stats:    ${STATS_DIR}/outputStats_uniqueTaxa.txt"
    echo "  Logs:     ${LOGS_DIR}/"
    
    # Count markers if hapmap exists
    if [[ -f "${HAPMAP_DIR}/${Study}.hmp.txt" ]]; then
        local marker_count
        marker_count=$(wc -l < "${HAPMAP_DIR}/${Study}.hmp.txt")
        log "Total markers in HapMap: $((marker_count - 1))"
    fi
    
    log "Pipeline finished at: $(date)"
}

#-------------------------------------------------------------------------------
# MAIN
#-------------------------------------------------------------------------------

main() {
    stage_init
    validate_paths
    
    stage_1_tag_discovery
    stage_2_tag_export
    stage_3_bwa_align
    stage_4_sam_to_db
    stage_5_snp_discovery
    stage_6_snp_quality
    stage_7_production_snps
    stage_8_export_vcf
    stage_9_export_hapmap
    stage_10_genotype_summary
    
    print_summary
}

# Run pipeline
main "$@"
