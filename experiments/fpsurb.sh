#!/bin/bash
#
# experiments/fpsurb.sh — FPS-URB-RCC urban downscaling (Paris)
#
# One file per experiment: which domains to process and, for each domain,
# where its WRF input is, where its CMORised output goes and where that
# output is archived. Selected by EXPERIMENT in env.site.sh (the file name
# without ".sh"), and also picks header_ini/fpsurb_*.ini.
#
# Every array below is keyed by grid (d01, d02, ...). Each grid listed in
# run[] needs an entry in all the others. Each processing job loops over
# all grids in run[] (d01, then d02), so enabling d02 makes every job
# longer: raise TIME[] in config/varsets.sh to match.
#----------------------------------------------------------------

# Per-varset working directories (namelists, compiled programs).
ROOT_RUN_DIR=$SCRATCH/fpsurb

# Grids to process. Only the keys matter (value 1 by convention); comment
# a line out to skip that grid. d02 is off for now (disk space).
declare -A run=(
  [d01]=1
#  [d02]=1
)

# CORDEX domain ID per grid — picks header_ini/fpsurb_<ID>_<grid>.ini and
# header_ini/fpsurb_global_<ID>_<grid>.ini.
declare -A DOMAIN_ID=(
  [d01]="EUR-12"
  [d02]="PARIS-3"
)

# Raw WRF output (wrfout_d0N_* / wrfxtrm_d0N_*) per grid.
declare -A OUTPUT_WRF=(
  [d01]=$SCRATCH/urb_wrf_run
  [d02]=$SCRATCH/urb_wrf_run
)

# CMORised output per grid. Must be a different directory for each grid:
# the archive step sends everything in it to that grid's archive paths.
declare -A OUTPUT_DIR=(
  [d01]=${ROOT_RUN_DIR}/output
  [d02]=${ROOT_RUN_DIR}/output_d02
)

# ECFS archive base per grid (emkdir/ecp).
declare -A ECFS_BASE=(
  [d01]="ec:FPS_URBAN/STAGE1/eval/output_d01"
  [d02]="ec:FPS_URBAN/STAGE1/eval/output_d02"
)

# Remote (scp) archive base per grid, on REMOTE_HOST (env.site.sh).
declare -A REMOTE_BASE=(
  [d01]="/media/Synology14/FPS_URBAN/eval/output_d01"
  [d02]="/media/Synology14/FPS_URBAN/eval/output_d02"
)
