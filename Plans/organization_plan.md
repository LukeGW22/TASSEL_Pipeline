# Plan: Git Setup for TXBM21-26 on Grace HPRC

Set up local git on Grace at `/scratch/group/genomic_predict/SNP_Calling/TXBM21-26` with a comprehensive `.gitignore` to exclude data files and SLURM outputs. Reorganize workflow to prevent the chaos from TXBM21-25: centralized logs, single script location, config-based parameters, and path variables.

---

## Phase 1: Directory Structure Setup

1. **Create organized directory structure on Grace:**
   ```
   TXBM21-26/
   ├── Scripts/           # ALL scripts live here (single source of truth)
   │   ├── 1_Preprocessing/
   │   ├── 2_SNPCalling/
   │   ├── 3_Filtering/
   │   └── 4_Imputation/
   ├── Config/            # Parameter files (YAML/JSON)
   ├── Logs/              # ALL job outputs go here
   │   └── YYYY-MM-DD/    # Organized by date
   ├── GBS_Metadata/      # Key files, line files
   ├── Data/              # Large data (gitignored)
   └── Results/           # Final outputs (gitignored)
   ```

2. **Modify SLURM scripts to redirect outputs to Logs/ with timestamps** *(depends on 1)*

## Phase 2: Git Initialization

3. **Initialize git repository** *(parallel with 4)*
4. **Create comprehensive .gitignore** *(parallel with 3)* — exclude `*.fastq*`, `*.vcf*`, `*.h5`, `slurm-*.out`, `*.stdout`, `*.stderr`, `Data/`, `Results/`
5. **Initial commit** *(depends on 3, 4)*

## Phase 3: Workflow Improvements

6. **Create `config.env` for path variables** — `PROJECT_ROOT`, `REF_GENOME`, `KEY_FILE`, `FASTQ_DIR`; all scripts source this instead of hardcoding
7. **Create `Config/params.yaml` for run parameters** — MLC, MAF thresholds; scripts read from config
8. **Update SLURM templates** *(depends on 6, 7)* — source config.env, redirect outputs to `Logs/$(date +%Y-%m-%d)/`

## Phase 4: Documentation

9. **Create README.md** — directory structure, how to run each stage, where data lives

---

## Relevant Files

- `setup_git.sh` — Will contain git init commands
- `SNP_Pipeline/1_SNPCalling/` — Existing scripts to update/migrate
- `SNP_Pipeline/.gitignore` — Base to expand

## Verification

1. `git status` shows only Scripts/, Config/, GBS_Metadata/, README.md tracked
2. After test job, stdout/stderr appear in `Logs/YYYY-MM-DD/`
3. `grep -r "/scratch/group"` in Scripts/ returns nothing (all use `$PROJECT_ROOT`)

---

## Further Considerations

1. **Run naming?** Dated logs work, but consider also `run_001_MLC30_MAF04/` subdirs for parameter variation tracking
2. **Backup?** Scratch has no backup — periodic `git bundle create backup.bundle --all` to `$WORK` or `$HOME`?
