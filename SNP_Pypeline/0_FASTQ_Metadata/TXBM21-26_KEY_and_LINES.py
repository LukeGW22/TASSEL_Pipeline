import marimo

__generated_with = "0.23.15"
app = marimo.App(width="medium")

with app.setup:
    import marimo as mo
    import os
    import pandas as pd
    import numpy as np

    from datetime import datetime


@app.cell(hide_code=True)
def _():
    mo.md(r"""
    # Setup
    """)
    return


@app.cell(hide_code=True)
def _():
    mo.md(r"""
    ## "LINES" File Functions
    """)
    return


@app.cell
def _():
    def read_lines(current_entries_path, new_entries_path):
        current_lines = pd.read_table(current_entries_path, sep="\t")
        new_lines = pd.read_table(new_entries_path, sep="\t")
        return current_lines, new_lines

    def update_breeding_lines(from_list, to_list):
        """
        Updates the current list of unique entries (ex. 2021-2025 genotypes) with a supplied list of entries (ex. 2026  genotypes). This function automatically removes duplicate entry names when updating.

        Args:
            from_list: DataFrame; the list of entries you want to add.
            to_list: DataFrame; the list of entries you want to add to.

        Returns:
            Updated DataFrame of unique genotype names.
        """
        # Get the column name (should be '<NAME>' based on your data)
        col_name = from_list.columns[0]

        # Get the actual values from both dataframes
        from_values = from_list[col_name].values
        to_values = to_list[col_name].values

        # Find duplicate names
        duplicate_entries = np.intersect1d(from_values, to_values)

        # Remove duplicates in from_list by filtering out rows whose names are in duplicates
        clean_from_list = from_list[~from_list[col_name].isin(duplicate_entries)]

        # Concatenate the lists
        updated_breeding_lines = pd.concat([to_list, clean_from_list], axis=0, ignore_index=True)
        return updated_breeding_lines

    return read_lines, update_breeding_lines


@app.cell(hide_code=True)
def _():
    mo.md(r"""
    ## "KEY" File Functions
    """)
    return


@app.cell
def _():
    def read_keys(current_entries_path, new_entries_path):
        current_keys = pd.read_table(current_entries_path, sep="\t")
        new_keys = pd.read_table(new_entries_path, sep="\t")
        return current_keys, new_keys

    def compare_keyfile_cols(from_key, to_key):
        """
        Reports the similarities and differences between key file column names.

        Args:
            from_key: DataFrame; the genotype keys you want to add.
            to_key: DataFrame; the genotype keys you want to add to.

        Returns:
            Common/uncommon column names + report when assigning 3 variables:
                common_cols, from_key_uncommon_cols, to_key_uncommon_cols
        """
        # get column names
        from_key_cols = from_key.columns
        to_key_cols = to_key.columns

        # columns in common
        common_cols = np.intersect1d(from_key_cols, to_key_cols)

        if len(common_cols) > 0:
            print(f"{len(common_cols)} Columns in common: \n {common_cols}")
        else:
            print("No common columns. Check names.")

        # columns NOT in common (in from_key but not in to_key) 
        from_key_uncommon_cols = np.setdiff1d(from_key_cols, to_key_cols)

        if len(from_key_uncommon_cols) > 0:
            print(f"\n{len(from_key_uncommon_cols)} Columns in 'from_key' but NOT in 'to_key': \n {from_key_uncommon_cols}")
        else:
            print("\nNo unique columns in 'from_key'.")

        # columns NOT in common (in to_key but not in from_key)
        to_key_uncommon_cols = np.setdiff1d(to_key_cols, from_key_cols)

        if len(to_key_uncommon_cols) > 0:
            print(f"\n{len(to_key_uncommon_cols)} Columns in 'to_key' but NOT in 'from_key': \n {to_key_uncommon_cols}")
        else:
            print("\nNo unique columns in 'to_key'.")

        return common_cols, from_key_uncommon_cols, to_key_uncommon_cols

    def update_keys(from_key, to_key, common_columns, has_polyA_tails: None):
        """
        Updates the current genotype key file (ex. 2021-2025 genotypes) with a supplied key file (ex. 2026 genotypes). This function maintains all observations since some lines are genotyped more than once.

        Args:
            from_key: DataFrame; the genotype keys you want to add.
            to_key: DataFrame; the genotype keys you want to add to.
            common_columns: str; the cleaned common column names.
            has_polyA_tails: bool; appends "AAAA-" to flowcell names.
        Returns:
            Updated key file inherits the "to_key" schema and column names. 
        """
        # Get columns that exist in both dataframes
        to_key_col_order = to_key.columns.tolist()
        available_cols = [col for col in to_key_col_order if col in from_key.columns]

        # Reorder the 'from_key' columns to match available columns
        from_key_reordered = from_key[available_cols]

        # add poly-A tails to flowcell name if true
        if has_polyA_tails is not None and has_polyA_tails == True:
            from_key_reordered["Flowcell"] = "AAAA-" + from_key_reordered["Flowcell"]

        # Concatenate the keys on their common columns
        updated_genotype_keys = pd.concat(
            [to_key[common_columns], from_key_reordered[common_columns]], axis=0
        ).reset_index().drop(columns={"index"})

        return updated_genotype_keys

    return compare_keyfile_cols, read_keys, update_keys


@app.cell(hide_code=True)
def _():
    mo.md(r"""
    # Execute
    """)
    return


@app.cell
def _():
    # get the working directory
    WD = os.getcwd()
    LINES_OUT_DIR = os.path.join(WD, "Updated Line Files")
    KEYS_OUT_DIR = os.path.join(WD, "Updated Key Files")

    os.makedirs(LINES_OUT_DIR, exist_ok=True)     # make the folder if it doesn't exist yet
    os.makedirs(KEYS_OUT_DIR, exist_ok=True)     

    # define population prefix
    pop_prefix = "TXBM21-26"

    # Genotype (line) name files
    ALL_LINES_CURRENT = os.path.join(WD, "TXBM21-25-LINES-3.txt")
    NEW_LINES = os.path.join(WD, "TXR2026GBS-LINES.txt")

    # Key files
    ALL_KEYS_CURRENT = os.path.join(WD, "TXBM21-25-PolyA-KEY.txt")
    NEW_KEYS = os.path.join(WD, "TXR2026GBS-KEY.txt")

    print(f"WD: \n {WD}")
    return (
        ALL_KEYS_CURRENT,
        ALL_LINES_CURRENT,
        KEYS_OUT_DIR,
        LINES_OUT_DIR,
        NEW_KEYS,
        NEW_LINES,
        pop_prefix,
    )


@app.cell
def _(
    ALL_LINES_CURRENT,
    LINES_OUT_DIR,
    NEW_LINES,
    pop_prefix,
    read_lines,
    update_breeding_lines,
):
    # 1. one-line import
    txbm21_25_lines, txbm26_lines = read_lines(ALL_LINES_CURRENT, NEW_LINES)

    # 2. update the 2021-2025 list with new, unique 2026 genotypes
    updated_lines = update_breeding_lines(from_list=txbm26_lines, to_list=txbm21_25_lines)

    # 3. save to .txt for SNP calling
    _timestamp = datetime.now().strftime("%Y%m%d_%H%M%S") # Compact format (YYYYMMDD_HHMMSS)
    _filename = f"{pop_prefix}_LINES-{_timestamp}.txt"
    _out_path = os.path.join(LINES_OUT_DIR, _filename)
    updated_lines.to_csv(_out_path, sep="\t", index=False)

    mo.vstack([
        mo.md('## Update "LINES" File'),
        mo.md(f"**Current** Num. Lines: {len(txbm21_25_lines)}"),
        mo.md(f"**TO ADD** Num. Lines: {len(txbm26_lines)}"),
        mo.md(f"**Updated** Num. Lines: {len(updated_lines)}"),
        mo.md("--"*100),
        mo.md(f"*{_filename} saved to:* <br> {_out_path}"),
        mo.md("--"*100),
        mo.ui.table(updated_lines.reset_index(drop=True))
    ])
    return


@app.cell
def _(
    ALL_KEYS_CURRENT,
    KEYS_OUT_DIR,
    NEW_KEYS,
    compare_keyfile_cols,
    pop_prefix,
    read_keys,
    update_keys,
):
    # 1. Import key files
    txbm21_25_keys, txbm26_keys = read_keys(ALL_KEYS_CURRENT, NEW_KEYS)

    # 2. QC: check column names
    common_cols, from_key_uncommon_cols, to_key_uncommon_cols = compare_keyfile_cols(txbm26_keys, txbm21_25_keys)

    # 3. update key file
    updated_keyfile = update_keys(
        from_key=txbm26_keys, to_key=txbm21_25_keys, 
        common_columns=common_cols, has_polyA_tails=True
    )

    # 4. save updated key file
    _timestamp = datetime.now().strftime("%Y%m%d_%H%M%S") # Compact format (YYYYMMDD_HHMMSS)
    _filename = f"{pop_prefix}_KEY-{_timestamp}.txt"
    _out_path = os.path.join(KEYS_OUT_DIR, _filename)
    updated_keyfile.to_csv(_out_path, sep="\t", index=False)

    # optional: make nice tidy table to compare columns between keyfiles with
    _max_len = max(len(common_cols), len(from_key_uncommon_cols), len(to_key_uncommon_cols), 1)

    def _pad(_cols, _n):
        _vals = list(_cols)
        return _vals + [""] * (_n - len(_vals))

    _col_comparison = pd.DataFrame({
        "Common Columns": _pad(common_cols, _max_len),
        "Columns Unique to TXBM26": _pad(from_key_uncommon_cols, _max_len),
        "Columns Unique to TXBM21-25": _pad(to_key_uncommon_cols, _max_len),
    })

    _tidy_col_table = mo.vstack([
        mo.md("### Key File Column Comparison"),
        mo.md(
            f"**Common:** {len(common_cols)} &nbsp;|&nbsp; "
            f"**Unique to TXBM26:** {len(from_key_uncommon_cols)} &nbsp;|&nbsp; "
            f"**Unique to TXBM21-25:** {len(to_key_uncommon_cols)}"
        ),
        mo.ui.table(_col_comparison, selection=None),
    ])

    mo.vstack([
        mo.md('## Update "KEY" file.'),
        mo.md('### Updated keys.'),
        updated_keyfile,
        _tidy_col_table
    ])
    return


@app.cell
def _():
    return


if __name__ == "__main__":
    app.run()
