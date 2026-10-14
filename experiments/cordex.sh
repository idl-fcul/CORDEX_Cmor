#!/bin/bash
#
# experiments/cordex.sh — EURO-CORDEX CMIP6 scenario run (ssp370)
#
# One file per experiment: which domains to process and, for each domain,
# where its WRF input is, where its CMORised output goes and where that
# output is archived. Selected by EXPERIMENT in env.site.sh (the file name
# without ".sh"), and also picks header_ini/cordex_*.ini.
#
# Every array below is keyed by grid (d01, d02, ...). Each grid listed in
# run[] needs an entry in all the others.
#----------------------------------------------------------------

# Per-varset working directories (namelists, compiled programs).
ROOT_RUN_DIR=$SCRATCH/ssp370

# Grids to process. Only the keys matter (value 1 by convention).
declare -A run=(
  [d01]=1
)

# CORDEX domain ID per grid — picks header_ini/cordex_<ID>_<grid>.ini and
# header_ini/cordex_global_<ID>_<grid>.ini.
declare -A DOMAIN_ID=(
  [d01]="EUR-12"
)

# Raw WRF output (wrfout_d0N_* / wrfxtrm_d0N_*) per grid.
declare -A OUTPUT_WRF=(
  [d01]=$SCRATCH/wrf_run
)

# CMORised output per grid (a different directory for each grid).
declare -A OUTPUT_DIR=(
  [d01]=${ROOT_RUN_DIR}/output
)

# ECFS archive base per grid (emkdir/ecp).
declare -A ECFS_BASE=(
  [d01]="ec:CORDEX/scenarios/ssp370/output"
)

# Remote (scp) archive base per grid, on REMOTE_HOST (env.site.sh).
declare -A REMOTE_BASE=(
  [d01]="/media/Synology14/CORDEX_CMIP6/scenarios/output/ssp370"
)
