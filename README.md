# Guide to CMORising WRF Output

[![shellcheck](https://github.com/ritamcardoso/CORDEX_Cmor/actions/workflows/shellcheck.yml/badge.svg)](https://github.com/ritamcardoso/CORDEX_Cmor/actions/workflows/shellcheck.yml)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](LICENSE)

These Fortran programs and accompanying scripts extract and convert WRF
output into CMOR-compliant format on a yearly basis, and archive the result
to ECFS and a remote server.

This used to be two dozen near-duplicate submission scripts, one per
variable group, each with its own hardcoded paths and variable list. It's
now 3 generic scripts driven by one small config file
(`config/varsets.sh`) plus one site-specific settings file
(`env.site.sh`) — everything below walks through the full setup, start to
finish.

## 1. Directory Setup

Place all files and subfolders into a single root directory, maintaining
the provided folder structure:

```
f90_src/       <- Fortran source (RCM_sfc_*.f90, RCM_plev_*.f90, RCM_zlev_*.f90, ...)
header/        <- per-variable namelist headers
header_ini/    <- per-domain grid/global config (see header_ini/README.md)
config/        <- varsets.sh: the single source of truth for variables/programs/scheduling (see config/README.md);
                  varsets_single.sh: the same without chaining (§10)
scripts/       <- the 3 generic job scripts
env.site.sh.example, LICENSE, README.md, MIGRATION.md
```

This root directory is referred to as `ROOT_DIR` everywhere below — see
[§9, Where the code lives](#9-where-the-code-lives-root_dir) for how the
scripts find it. It does not need to be, and generally shouldn't be, the
same directory you submit jobs from.

## 2. Configuration (`header_ini`)

Update the grid and global experiment characteristics in the `header_ini` files to match your
specific simulation (see [`header_ini/README.md`](header_ini/README.md)
for the full filename pattern):

* **Domain & Geography:** in `<EXPERIMENT>_<DOMAIN_ID>_<grid>.ini` (e.g.
  `cordex_EUR-12_d01.ini`), update the domain of the output file (and
  the matching `geog` name).

  * **Directories:** now set in `env.site.sh` (§4) as `OUTPUT_WRF` (raw
    `wrfout` location) and `OUTPUT_DIR` (CMORised-output destination), not
    in the `.ini` files — the `.ini` files just hold the
    `_OUTPUT_WRF_`/`_OUTPUT_DIR_` placeholders `run_out_generic.sh`
    substitutes at run time. `cordex_EUR-12_d01.ini`), update the domain of the output file (and
    the matching `geog` name).
  * **Naming Conventions:** change the general domain and model names used
  for the CMORised variables (`dom`/`outdom`, same file).

* **Global Properties:** edit `<EXPERIMENT>_global_<DOMAIN_ID>_<grid>.ini`
  (e.g. `cordex_global_EUR-12_d01.ini`) — the global characteristics of
  the variables, tailored to your experiment. `<EXPERIMENT>` and
  `<DOMAIN_ID>` must match what you set in `env.site.sh`'s
  `EXPERIMENT[]`/`DOMAIN_ID[]` maps for that grid (§4) — every
  `<EXPERIMENT>`/`<DOMAIN_ID>` pair needs **both** an
  `<EXPERIMENT>_<DOMAIN_ID>_<grid>.ini` and a matching
  `<EXPERIMENT>_global_<DOMAIN_ID>_<grid>.ini`; a domain-ID mismatch
  between the two (one says `EUR-12`, the other `EUR-11`, say) will break
  the lookup for whichever one doesn't match `DOMAIN_ID[]`. These must
  also match the official CORDEX-CMIP6 controlled vocabulary — see
  [`header_ini/README.md`](header_ini/README.md) and
  [WCRP-CORDEX/cordex-cmip6-cv](https://github.com/WCRP-CORDEX/cordex-cmip6-cv)
  for the valid values.

## 3. Headers (`header` folder)

The `header` folder contains the specific namelist header for each
variable (`header_<var>`). Under normal circumstances you do not need to
modify these files — the scripts assemble a full namelist per run by
concatenating the relevant `header_<var>` onto the `header_ini` grid config
(see `run_out_generic.sh`'s processing loop).

## 4. Site Environment (`env.site.sh`)

This is the one file that's genuinely different per user/machine, and the
only one you need to edit once you setup the header_ini files :

```bash
cp env.site.sh.example env.site.sh
# then edit it
```

* **Paths** — `PROG_DIR`, `HEADER_DIR`, `HEADER_INI_DIR` (all derived from
  `ROOT_DIR`, so you don't repeat yourself), and `RUN_DIR` — the scratch
  working directory each run processes in. Each run generates its own
  namelist and works in this folder; don't change that behaviour, just
  point it wherever you want the scratch data to live.
* **Compiler/library versions** — `intel_v`, `hdf5_v`, `netcdf_v`, `FC`,
  `FFLAGS`, and the NetCDF/HDF5 include/lib paths.
* **Domains** — `run` is the set of grids to process, keyed the same way
  as `DOMAIN_ID[]` below it (only the keys matter; the value is unused,
  `1` by convention) — e.g. `run=([d01]=1)`, plus a matching entry in
  `DOMAIN_ID[]` (e.g. `[d01]="EUR-12"`) for each. Together with
  `EXPERIMENT` (below) these select `<EXPERIMENT>_<DOMAIN_ID>_<grid>.ini` /
  `<EXPERIMENT>_global_<DOMAIN_ID>_<grid>.ini` out of `header_ini/` — see
  [`header_ini/README.md`](header_ini/README.md). Add as many
  `run`/`DOMAIN_ID` entries as you need, provided you have a matching
  `header_ini` file for each. Comment a grid's line out in `run` to
  disable it without deleting its `DOMAIN_ID` entry.
* **Experiment + raw/output directories** — `EXPERIMENT` (the campaign
  prefix, `cordex` for standard CORDEX-CMIP6 runs or `fpsurb` for
  FPS-URB-RCC runs), `OUTPUT_WRF` (raw `wrfout` location) and `OUTPUT_DIR`
  (CMORised-output destination, sed'd into each `.ini` file's
  `_OUTPUT_WRF_`/`_OUTPUT_DIR_` placeholders at run time). **Unlike
  `DOMAIN_ID`, these three are single site-wide values, not per-grid** —
  an experiment always spans every grid in `run` together (`cordex` only
  ever runs `d01`; `fpsurb` runs `d01` *and* `d02` at once, just on
  different domain IDs — `EUR-12` and `PARIS-3` respectively).
  `env.site.sh.example` ships two ready-made blocks (CORDEX vs.
  urban-downscaling); uncomment whichever matches what you're currently
  running, together with the matching `run`/`DOMAIN_ID` entries above.
  **Uncomment the whole block, not just some lines** — the two blocks
  work by plain sequential reassignment (the urban block, being lower in
  the file, simply overwrites `EXPERIMENT`/`ROOT_RUN_DIR`/`OUTPUT_DIR`/
  `OUTPUT_WRF` if you leave the CORDEX block active above it), so leaving
  any one of those four commented out in the block you actually want
  silently keeps that variable's CORDEX-block value instead.
* **Archive step settings** — `CP_MODULES`, `CP_RUN_DIR`, `ECFS_BASE`,
  `REMOTE_HOST`, `REMOTE_BASE` (see [§7, Archiving](#7-archiving)).

`env.site.sh` is gitignored — it never gets committed.

* **Slurm job settings** — `JOB_ACCOUNT`, `JOB_MAIL_TYPE`,
  `JOB_MAIL_USER`, `JOB_CHDIR`. `submit.sh` passes them to every job as
  `--account` / `--mail-type` / `--mail-user` / `--chdir` (see
  [§6](#6-submission-scripts-scripts-folder)). Leave one empty to not pass
  that flag.

## 5. Variable Sets (`config/varsets.sh`)

It's the single place that defines every variable group ("varset"), what Fortran program(s) process it, how
long to schedule it for, and how it chains to other varsets. You will
rarely need to touch anything else once this is set up.

**[`config/README.md`](config/README.md) covers this file in full**,
including how to turn off the legacy self-resubmission chaining if you
just want one-shot runs, and how to cut it down to only the variables you
need. Variable names follow the
[CORDEX-CMIP6 data request](https://github.com/WCRP-CORDEX/data-request-table),
and the Fortran programs referenced in each entry correspond to
[CORDEX-WRF-community/WRF-CMORizer](https://github.com/CORDEX-WRF-community/WRF-CMORizer/tree/main) —
see `config/README.md` before adding a variable this repo doesn't have a
program for yet.

### Fortran program naming

Each varset maps to one or more variable "groups", each with its own
program pattern:

```
[out1]="RCM_sfc_VAR:tas,ts,th,..."                # RCM_sfc_tas.f90, RCM_sfc_ts.f90, ...
[cloud1]="RCM_sfc_cloud:clh,clm"                  # always RCM_sfc_cloud.f90
[plev_ta]="RCM_plev_ta:ta1000,ta925,...,ta30"      # always RCM_plev_ta.f90, all 16 levels
[zlev_uava0]="RCM_zlev_uava:va50m,va150m,va100m"   # always RCM_zlev_uava.f90
```

`VAR` in a program pattern gets substituted with the current variable; a
pattern without `VAR` is used as-is for every variable in that group.
Per-variable programs turn out to be **the exception, not the rule** once
you include plev/zlev:

- **sfc**: mostly per-variable (`RCM_sfc_<var>`) — `out`, `soil`, `snw`,
  `tau`, `wpth`. But `cloud` → always `RCM_sfc_cloud`, `wxtrm` → always
  `RCM_sfc_xtrm`, and `rad` → always `RCM_sfc_rad` (14 radiation variables,
  one fixed program).
- **plev**: always one fixed program per family, covering every pressure
  level in one program (`RCM_plev_ta.f90` handles `ta1000`...`ta30`).
- **zlev**: same — one fixed program per family, covering every height
  level (`RCM_zlev_ua.f90` handles `ua50m`, `ua100m`, `ua150m`, ...).

`plev_uava` and `zlev_uava0`/`zlev_uava1` process `ua`and `va` variables through a
program literally named `RCM_plev_uava` / `RCM_zlev_uava` — that's how the
source names those programs, not a bug in this config.

To extract the fixed variables `VAR`is set to `fx`
`run_out_fx.sh` (`orog`, `sftlaf`, `sftlf`, `sfturf`, `sftgif` →
`RCM_fx_<var>`) 
`[fx]="RCM_fx_VAR:orog,sftlaf,sftlf,sfturf,sftgif"`It is not called in Analysis since
is independent of time. Call as a single `VARSET` see §10 (Extracting a single variable/varset). 

### Scheduling and chaining

Alongside `VARSETS[]`, the same file holds:

* **`TIME[]`** — walltime to request for each varset's processing job.
* **`CP_TIME[]`** / **`DEFAULT_CP_TIME`** — walltime for each varset's
  archive job.
* **`ORDER`** — the varsets `run_analysis.sh` submits directly (see
  [§10](#10-job-submission-instructions)).
* **`NEXT[]`** and **`ADVANCE_YEAR[]`** — see
  [§8, Chaining behaviour](#8-chaining-behaviour).
* **`CP_EXTRA[]`** — see [§7, Archiving](#7-archiving).

See [§11, Adding/changing a variable set](#11-addingchanging-a-variable-set)
for how to extend this file.

## 6. Submission Scripts (`scripts` folder)

Only 3 scripts now, each replacing what used to be a whole family of
per-variable files:

| Script | Replaces | Role |
|---|---|---|
| `run_out_generic.sh` | all `run_out_*.sh` | processes one varset for a year range, then submits the archive job and (if configured) the next varset in the chain |
| `run_cp_generic.sh` | all `run_cp_*.sh` | archives one varset's output to ECFS + remote |
| `run_analysis.sh` | itself (orchestrator) | submits every varset in `ORDER`, 120s apart |

**Slurm account/mail/chdir:** set once in `env.site.sh` (`JOB_ACCOUNT`,
`JOB_MAIL_TYPE`, `JOB_MAIL_USER`, `JOB_CHDIR` — §4), not in the scripts.
`#SBATCH` lines are read by `sbatch` before a script starts, so a script
can't load them from a file itself; instead every job is submitted through
`submit.sh`, which reads those four values from `env.site.sh` and passes
them on the `sbatch` command line. That includes the jobs the scripts
submit for each other, so **submit your first job through `submit.sh`
too** (§10) — a job started with plain `sbatch` won't get these settings.

The 3 scripts are fully generic — you should not need to edit them.

## 7. Archiving

After processing each varset, `run_out_generic.sh` unconditionally submits
`run_cp_generic.sh` for the same varset — matching the original scripts'
unconditional call to their `run_cp_<varset>.sh` sibling. It reads the same
`VARSETS[<varset>]` entry, flattens every group into one plain variable
list, and archives each `<var>_*.nc` to ECFS and a remote server. There's
nothing varset-specific to write — adding a new varset to
`config/varsets.sh` automatically gets archiving for free.

`plev_uava`, `zlev_uava0`, and `zlev_uava1`  *process* the u and v-components 
so their archive step needs two calls, not one. `CP_EXTRA[]` in `config/varsets.sh`
 names the "u" companion varset to also archive (`plev_ua`, `zlev_ua0`, `zlev_ua1` respectively —
reactivated from the deprecated block purely for this, since they're not
used for processing and aren't in `ORDER`/`NEXT`/`TIME`). When
`CP_EXTRA[$VARSET]` is set, `run_out_generic.sh` submits a second
`run_cp_generic.sh` job for that companion.

The archive step's modules and remote paths (which differ from the
compile/run environment) live in `env.site.sh`: `CP_MODULES`, `CP_RUN_DIR`,
`ECFS_BASE`, `REMOTE_HOST`, `REMOTE_BASE`.

## 8. Chaining behaviour

Each varset's year loop resubmits another varset when it finishes (`NEXT[]`
in `config/varsets.sh`). The varsets are arranged in 10 parallel
"streams", balanced on measured run times so each takes about the same
time per model year (~21h) — the table at the top of `config/varsets.sh`
lists them:

- **2-hop chains**: `plev_uava→wxtrm`, `cloud1→wpth1`, `cloud2→wpth3`,
  `plev_zg→snw`, `plev_ta→wpth2`, `rad→out1`
- **3-hop chains**: `plev_wa→zlev_hus→zlev_ta`, `plev_hus→soil→out2`
- **Self-loops** (resubmits itself each year): `zlev_uava0`, `zlev_uava1`

`ORDER` holds the first link of each stream. Exactly one link per stream
advances `yeari`/`yearf` (`ADVANCE_YEAR[]`) — the last one before the
chain returns to its first link — so each stream advances one year per
full round-trip, not per hop.

To rebalance (e.g. after run times change), run `report_walltimes.sh` and
move variables between varsets: every program runs once per variable or
level, so any varset can be split.

## 9. Where the code lives (`ROOT_DIR`)

This repo can live anywhere (e.g. `$HPCPERM/CORDEX/scenarios/Analysis`)
— it does **not** need to be checked out into your submission/scratch
directory. There's nothing to export: `submit.sh` works out `ROOT_DIR`
from its own location and passes it to every job it submits (and the
scripts submit their follow-up jobs through it too).

To submit from another directory (e.g. `$SCRATCH/Analysis`), call
`submit.sh` by its path, or put a symlink to it there:

```bash
cd $SCRATCH/Analysis
ln -s $HPCPERM/CORDEX/scenarios/Analysis/submit.sh .
./submit.sh run_analysis.sh 20010101 20011231 2005
```

The symlink is resolved, so `ROOT_DIR` still points at the repo. (The
scripts themselves can't find the repo from `$0`, because Slurm runs a
spooled copy of them — which is why they must be submitted through
`submit.sh` rather than plain `sbatch`.)

This is completely independent of:
- **where you submit from** — anywhere, e.g. `$SCRATCH/Analysis` (set
  `JOB_CHDIR` in `env.site.sh` if you want job logs to land there)
- **`RUN_DIR`** (`env.site.sh`) — per-run scratch working directory used
  while processing (e.g. `$SCRATCH/ssp370/out`)
- **`CP_RUN_DIR`** (`env.site.sh`) — where finished output files land
  before archiving (e.g. `$SCRATCH/ssp370/output`)

## 10. Job Submission Instructions

### First-time setup checklist

1. Check out this repo somewhere permanent — that's `ROOT_DIR` (found
   automatically by `submit.sh`, nothing to export).
2. Fill in `header_ini/` and confirm `header/` (§2, §3).
3. `cp env.site.sh.example env.site.sh` and fill it in (§4).
4. Check `config/varsets.sh` covers the variables you need (§5) —
   `MIGRATION.md` maps old script names to varsets if you're coming from
   the previous per-variable-script layout.
5. In `env.site.sh`, fill in `JOB_ACCOUNT`, `JOB_MAIL_USER` and
   `JOB_CHDIR` (§4, §6) — nothing to edit in `scripts/`.

### Standard submission

`run_analysis.sh` is the main controller — it submits every varset in
`ORDER` (`config/varsets.sh`), each of which manages its own dependencies
via `NEXT[]`, submitting some archival/follow-up tasks as soon as its own
processing finishes. `year_lim` is a failsafe: it stops each chain's
self-resubmission at a specific year so a stuck loop doesn't run forever.

```bash
cd $SCRATCH/Analysis   # or wherever you want to submit from — doesn't have to be ROOT_DIR

# Syntax
./submit.sh run_analysis.sh <datebeg> <dateend> <year_lim>

# Example: process 2001, then keep chaining year by year until 2005
./submit.sh run_analysis.sh 20010101 20011231 2005
```

Always submit through `submit.sh` (not plain `sbatch`): it's what applies
the `env.site.sh` job settings (§6).

### Extracting a single variable/varset

Check `config/varsets.sh` (or `MIGRATION.md` if you're looking for where an
old `run_out_<x>.sh` script went) to find which varset covers your
variable, then submit it directly — no file to modify:

```bash
./submit.sh --job-name=wrf-soil --time=12:00:00 --mem=8G \
       --output=wrf-soil.%j.out --error=wrf-soil.%j.out \
       run_out_generic.sh 19900101 19901231 2000 soil
```

### Extracting multiple years in a single submission

Set `datebeg`/`dateend` to span the whole period you want processed in one
job — `run_out_generic.sh`'s internal year loop already handles a range.

**Take care with `NEXT[]`.** With the normal `config/varsets.sh`, a job
that finishes resubmits the next varset in its chain (`NEXT[]`, §8), and
that chain keeps going year by year until `year_lim`. That is what you
want for a production run, but not for a one-off extraction: you would
start a whole stream, not one job.

For one-off or multi-year extractions, use the no-chaining config,
**`config/varsets_single.sh`**. It has the same varsets, time limits and
memory, but `NEXT[]` is empty, so every job processes its years, archives
them, and stops. To use it, keep a copy of the chained file and put the
single one in its place:

```bash
cd $ROOT_DIR    # the repo
cp config/varsets.sh        config/varsets_chain.sh   # keep the original
cp config/varsets_single.sh config/varsets.sh         # no chaining from now on
```

and to go back to production runs:

```bash
cp config/varsets_chain.sh config/varsets.sh
```

Every job reads `config/varsets.sh` when it **starts**, so only switch when
no chained jobs are queued or running — otherwise those streams stop at
their next link.

Then submit the varset directly. The `TIME[]` limits are for **one** model
year, so scale `--time` to the number of years yourself (and stay within the
queue's maximum walltime — split long periods into several jobs):

```bash
# Process 2001-2005 of soil in one job (~5h per year -> 5 x 5h, plus margin)
./submit.sh --job-name=wrf-soil --time=32:00:00 --mem=8G \
       --output=wrf-soil.%j.out --error=wrf-soil.%j.out \
       run_out_generic.sh 20010101 20051231 2005 soil
```

`run_analysis.sh` works with `varsets_single.sh` too, but its `ORDER` is
empty by default: without chaining, everything listed runs at once, so
uncomment one of the two batches in the file (10 varsets each) and keep
each job to one year.

(Without switching files, setting `year_lim` to a year **before** the start
year also stops the chaining, since the resubmission check
`yeari <= year_lim` is then false — but that is easy to get wrong, and a
mistake starts a full chain.)

## 11. Adding/changing a variable set

Edit **only** `config/varsets.sh`:

```bash
declare -A VARSETS=(
  ...
  [my_new_set]="RCM_sfc_VAR:varA,varB,varC"          # per-variable program
  # or: [my_new_set]="RCM_sfc_myprog:varA,varB,varC" # one fixed program
)
declare -A TIME=(
  ...
  [my_new_set]="04:00:00"
)
```

Add it to `ORDER` if it should be submitted directly by `run_analysis.sh`,
to `NEXT[]` if some varset should chain into (or from) it, and to
`ADVANCE_YEAR[]=1` if it should advance the year before resubmitting.
If its jobs need more than the default 8G of memory, add a `MEM[]` entry
(e.g. `[my_new_set]="16G"`); otherwise it uses `DEFAULT_MEM`.

## Notes / things to double check before first real run

- The compile step (Fortran module + subs + program) still runs once per
  variable, per year, exactly as in the original — including recompiling
  the same fixed program (e.g. `RCM_sfc_rad.f90`, `RCM_plev_ta.f90`)
  repeatedly for each variable/level in its group. Harmless, just matches
  the original's per-variable compile pattern.
- Scripts use `#!/bin/bash` explicitly (not `#!/bin/sh`) since they rely on
  bash associative arrays — the originals already used bash-only syntax
  under a `#!/bin/sh` shebang, which only worked if `/bin/sh` happened to be
  bash on your system. This makes that assumption explicit and portable.
- `TIME[]` values for `out` and `plev_ta` were confirmed against the live
  scripts; the rest are carried over/estimated and worth a check — `rad`
  and `snw` especially, since what they cover just changed.
- `CP_TIME[]` (archive-step walltime) is only confirmed for `out`
  (`20:00:00`, from the live `run_cp_out.sh`); everything else falls back
  to `DEFAULT_CP_TIME` (`04:00:00`) until you've checked real numbers.
- `plev_va`, `zlev_va0`, `zlev_va1` are disabled on purpose (old/superseded
  versions) — commented out at the bottom of `config/varsets.sh` rather
  than deleted, so they're easy to compare against or resurrect.
  `plev_ua`, `zlev_ua0`, `zlev_ua1` are also disabled *for processing*, but
  reactivated as archive-only `VARSETS[]` entries (see §7, above).
