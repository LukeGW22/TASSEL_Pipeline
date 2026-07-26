#!/usr/bin/env python3
"""
reduce_tree.py — Collapse redundant file listings in `tree` output schematics.

Designed for use with genomic pipeline directory trees (TASSEL/ADMIXTURE/Fable),
but broadly applicable to any `tree`-generated schematic with repetitive file groups.

Usage:
    python reduce_tree.py input.txt [output.txt]

If output.txt is omitted, overwrites input.txt (original backed up as input.txt.bak).
"""

import re
import sys
import shutil
from pathlib import Path


# ── Helpers ───────────────────────────────────────────────────────────────────

def base_prefix(line: str) -> str:
    """Return the indentation prefix of a tree line (│   and spaces only)."""
    m = re.match(r'^((?:│   |    )*)', line)
    return m.group(1) if m else ''


def filename(line: str) -> str:
    """Extract the filename/dirname from a tree line."""
    return line.split('── ')[-1].strip() if '── ' in line else line.strip()


def collect_while(lines, i, predicate):
    """Consume consecutive lines satisfying predicate(filename). Returns (block, new_i)."""
    block = []
    while i < len(lines) and predicate(filename(lines[i])):
        block.append(lines[i])
        i += 1
    return block, i


# ── Collapse Rules ────────────────────────────────────────────────────────────
# Each rule is a (test_fn, handler_fn) pair.
# test_fn(filename) → bool  — should this line trigger the rule?
# handler_fn(line, lines, i, bp) → (output_lines, new_i)

def rule_admix_P(line, lines, i, b):
    block, i = collect_while(lines, i, lambda x: re.search(r'\.admix\.P$', x))
    return [f"{b}├── < {len(block)} .admix.P files (K2-K30 × 5 seeds) >\n"], i

def rule_admix_Q(line, lines, i, b):
    block, i = collect_while(lines, i, lambda x: re.search(r'\.admix\.Q$', x))
    return [f"{b}└── < {len(block)} .admix.Q files (K2-K30 × 5 seeds) >\n"], i

def rule_k_seed_log(line, lines, i, b):
    block, i = collect_while(lines, i, lambda x: re.search(r'\.K\d+\.seed\d+\.log$', x))
    return [f"{b}└── < {len(block)} K/seed .log files (K2-K30 × seeds 42,95,491,696,1183) >\n"], i

def rule_sobol_ucb_log(line, lines, i, b):
    block, i = collect_while(lines, i, lambda x: bool(
        re.search(r'TXBM21-25\.(SOBOL-0|UCB-1)-\d+\.log$', x) or
        re.search(r'TXBM21-25\.Trial_ID\.log$', x)
    ))
    sobol = [filename(l) for l in block if 'SOBOL' in filename(l)]
    ucb   = [filename(l) for l in block if 'UCB'   in filename(l)]
    trial = [filename(l) for l in block if 'Trial' in filename(l)]
    out = []
    if sobol:
        nums = sorted(int(x) for x in re.findall(r'SOBOL-0-(\d+)\.log', ''.join(sobol)))
        out.append(f"{b}{'├' if ucb else '└'}── < {len(sobol)} SOBOL-0 run .log files ({nums[0]}-{nums[-1]}) >\n")
    if ucb:
        nums = sorted(int(x) for x in re.findall(r'UCB-1-(\d+)\.log', ''.join(ucb)))
        extra = " + Trial_ID.log" if trial else ""
        out.append(f"{b}└── < {len(ucb)} UCB-1 run .log files ({nums[0]}-{nums[-1]}){extra} >\n")
    elif trial:
        out.append(f"{b}└── < Trial_ID.log >\n")
    return out, i

def rule_prelim_sobol_log(line, lines, i, b):
    block, i = collect_while(lines, i, lambda x: re.search(r'PRELIM-SOBOL[^\n]*\.log$', x))
    nums = sorted(int(x) for x in re.findall(r'SOBOL-0-(\d+)\.log', ''.join(block)))
    rng = f"{nums[0]}-{nums[-1]}" if nums else str(len(block))
    return [f"{b}└── < {len(block)} PRELIM-SOBOL .log files (runs {rng}) >\n"], i

def rule_prelim_sobol_txt(line, lines, i, b):
    block, i = collect_while(lines, i, lambda x: re.search(r'PRELIM-SOBOL[^\n]*\d{3}\.txt$', x))
    nums = sorted(int(x) for x in re.findall(r'SOBOL-0-(\d{2})\d\.txt', ''.join(block)))
    rng = f"runs {nums[0]}-{nums[-1]}" if nums else f"{len(block)} files"
    return [f"{b}└── < {len(block)} PRELIM-SOBOL summary .txt ({rng}) >\n"], i

def rule_stderr_stdout(line, lines, i, b):
    block, i = collect_while(lines, i, lambda x: bool(re.match(r'(?:stderr|stdout)\.\S+\.\d{5,}$', x)))
    err  = sum(1 for l in block if 'stderr.' in l)
    sout = len(block) - err
    out = []
    if err:  out.append(f"{b}├── < {err} stderr.*.JOBID files >\n")
    if sout: out.append(f"{b}└── < {sout} stdout.*.JOBID files >\n")
    return out, i

def rule_plots_dir(line, lines, i, b):
    """Collapse contents of *_plots directories."""
    out = [line]
    i += 1
    depth = len(b)
    files = []
    while i < len(lines) and '── ' in lines[i] and len(base_prefix(lines[i])) > depth:
        files.append(filename(lines[i]))
        i += 1
    if files:
        exts = sorted(set(x.rsplit('.', 1)[-1] for x in files if '.' in x))
        out.append(f"{b}│   └── < {len(files)} files: {', '.join('.' + e for e in exts)} >\n")
    return out, i

def rule_clumpak_k_dirs(line, lines, i, b):
    """Collapse K2-K30 directories inside *_for_CLUMPAK folders."""
    f = filename(line)
    base_name = re.sub(r'\.K\d+$', '', f)
    parent_depth = len(b)
    k_list = []
    while i < len(lines):
        curr_f = filename(lines[i])
        if re.match(re.escape(base_name) + r'\.K\d+$', curr_f) and '── ' in lines[i]:
            k_list.append(int(re.search(r'\.K(\d+)$', curr_f).group(1)))
            i += 1
            while i < len(lines) and len(base_prefix(lines[i])) > parent_depth:
                i += 1
        else:
            break
    if len(k_list) > 1:
        return [f"{b}└── < {base_name}.K{min(k_list)}-K{max(k_list)} ({len(k_list)} dirs, 5 .admix.Q per dir) >\n"], i
    return [line], i

def rule_jar_files(line, lines, i, b):
    """Collapse .jar / .dylib / .ini library files."""
    block, i = collect_while(lines, i, lambda x: x.endswith(('.jar', '.dylib', '.ini')))
    jar   = sum(1 for l in block if filename(l).endswith('.jar'))
    other = [filename(l) for l in block if not filename(l).endswith('.jar')]
    out = [f"{b}├── < {jar} .jar library files >\n"]
    out += [f"{b}├── {o}\n" for o in other]
    return out, i

def rule_image_files(line, lines, i, b):
    """Collapse UI image files (.gif, .jpeg)."""
    block, i = collect_while(lines, i, lambda x: bool(re.search(r'\.(gif|jpeg)$', x)))
    return [f"{b}└── < {len(block)} UI image files (.gif, .jpeg) >\n"], i

def rule_tassel_plugin_logs(line, lines, i, b):
    """Collapse TASSEL GBS pipeline plugin log files."""
    pat = r'^(discovery|DiscoverySNP|GBSSeqTo|HapmapFrom|ProductionSNP|SAMToGBS|SNPQuality|TagExport|VCFFromHDF5).*\.log$'
    block, i = collect_while(lines, i, lambda x: bool(re.search(pat, x)))
    return [f"{b}└── < {len(block)} TASSEL GBS plugin .log files >\n"], i

def rule_bwa_index(line, lines, i, b):
    """Collapse BWA genome index files."""
    block, i = collect_while(lines, i, lambda x: bool(re.search(r'\.fa\.(amb|ann|bwt|pac|sa)$', x)))
    return [f"{b}└── < {len(block)} BWA index files (.fa.amb/ann/bwt/pac/sa) >\n"], i

def rule_summary_numbered(line, lines, i, b):
    """Collapse summary1.txt, summary2.txt, summary3.txt, summary4.txt."""
    block, i = collect_while(lines, i, lambda x: bool(re.match(r'summary\d\.txt$', x)))
    return [f"{b}└── < {len(block)} summary1-{len(block)}.txt files >\n"], i

def rule_txbm_summary(line, lines, i, b):
    """Collapse TXBM21-25[1-4].txt TASSEL summary files."""
    block, i = collect_while(lines, i, lambda x: bool(re.match(r'TXBM21-25\d\.txt$', x)))
    return [f"{b}└── < {len(block)} × TXBM21-25N.txt summary files >\n"], i

def rule_tassel_summaries(line, lines, i, b):
    """Collapse MLC/MAF numbered summary .txt files (e.g. MLC30_MAF041.txt → MLC30_MAF044.txt)."""
    f = filename(line)
    base_name = re.sub(r'\d\.txt$', '', f)
    block, i = collect_while(lines, i, lambda x: x.startswith(base_name) and x.endswith('.txt'))
    if len(block) >= 4:
        return [f"{b}└── < {len(block)} × {base_name}N.txt summary files >\n"], i
    # Too few to collapse — pass through
    return [lines[j] for j in range(i - len(block), i)], i

def rule_gridtest_logs(line, lines, i, b):
    """Collapse GridTest MAF/MLC/MISS/HET parameter sweep log files."""
    block, i = collect_while(lines, i, lambda x: bool(re.search(r'MAF\d+\.MLC\d+\.MISS', x)))
    return [f"{b}└── < {len(block)} GridTest parameter .log files >\n"], i


# ── Rule dispatch table ───────────────────────────────────────────────────────
# Each entry: (predicate_on_filename, rule_function)
RULES = [
    # ADMIXTURE output files
    (lambda f: bool(re.search(r'\.admix\.P$', f)),          rule_admix_P),
    (lambda f: bool(re.search(r'\.admix\.Q$', f)),          rule_admix_Q),
    (lambda f: bool(re.search(r'\.K\d+\.seed\d+\.log$', f)),rule_k_seed_log),
    # Optimization run logs
    (lambda f: bool(re.search(r'TXBM21-25\.(SOBOL-0|UCB-1)-\d+\.log$', f) or
                    re.search(r'TXBM21-25\.Trial_ID\.log$', f)),  rule_sobol_ucb_log),
    (lambda f: bool(re.search(r'PRELIM-SOBOL-0-\d+\.log$', f)),   rule_prelim_sobol_log),
    (lambda f: bool(re.search(r'PRELIM-SOBOL-0-\d{3}\.txt$', f)), rule_prelim_sobol_txt),
    # HPC job log files
    (lambda f: bool(re.match(r'(?:stderr|stdout)\.\S+\.\d{5,}$', f)), rule_stderr_stdout),
    # Plot directory contents
    (lambda f: bool(re.search(r'_plots$', f)),               rule_plots_dir),
    # CLUMPAK K directories
    (lambda f: bool(re.search(r'\.K\d+$', f)),               rule_clumpak_k_dirs),
    # Software library files
    (lambda f: f.endswith(('.jar', '.dylib', '.ini')),        rule_jar_files),
    (lambda f: bool(re.search(r'\.(gif|jpeg)$', f)),          rule_image_files),
    # TASSEL-specific logs and summaries
    (lambda f: bool(re.search(r'^(discovery|DiscoverySNP|GBSSeqTo|HapmapFrom|ProductionSNP|SAMToGBS|SNPQuality|TagExport|VCFFromHDF5).*\.log$', f)),
                                                              rule_tassel_plugin_logs),
    (lambda f: bool(re.search(r'\.fa\.(amb|ann|bwt|pac|sa)$', f)), rule_bwa_index),
    (lambda f: bool(re.match(r'summary\d\.txt$', f)),         rule_summary_numbered),
    (lambda f: bool(re.match(r'TXBM21-25\d\.txt$', f)),       rule_txbm_summary),
    (lambda f: bool(re.search(r'(?:MLC|MAF)\d+\d\.txt$', f)),rule_tassel_summaries),
    (lambda f: bool(re.search(r'MAF\d+\.MLC\d+\.MISS', f)),   rule_gridtest_logs),
]


# ── Main processor ────────────────────────────────────────────────────────────

def reduce_tree(text: str) -> str:
    """Apply all collapse rules to a tree schematic string."""
    # Normalize non-breaking spaces (U+00A0) used by some `tree` versions
    text = text.replace('\xa0', ' ')
    lines = text.splitlines(keepends=True)

    out = []
    i = 0
    while i < len(lines):
        line = lines[i]
        f = filename(line)
        b = base_prefix(line)

        matched = False
        if '── ' in line:
            for predicate, handler in RULES:
                if predicate(f):
                    new_lines, i = handler(line, lines, i, b)
                    out.extend(new_lines)
                    matched = True
                    break

        if not matched:
            out.append(line)
            i += 1

    return ''.join(out)


def main():
    if len(sys.argv) < 2:
        print(__doc__)
        sys.exit(1)

    src = Path(sys.argv[1])
    dst = Path(sys.argv[2]) if len(sys.argv) > 2 else src

    if not src.exists():
        print(f"Error: {src} not found.", file=sys.stderr)
        sys.exit(1)

    text = src.read_text()
    orig_lines = len([l for l in text.splitlines() if l.strip()])

    result = reduce_tree(text)
    new_lines = len([l for l in result.splitlines() if l.strip()])
    reduction = 100 * (1 - new_lines / orig_lines) if orig_lines else 0
    tokens_saved = (orig_lines - new_lines) * 2.5

    # Backup original if overwriting
    if dst == src:
        shutil.copy(src, src.with_suffix(src.suffix + '.bak'))

    dst.write_text(result)

    print(f"Original:  {orig_lines:>5} non-empty lines  ({src})")
    print(f"Reduced:   {new_lines:>5} non-empty lines  ({dst})")
    print(f"Reduction: {reduction:.1f}%  (~{tokens_saved:.0f} tokens saved)")
    if dst == src:
        print(f"Backup:    {src.with_suffix(src.suffix + '.bak')}")


if __name__ == '__main__':
    main()
