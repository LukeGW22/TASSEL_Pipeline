import marimo

__generated_with = "0.23.15"
app = marimo.App(width="medium")

with app.setup:
    import marimo as mo
    import pandas as pd
    import os
    from datetime import datetime

    import sys
    sys.path.insert(0, "/home/lgw/TAMU/TXBM21-26/SNP_Pypeline/genotype_synonymizer")

    from genotype_synonymizer import GenotypeSynonymizer


@app.cell
def _():
    # define population prefix
    pop_prefix = "TXBM21-26"
    return (pop_prefix,)


@app.cell(hide_code=True)
def _():
    mo.md(r"""
    # Synonymize Lines File
    """)
    return


@app.cell
def _(pop_prefix):
    lines_synkey = "/home/lgw/TAMU/TXBM21-26/SNP_Pypeline/genotype_synonymizer/GenoSynonimizer-KEY.txt"
    lines_path = "./0_FASTQ_Metadata/Updated Line Files/TXBM21-26_LINES-20260724_210705.txt"
    LINES_OUT_DIR = "./0_FASTQ_Metadata/Updated Line Files"

    # initialize synonymizer
    line_synonymizer = GenotypeSynonymizer(
        key_file             = lines_synkey,
        trial_file           = None,
        genotype_id_input    = lines_path,
        key_cultivar_col     = "Cultivar_Name",
        key_experimental_col = "Experimental_Name",
        key_preferred_col    = "Preferred_Name",
        geno_id_col          = "<NAME>",   # header in the LINES file
    )


    # 1. read in file to edit
    lines = pd.read_table(lines_path)

    # 2. synonymize lines
    synonymized_lines = line_synonymizer.standardize_names(df=lines, name_col="<NAME>", new_col="<SYN_NAMES>")
    synonymized_lines = synonymized_lines.drop("<NAME>", axis=1).rename(columns={"<SYN_NAMES>":"<NAME>"})

    # 3. save to .txt for SNP calling
    _timestamp = datetime.now().strftime("%Y%m%d_%H%M%S") # Compact format (YYYYMMDD_HHMMSS)
    _filename = f"{pop_prefix}_SYNONYMIZED_LINES-{_timestamp}.txt"
    _out_path = os.path.join(LINES_OUT_DIR, _filename)
    synonymized_lines.to_csv(_out_path, sep="\t", index=False)


    mo.vstack([
        mo.md("## Synonymized Keys"),
        line_synonymizer.check_all_files(),
        mo.md("--"*100),
        mo.md(f"*{_filename} saved to:* <br> {_out_path}"),
        mo.md("--"*100),
        synonymized_lines
    ])
    return (LINES_OUT_DIR,)


@app.cell(hide_code=True)
def _():
    mo.md(r"""
    # Synonymize Key File
    """)
    return


@app.cell
def _(LINES_OUT_DIR, pop_prefix):
    key_synkey = "/home/lgw/TAMU/TXBM21-26/SNP_Pypeline/genotype_synonymizer/GenoSynonimizer-KEY.txt"
    key_path = "./0_FASTQ_Metadata/Updated Key Files/TXBM21-26_KEY-20260724_210705.txt"
    KEYS_OUT_DIR = "./0_FASTQ_Metadata/Updated Key Files"

    # initialize synonymizer
    key_synonymizer = GenotypeSynonymizer(
        key_file             = key_synkey,
        trial_file           = None,
        genotype_id_input    = key_path,
        key_cultivar_col     = "Cultivar_Name",
        key_experimental_col = "Experimental_Name",
        key_preferred_col    = "Preferred_Name",
        geno_id_col          = "FullSampleName",   # header in the LINES file
    )

    # 1. read in file to edit
    keys = pd.read_table(key_path)

    # 2. synonymize keys
    synonymized_keys = key_synonymizer.standardize_names(df=keys, name_col="FullSampleName", new_col="<SYN_NAMES>")
    synonymized_keys = synonymized_keys.drop("FullSampleName", axis=1).rename(columns={"<SYN_NAMES>":"FullSampleName"})

    # 3. save to .txt for SNP calling
    _timestamp = datetime.now().strftime("%Y%m%d_%H%M%S") # Compact format (YYYYMMDD_HHMMSS)
    _filename = f"{pop_prefix}_SYNONYMIZED_KEYS-{_timestamp}.txt"
    _out_path = os.path.join(LINES_OUT_DIR, _filename)
    synonymized_keys.to_csv(_out_path, sep="\t", index=False)


    mo.vstack([
        mo.md("## Synonymized Keys"),
        key_synonymizer.check_all_files(),
        mo.md("--"*100),
        mo.md(f"*{_filename} saved to:* <br> {_out_path}"),
        mo.md("--"*100),
        synonymized_keys
    ])
    return


@app.cell
def _():
    return


if __name__ == "__main__":
    app.run()
