# Plan: Refactor TASSEL Pipeline for External Data Directories

## TL;DR
Refactor the TASSEL GBS pipeline script to decouple input data sources (FASTQ, reference genomes, metadata) from output locations, consolidating all pipeline outputs into `TASSEL_Workflow_Outputs/`. This requires adding new path variables and updating ~15 command invocations.

---

## Current State Analysis

### Current Script Assumptions
The script assumes a flat "working directory" (`$WD`) containing:
- **Inputs:** FASTQ files, reference genome, key files, taxa files
- **Outputs:** All subdirectories created within $WD

### Inputs That Need Relocation
| Input Type | Current Location | Proposed Variable | Example Path |
|------------|------------------|-------------------|--------------|
| Raw FASTQ files | `$WD/*.fastq(.gz)` | — | `$DATA_ROOT/Raw_genomic_data/Breeding_Lines/FASTQ/` |
| Poly-A FASTQ files | `$WD/*.fastq(.gz)` | `$FASTQ_DIR` | `$DATA_ROOT/PolyA_FASTQ/` |
| Reference genome | `$WD/iwgsc_*.fa` | `$REF_GENOME_DIR` | `$DATA_ROOT/Reference_Genomes/` |
| Key files | `$WD/*.txt` | `$METADATA_DIR` | `$PROJECT_ROOT/GBS_Metadata/` |
| Taxa/LINES files | `$WD/*.txt` | `$METADATA_DIR` | `$PROJECT_ROOT/GBS_Metadata/` |

### Outputs to Consolidate into `TASSEL_Workflow_Outputs/`
| Output | Current Path | New Path |
|--------|--------------|----------|
| HapMap files | `$WD/hapmap/` | `$OUTPUT_DIR/hapmap/` |
| Log files | `$WD/logs/` | `$OUTPUT_DIR/logs/` |
| Database | `$WD/database/` | `$OUTPUT_DIR/database/` |
| Alignment files | `$WD/alignment/` | `$OUTPUT_DIR/alignment/` |
| HDF5 genotypes | `$WD/HDF5/` | `$OUTPUT_DIR/HDF5/` |
| SNP stats | `$WD/outputStats_uniqueTaxa.txt` | `$OUTPUT_DIR/stats/` |
| Summary files | `$WD/summary*.txt` | `$OUTPUT_DIR/summaries/` |

---

## Steps

### Phase 1: Define New Path Variables (lines ~55-70)

1. **Add root directory variables** after existing definitions:
   ```bash
   # Root directories (adjust for HPRC: DATA_ROOT=$SCRATCH, PROJECT_ROOT=$WORK)
   DATA_ROOT=/path/to/Data              # Large immutable data (FASTQ, refs)
   PROJECT_ROOT=/path/to/Project        # Project working files
   
   # Input directories (under DATA_ROOT)
   FASTQ_DIR=$DATA_ROOT/PolyA_FASTQ                    # Poly-A processed FASTQ files
   REF_GENOME_DIR=$DATA_ROOT/Reference_Genomes         # Reference genomes + BWA index
   
   # Metadata directory (under PROJECT_ROOT, version-controlled)
   METADATA_DIR=$PROJECT_ROOT/GBS_Metadata
   
   # Output directory (all outputs consolidated here)
   OUTPUT_DIR=$PROJECT_ROOT/TASSEL_Workflow_Outputs
   ```

2. **Update existing variables to use new paths:**
   - `RG=$REF_GENOME_DIR/iwgsc_refseqv2.1_assembly.fa`
   - `DKF=$METADATA_DIR/TXBM21-26_KEY-20260724_210705.txt` (or use symlink `current_key.txt`)
   - `PKF=$METADATA_DIR/TXBM21-26_KEY-20260724_210705.txt`
   - `TF=$METADATA_DIR/TXBM21-26_LINES-20260724_210705.txt`

3. **Optional: Create symlinks for timestamped metadata** (avoids hardcoding dates):
   ```bash
   ln -sf TXBM21-26_KEY-20260724_210705.txt $METADATA_DIR/current_key.txt
   ln -sf TXBM21-26_LINES-20260724_210705.txt $METADATA_DIR/current_lines.txt
   # Then use: DKF=$METADATA_DIR/current_key.txt
   ```

### Phase 2: Update Output Directory Creation (line ~183)

3. **Change `mkdir` command:**
   ```bash
   mkdir -p $OUTPUT_DIR/{hapmap,logs,database,alignment,HDF5,stats,summaries}
   ```

### Phase 3: Update TASSEL Plugin Commands

4. **GBSSeqToTagDBPlugin** (line ~198) — change:
   - `-i $WD` → `-i $FASTQ_DIR` (read FASTQ from input dir)
   - `-db ./database/` → `-db $OUTPUT_DIR/database/`
   - Redirect log to `$OUTPUT_DIR/logs/`

5. **TagExportToFastqPlugin** (line ~205) — change:
   - `-db database/` → `-db $OUTPUT_DIR/database/`
   - `-o alignment/` → `-o $OUTPUT_DIR/alignment/`

6. **BWA alignment commands** (lines ~211-218) — change:
   - All `alignment/` → `$OUTPUT_DIR/alignment/`

7. **SAMToGBSdbPlugin** (line ~223) — change:
   - `-i alignment/` → `-i $OUTPUT_DIR/alignment/`
   - `-db database/` → `-db $OUTPUT_DIR/database/`

8. **DiscoverySNPCallerPluginV2** (line ~229) — change:
   - `-db database/` → `-db $OUTPUT_DIR/database/`

9. **SNPQualityProfilerPlugin** (line ~235) — change:
   - `-db database/` → `-db $OUTPUT_DIR/database/`
   - `-statFile "outputStats_uniqueTaxa.txt"` → `-statFile "$OUTPUT_DIR/stats/outputStats_uniqueTaxa.txt"`

10. **ProductionSNPCallerPluginV2** (line ~241) — change:
    - `-db database/` → `-db $OUTPUT_DIR/database/`
    - `-i $WD` → `-i $FASTQ_DIR`
    - `-o HDF5/` → `-o $OUTPUT_DIR/HDF5/`

11. **VCF export** (line ~247) — change:
    - `-h5 HDF5/` → `-h5 $OUTPUT_DIR/HDF5/`
    - `-export ./hapmap/` → `-export $OUTPUT_DIR/hapmap/`

12. **HapMap export** (line ~253) — change:
    - Same pattern as VCF export

13. **GenotypeSummaryPlugin** (line ~259) — change:
    - `-export summary` → `-export $OUTPUT_DIR/summaries/summary`

### Phase 4: Update Log Redirection

14. **Update all log file redirects** throughout script:
    - `> ./logs/*.log` → `> $OUTPUT_DIR/logs/*.log`
    - `>> ./logs/discovery.log` → `>> $OUTPUT_DIR/logs/discovery.log`

### Phase 5: Update Echo Statements and Validation

15. **Update validation echo statements** (lines ~170-180) to show new paths
16. **Update FASTQ file detection loop** (lines ~165-175):
    ```bash
    for file in $FASTQ_DIR/*.fastq; do
    ```

---

## Relevant Files

- [TXBM21-25_Tassel5GBSv2_pipeline_Paulv3-scratch.sh](SNP_Pipeline/1_SNPCalling/TXBM21-25_Tassel5GBSv2_pipeline_Paulv3-scratch.sh) — Main script to modify
- [organization_plan.md](organization_plan.md) — Existing directory structure plan (aligns with this work)
- [FASTQ_Metadata/](SNP_Pipeline/FASTQ_Metadata/) — Key/Lines files location

---

## Verification

1. **Check paths resolve:** Before running, add validation:
   ```bash
   [[ -d "$DATA_ROOT" ]] || { echo "DATA_ROOT not found: $DATA_ROOT"; exit 1; }
   [[ -d "$PROJECT_ROOT" ]] || { echo "PROJECT_ROOT not found: $PROJECT_ROOT"; exit 1; }
   [[ -d "$FASTQ_DIR" ]] || { echo "FASTQ_DIR not found: $FASTQ_DIR"; exit 1; }
   [[ -f "$RG" ]] || { echo "Reference genome not found: $RG"; exit 1; }
   [[ -f "$DKF" ]] || { echo "Key file not found: $DKF"; exit 1; }
   [[ -f "$TF" ]] || { echo "Taxa file not found: $TF"; exit 1; }
   ```
2. **Dry-run with echo:** Add `-Dry` flag to print commands without executing
3. **Verify output structure:** After run, confirm `TASSEL_Workflow_Outputs/` contains all 7 subdirectories with expected files
4. **Compare SNP counts:** If re-running existing data, compare `hapmap/*.hmp.txt` line counts to previous runs

---

## Decisions

- **Two-root structure:** `$DATA_ROOT` for large immutable data (FASTQ, refs), `$PROJECT_ROOT` for project files. On HPRC Grace: `DATA_ROOT=$SCRATCH`, `PROJECT_ROOT=$WORK` for different retention policies.
- **FASTQ location:** Script reads from `$FASTQ_DIR`, so poly-A processing must happen BEFORE running this script (or use a separate preprocessing step)
- **Working directory:** `$WD` can be removed or set to `$PROJECT_ROOT` — no longer needs to contain input files
- **Reference genome indexing:** BWA index files (`*.bwt`, `*.pac`, etc.) must exist alongside reference in `$REF_GENOME_DIR`
- **Timestamped metadata:** Use symlinks (`current_key.txt` → timestamped file) to avoid hardcoding dates in script

---

## Directory Structure (Proposed)

```
$DATA_ROOT/                           # On HPRC: $SCRATCH (90-day purge)
├── Raw_genomic_data/
│   └── Breeding_Lines/
│       └── FASTQ/                    # Original FASTQ files
├── PolyA_FASTQ/                      # Poly-A processed FASTQ (INPUT)
├── Reference_Genomes/                # Reference genome + BWA index (INPUT)
│   ├── iwgsc_refseqv2.1_assembly.fa
│   ├── iwgsc_refseqv2.1_assembly.fa.bwt
│   ├── iwgsc_refseqv2.1_assembly.fa.pac
│   ├── iwgsc_refseqv2.1_assembly.fa.ann
│   ├── iwgsc_refseqv2.1_assembly.fa.amb
│   └── iwgsc_refseqv2.1_assembly.fa.sa

$PROJECT_ROOT/                        # On HPRC: $WORK (longer retention)
├── GBS_Metadata/                     # Key and Lines files (INPUT)
│   ├── TXBM21-26_KEY-20260724_210705.txt
│   ├── TXBM21-26_LINES-20260724_210705.txt
│   ├── current_key.txt -> TXBM21-26_KEY-20260724_210705.txt
│   └── current_lines.txt -> TXBM21-26_LINES-20260724_210705.txt
└── TASSEL_Workflow_Outputs/          # ALL OUTPUTS GO HERE
    ├── hapmap/                       # Final HapMap/VCF files
    ├── logs/                         # All TASSEL logs
    ├── database/                     # SQLite database
    ├── alignment/                    # SAM/SAI files
    ├── HDF5/                         # HDF5 genotype files
    ├── stats/                        # SNP quality stats
    └── summaries/                    # Genotype summary files
```
