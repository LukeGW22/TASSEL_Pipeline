"""
GenotypeSynonymizer
===================
A class for standardizing and cross-referencing genotype/cultivar names
across multi-environment trial (MET) and genotype data files.

Dependencies
------------
    Required : pandas
    Optional : rapidfuzz  (pip install rapidfuzz)
               Falls back to difflib if rapidfuzz is not installed.

Usage Example
-------------
    syn = GenotypeSynonymizer(
        key_file            = "synonym_key.tsv",
        trial_file          = "met_data.tsv",
        genotype_id_input   = "geno_table.tsv",  # or a plain .txt list
        key_cultivar_col    = "cultivar",
        key_experimental_col= "experimental",
        key_preferred_col   = "preferred",
        trial_id_col        = "Genotype",
        geno_id_col         = "Taxa",            # required when input is a table
    )

    # 1. QC checks on all files
    syn.check_all_files()

    # 2. Presence/absence check — what name is used in each file?
    presence_df = syn.check_name_presence()

    # 3. Hard + fuzzy match table for unmatched names
    match_df = syn.find_matches(n_matches=5, fuzzy_threshold=65.0)

    # 4. Append a standardized-name column to any DataFrame
    trial_std = syn.standardize_names(syn.trial_df, name_col="Genotype")
"""

import os
import re
import pandas as pd
from typing import Dict, List, Optional, Tuple, Union

try:
    from rapidfuzz import fuzz
    from rapidfuzz import process as rfprocess
    _RAPIDFUZZ = True
except ImportError:
    from difflib import SequenceMatcher
    _RAPIDFUZZ = False


# ──────────────────────────────────────────────────────────────────────────────
class GenotypeSynonymizer:
    """
    Synonymize genotype names across multiple breeding/trial data files.

    Three core input files
    ----------------------
    key_file
        Tab- (or comma-) delimited synonym table with at least three columns:
        a cultivar column, one or more experimental-name columns, and a
        preferred (standardized) name column.
    trial_file
        Multi-environment trial (MET) file with trait and metadata columns
        plus a genotype-ID column.
    genotype_id_input
        One of:
          • path to a genotype/marker table (.tsv/.txt) — also supply
            ``geno_id_col`` to name the ID column;
          • path to a plain-text taxa list (.txt, one entry per line);
          • a Python ``list[str]`` of genotype names.

    Three primary methods
    ---------------------
    check_line_names / check_all_files
        QC: whitespace, space separators, special characters, lowercase.
    check_name_presence
        Presence/absence of every query across key, trial, and geno-list
        files; returns the exact alias found in each file.
    find_matches
        Hard (exact) lookup + fuzzy top-N candidates for unresolved names.
    """

    # ── Constructor ──────────────────────────────────────────────────────────
    def __init__(
        self,
        key_file:             str,
        trial_file:           Optional[str],
        genotype_id_input:    Union[str, List[str]],
        # Key-file column names
        key_cultivar_col:     str                    = "cultivar",
        key_experimental_col: Union[str, List[str]]  = "experimental",
        key_preferred_col:    str                    = "preferred",
        # Trial-file settings
        trial_id_col:         str                    = "genotype",
        # Genotype-table settings (only when genotype_id_input is a table file)
        geno_id_col:          Optional[str]          = None,
        # File delimiters
        key_sep:              str                    = "\t",
        trial_sep:            str                    = "\t",
        geno_sep:             str                    = "\t",
    ):
        """
        Parameters
        ----------
        key_file : str
            Path to the synonym key file (.tsv / .txt / .csv).
        trial_file : str or None
            Path to the MET phenotype/metadata file (.tsv / .txt / .csv).
            Pass ``None`` to skip trial-file loading (trial-related outputs
            will be filled with ``None``).
        genotype_id_input : str | list[str]
            Genotype names as a file path or Python list (see class docstring).
        key_cultivar_col : str
            Column in *key_file* holding cultivar / official names.
        key_experimental_col : str | list[str]
            Column(s) in *key_file* holding experimental designations.
            Multiple aliases per cell may be separated by ``;`` or ``,``.
        key_preferred_col : str
            Column in *key_file* holding the canonical preferred name.
        trial_id_col : str
            Column in *trial_file* holding genotype identifiers.
        geno_id_col : str, optional
            Column in a tabular *genotype_id_input* file holding sample IDs.
            Required when that file is a table, not a single-column name list.
        key_sep : str
            Field delimiter for *key_file*. Default: tab (``\t``).
        trial_sep : str
            Field delimiter for *trial_file*. Default: tab.
        geno_sep : str
            Field delimiter for a tabular *genotype_id_input*. Default: tab.
        """
        # Store column config
        self.key_cultivar_col     = key_cultivar_col
        self.key_experimental_col = (
            [key_experimental_col]
            if isinstance(key_experimental_col, str)
            else list(key_experimental_col)
        )
        self.key_preferred_col = key_preferred_col
        self.trial_id_col      = trial_id_col
        self.geno_id_col       = geno_id_col

        # ── Load key file ────────────────────────────────────────────────────
        self.key_df = self._load_delimited(key_file, sep=key_sep)
        self._validate_key_columns()
        self._build_synonym_lookup()

        # ── Load trial file ──────────────────────────────────────────────────
        if trial_file is not None:
            self.trial_df = self._load_delimited(trial_file, sep=trial_sep)
            if trial_id_col not in self.trial_df.columns:
                raise ValueError(
                    f"Column '{trial_id_col}' not found in trial file. "
                    f"Available columns: {list(self.trial_df.columns)}"
                )
        else:
            self.trial_df = None

        # ── Load genotype IDs ────────────────────────────────────────────────
        self.geno_names: List[str] = self._parse_geno_input(
            genotype_id_input, geno_sep
        )

        # ── Startup summary ──────────────────────────────────────────────────
        print(
            f"✓ Key file loaded     — {len(self.key_df):,} rows | "
            f"{len(self._lookup):,} total aliases indexed."
        )
        if self.trial_df is not None:
            print(
                f"✓ Trial file loaded   — {len(self.trial_df):,} rows | "
                f"{self.trial_df[trial_id_col].nunique():,} unique genotype IDs."
            )
        else:
            print("  ⚠ Trial file not provided — trial-related outputs will be skipped.")
        print(f"✓ Genotype list loaded — {len(self.geno_names):,} entries.")
        if not _RAPIDFUZZ:
            print(
                "  ⚠ rapidfuzz not found — using difflib for fuzzy matching. "
                "Install with: pip install rapidfuzz"
            )

    # ── Private helpers ───────────────────────────────────────────────────────

    @staticmethod
    def _load_delimited(path: str, sep: str = "\t") -> pd.DataFrame:
        """Read a delimited text file; strip surrounding whitespace from cells."""
        if not os.path.isfile(path):
            raise FileNotFoundError(f"File not found: '{path}'")
        # Auto-switch to comma for .csv
        if os.path.splitext(path)[1].lower() == ".csv":
            sep = ","
        df = pd.read_csv(path, sep=sep, dtype=str)
        return df.apply(
            lambda col: col.str.strip() if col.dtype == object else col
        )

    def _validate_key_columns(self) -> None:
        """Raise if any required key-file columns are absent."""
        required = (
            [self.key_cultivar_col, self.key_preferred_col]
            + self.key_experimental_col
        )
        missing = [c for c in required if c not in self.key_df.columns]
        if missing:
            raise ValueError(
                f"Key file is missing required columns: {missing}. "
                f"Available: {list(self.key_df.columns)}"
            )

    def _build_synonym_lookup(self) -> None:
        """
        Build two internal structures:

        ``_lookup``  : dict  alias_UPPER  → preferred_name
        ``_aliases`` : dict  preferred_name → [all_known_aliases]
        """
        self._lookup:  Dict[str, str]        = {}
        self._aliases: Dict[str, List[str]]  = {}

        for _, row in self.key_df.iterrows():
            preferred = row[self.key_preferred_col]
            if pd.isna(preferred) or preferred == "":
                continue

            all_aliases: List[str] = []

            # Preferred itself
            self._lookup[preferred.upper()] = preferred
            all_aliases.append(preferred)

            # Cultivar name
            cultivar = row[self.key_cultivar_col]
            if pd.notna(cultivar) and cultivar.strip():
                self._lookup[cultivar.upper()] = preferred
                all_aliases.append(cultivar)

            # Experimental name column(s) — cells may be multi-valued (;,)
            for exp_col in self.key_experimental_col:
                cell = row.get(exp_col)
                if pd.notna(cell) and str(cell).strip():
                    for token in re.split(r"[;,]", str(cell)):
                        token = token.strip()
                        if token:
                            self._lookup[token.upper()] = preferred
                            all_aliases.append(token)

            # Accumulate aliases under preferred key (deduplicate, preserve order)
            existing = self._aliases.setdefault(preferred, [])
            for alias in all_aliases:
                if alias not in existing:
                    existing.append(alias)

        # Sorted list of all preferred names (for default queries)
        self._all_preferred: List[str] = sorted(self._aliases.keys())

    def _resolve(self, name: str) -> Optional[str]:
        """Return preferred name for *name* (case-insensitive), or ``None``."""
        return self._lookup.get(str(name).upper().strip())

    def _parse_geno_input(
        self, source: Union[str, List[str]], sep: str
    ) -> List[str]:
        """Convert genotype_id_input into a flat list of strings."""
        if isinstance(source, list):
            return [str(n).strip() for n in source if str(n).strip()]

        if not isinstance(source, str):
            raise TypeError(
                f"genotype_id_input must be a file path (str) or list. "
                f"Got {type(source).__name__}."
            )
        if not os.path.isfile(source):
            raise FileNotFoundError(f"Genotype input file not found: '{source}'")

        if self.geno_id_col is not None:
            # Tabular file — extract named column
            df = self._load_delimited(source, sep=sep)
            if self.geno_id_col not in df.columns:
                raise ValueError(
                    f"Column '{self.geno_id_col}' not found in genotype file. "
                    f"Available: {list(df.columns)}"
                )
            return df[self.geno_id_col].dropna().astype(str).str.strip().tolist()

        # Plain text list (one name per line)
        with open(source) as fh:
            return [ln.strip() for ln in fh if ln.strip()]

    # ── Public method 1: QC ───────────────────────────────────────────────────

    @staticmethod
    def check_line_names(df: pd.DataFrame, name_col: str) -> None:
        """
        Run QC checks on genotype name strings in *df[name_col]*.

        Checks performed
        ----------------
        1. Leading / trailing whitespace
        2. Internal spaces used as word separators
        3. Prohibited special characters (anything outside ``a-zA-Z0-9 -_.``)
        4. Fully lowercase entries

        Parameters
        ----------
        df : pd.DataFrame
            DataFrame containing the column to check.
        name_col : str
            Column name holding the genotype / line identifiers.
        """
        if name_col not in df.columns:
            raise ValueError(
                f"Column '{name_col}' not found. "
                f"Available: {list(df.columns)}"
            )

        series = df[name_col].astype(str)

        # 1. Leading / trailing whitespace
        has_whitespace = series != series.str.strip()
        # 2. Internal space separators
        has_space_sep  = series.str.contains(r" ", regex=False, na=False)
        # 3. Prohibited special characters (outside a-zA-Z0-9 space - _ .)
        has_spec_chars = series.str.contains(
            r"[^a-zA-Z0-9 \-_.]", regex=True, na=False
        )
        # 4. Fully lowercase
        is_lowercase   = series.str.islower()

        if has_whitespace.any():
            print("✘ Leading/trailing whitespace found:")
            print(df.loc[has_whitespace, [name_col]].to_string())
        else:
            print("✓ No leading/trailing whitespace in entry names.")

        if has_space_sep.any():
            print("✘ Spaces used as separators in names:")
            print(df.loc[has_space_sep, [name_col]].to_string())
        else:
            print("✓ No spaces used as separators in entry names.")

        if has_spec_chars.any():
            print("✘ Prohibited special characters in entry names:")
            flagged = df.loc[has_spec_chars, [name_col]].copy()
            flagged["prohibited_chars"] = (
                series.loc[has_spec_chars]
                .str.findall(r"[^a-zA-Z0-9 \-_.]")
                .str.join(", ")
            )
            print(flagged.to_string())
        else:
            print("✓ No prohibited special characters in entry names.")

        if is_lowercase.any():
            print("✘ Fully lowercase entry names found:")
            print(df.loc[is_lowercase, [name_col]].to_string())
        else:
            print("✓ All entry names contain uppercase characters.")

    def check_all_files(self) -> None:
        """
        Convenience wrapper: run :meth:`check_line_names` on the preferred-
        name column of the key file, the ID column of the trial file, and
        the loaded genotype list.
        """
        _sep = "=" * 60

        print(f"\n{_sep}\nQC — Key file  ({self.key_preferred_col})\n{_sep}")
        self.check_line_names(self.key_df, self.key_preferred_col)

        print(f"\n{_sep}\nQC — Trial file  ({self.trial_id_col})\n{_sep}")
        if self.trial_df is not None:
            self.check_line_names(self.trial_df, self.trial_id_col)
        else:
            print("  ⚠ No trial file loaded — skipping trial QC.")

        print(f"\n{_sep}\nQC — Genotype list\n{_sep}")
        _id_col = self.geno_id_col or "genotype"
        geno_df = pd.DataFrame({_id_col: self.geno_names})
        self.check_line_names(geno_df, _id_col)

    # ── Public method 2: presence / absence ───────────────────────────────────

    def check_name_presence(
        self,
        query_names: Optional[List[str]] = None,
        verbose:     bool                = True,
    ) -> pd.DataFrame:
        """
        Check whether each query name (or any of its known synonyms) appears
        in the key file, trial file, and genotype list. Returns the exact
        string used in each file.

        Parameters
        ----------
        query_names : list[str], optional
            Names to search for. Defaults to every preferred name in the key.
        verbose : bool
            Print a presence-summary table. Default: ``True``.

        Returns
        -------
        pd.DataFrame
            One row per query with columns:

            ==================  ================================================
            query_name          The name supplied for lookup
            preferred_name      Resolved preferred name (or ``NOT_IN_KEY``)
            in_key              Whether any alias exists in the key file
            key_aliases         Comma-joined list of known key-file aliases
            in_trial            Whether any alias found in the trial file
            trial_name_used     Exact string used in the trial file
            in_geno_list        Whether any alias found in the genotype list
            geno_list_name_used Exact string used in the genotype list
            ==================  ================================================
        """
        if query_names is None:
            query_names = self._all_preferred

        # Build upper-cased reverse maps for fast membership testing
        trial_upper: Dict[str, str] = (
            {
                n.upper(): n
                for n in self.trial_df[self.trial_id_col].dropna().astype(str).unique()
            }
            if self.trial_df is not None
            else {}
        )
        geno_upper: Dict[str, str] = {
            n.upper(): n for n in self.geno_names
        }

        records = []
        for query in query_names:
            query_upper = query.upper().strip()
            preferred   = self._resolve(query)

            # Collect all known aliases for this entry
            key_aliases: List[str] = (
                self._aliases.get(preferred, []) if preferred else []
            )
            in_key = bool(key_aliases) or (query_upper in self._lookup)

            # ── Trial file ───────────────────────────────────────────────────
            trial_name: Optional[str] = trial_upper.get(query_upper)
            if trial_name is None and key_aliases:
                for alias in key_aliases:
                    hit = trial_upper.get(alias.upper())
                    if hit:
                        trial_name = hit
                        break
            in_trial = trial_name is not None

            # ── Genotype list ─────────────────────────────────────────────────
            geno_name: Optional[str] = geno_upper.get(query_upper)
            if geno_name is None and key_aliases:
                for alias in key_aliases:
                    hit = geno_upper.get(alias.upper())
                    if hit:
                        geno_name = hit
                        break
            in_geno = geno_name is not None

            records.append(
                {
                    "query_name":          query,
                    "preferred_name":      preferred or "NOT_IN_KEY",
                    "in_key":              in_key,
                    "key_aliases":         ", ".join(key_aliases) if key_aliases else None,
                    "in_trial":            in_trial,
                    "trial_name_used":     trial_name,
                    "in_geno_list":        in_geno,
                    "geno_list_name_used": geno_name,
                }
            )

        result = pd.DataFrame(records)

        if verbose:
            _sep = "=" * 60
            print(f"\n{_sep}\nNAME PRESENCE ACROSS FILES\n{_sep}")
            print(f"  Queries submitted  : {len(result):,}")
            print(f"  Found in key file  : {result['in_key'].sum():,} / {len(result):,}")
            if self.trial_df is not None:
                print(f"  Found in trial file: {result['in_trial'].sum():,} / {len(result):,}")
            else:
                print("  Found in trial file: n/a (no trial file loaded)")
            print(f"  Found in geno list : {result['in_geno_list'].sum():,} / {len(result):,}")

            absent_mask = (
                ~result["in_key"]
                | (~result["in_trial"] if self.trial_df is not None else False)
                | ~result["in_geno_list"]
            )
            if absent_mask.any():
                print(
                    f"\n  ⚠  {absent_mask.sum():,} names absent from ≥1 file:"
                )
                print(
                    result.loc[
                        absent_mask,
                        ["query_name", "preferred_name",
                         "in_key", "in_trial", "in_geno_list"],
                    ].to_string(index=False)
                )
            else:
                print("\n  ✓ All names present in every file.")

        return result

    # ── Public method 3: hard + fuzzy matching ────────────────────────────────

    def find_matches(
        self,
        query_names:     Optional[List[str]] = None,
        n_matches:       int                 = 5,
        fuzzy_threshold: float               = 65.0,
    ) -> pd.DataFrame:
        """
        For each query name perform an exact lookup then, if unresolved,
        return the top fuzzy candidates from the key-file alias pool.

        Parameters
        ----------
        query_names : list[str], optional
            Names to match. Defaults to geno-list entries not already
            resolved by an exact lookup.
        n_matches : int
            Maximum fuzzy candidates to return per query (3 or 5 typical).
        fuzzy_threshold : float
            Minimum similarity score (0–100) to include a fuzzy hit.

        Returns
        -------
        pd.DataFrame
            Columns: ``query_name``, ``hard_match``, ``preferred_name``,
            then for *i* in 1…n_matches:
            ``fuzzy_match_i``, ``fuzzy_alias_i``, ``fuzzy_score_i``.

            * ``hard_match`` = True when an exact alias was found.
            * ``fuzzy_alias_i`` = the specific alias in the key that
              triggered the match (may differ from ``fuzzy_match_i``,
              which is the resolved preferred name).
        """
        if query_names is None:
            query_names = [n for n in self.geno_names if not self._resolve(n)]
            if not query_names:
                print("✓ All genotype names resolved exactly — no fuzzy matching needed.")
                return pd.DataFrame()

        # Pool of all known aliases (stored as UPPER for comparison)
        alias_pool: List[str] = list(self._lookup.keys())

        records = []
        for query in query_names:
            query_upper = query.upper().strip()
            preferred   = self._resolve(query)
            hard_match  = preferred is not None

            rec: Dict = {
                "query_name":    query,
                "hard_match":    hard_match,
                "preferred_name": preferred,
            }

            if not hard_match:
                hits = self._fuzzy_search(
                    query_upper, alias_pool,
                    n=n_matches, threshold=fuzzy_threshold
                )
                for i, (alias_upper, score) in enumerate(hits, start=1):
                    pref_hit = self._lookup.get(alias_upper, alias_upper)
                    rec[f"fuzzy_match_{i}"] = pref_hit
                    rec[f"fuzzy_alias_{i}"] = alias_upper
                    rec[f"fuzzy_score_{i}"] = round(score, 1)
                # Pad remaining slots with None
                for i in range(len(hits) + 1, n_matches + 1):
                    rec[f"fuzzy_match_{i}"] = None
                    rec[f"fuzzy_alias_{i}"] = None
                    rec[f"fuzzy_score_{i}"] = None
            else:
                for i in range(1, n_matches + 1):
                    rec[f"fuzzy_match_{i}"] = None
                    rec[f"fuzzy_alias_{i}"] = None
                    rec[f"fuzzy_score_{i}"] = None

            records.append(rec)

        result = pd.DataFrame(records)

        n_hard    = int(result["hard_match"].sum())
        n_no_hit  = int(
            result["fuzzy_score_1"].isna().sum() - n_hard
        ) if "fuzzy_score_1" in result.columns else 0
        n_fuzzy   = len(result) - n_hard - max(n_no_hit, 0)

        print(f"\nMatch results for {len(result):,} names:")
        print(f"  ✓ Hard (exact) matches : {n_hard:,}")
        print(f"  ~ Fuzzy matches found  : {n_fuzzy:,}")
        print(f"  ✘ No match found        : {n_no_hit:,}")

        return result

    @staticmethod
    def _fuzzy_search(
        query:     str,
        choices:   List[str],
        n:         int   = 5,
        threshold: float = 65.0,
    ) -> List[Tuple[str, float]]:
        """
        Return up to *n* ``(alias, score)`` pairs above *threshold*,
        sorted by descending score.

        Uses **rapidfuzz** (``WRatio`` scorer) when available; falls back
        to **difflib** ``SequenceMatcher`` otherwise.
        """
        if _RAPIDFUZZ:
            hits = rfprocess.extract(
                query, choices,
                scorer=fuzz.WRatio,
                limit=n,
                score_cutoff=threshold,
            )
            return [(alias, score) for alias, score, _ in hits]

        # difflib fallback
        scored = [
            (choice, SequenceMatcher(None, query, choice).ratio() * 100)
            for choice in choices
        ]
        scored = [(c, s) for c, s in scored if s >= threshold]
        scored.sort(key=lambda x: x[1], reverse=True)
        return scored[:n]

    # ── Bonus utility methods ─────────────────────────────────────────────────

    def standardize_names(
        self,
        df:       pd.DataFrame,
        name_col: str,
        new_col:  str  = "preferred_name",
        inplace:  bool = False,
    ) -> pd.DataFrame:
        """
        Append a *preferred_name* column to *df* by resolving each entry
        in *name_col* against the synonym lookup.

        Parameters
        ----------
        df : pd.DataFrame
        name_col : str
            Column containing raw genotype names to standardize.
        new_col : str
            Name for the new preferred-name column. Default: ``preferred_name``.
        inplace : bool
            Modify *df* in place. Default: ``False``.

        Returns
        -------
        pd.DataFrame
            *df* with *new_col* appended.
        """
        if not inplace:
            df = df.copy()
        df[new_col] = df[name_col].apply(
            lambda x: self._resolve(x) if pd.notna(x) else None
        )
        n_missing = int(df[new_col].isna().sum())
        if n_missing:
            print(
                f"  ⚠ {n_missing:,} of {len(df):,} names could not be "
                f"standardized (no match in key file)."
            )
        else:
            print(f"  ✓ All {len(df):,} names successfully standardized.")
        return df

    def get_aliases(self, preferred_name: str) -> List[str]:
        """Return every known alias for *preferred_name* (from the key file)."""
        return list(self._aliases.get(preferred_name, []))

    def summary(self) -> None:
        """Print a short summary of the loaded data."""
        _sep = "=" * 60
        print(f"\n{_sep}\nGenotypeSynonymizer — Summary\n{_sep}")
        print(f"  Preferred names in key  : {len(self._all_preferred):,}")
        print(f"  Total aliases indexed   : {len(self._lookup):,}")
        if self.trial_df is not None:
            print(f"  Trial file rows         : {len(self.trial_df):,}")
            print(
                f"  Unique IDs in trial     : "
                f"{self.trial_df[self.trial_id_col].nunique():,}"
            )
        else:
            print("  Trial file rows         : n/a (not loaded)")
            print("  Unique IDs in trial     : n/a")
        print(f"  Genotype list entries   : {len(self.geno_names):,}")
        print(f"  Fuzzy backend           : "
              f"{'rapidfuzz' if _RAPIDFUZZ else 'difflib (install rapidfuzz)'}")
