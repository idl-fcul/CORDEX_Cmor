#!/bin/bash
#
# experiments/cordex/cordex.sh — EURO-CORDEX CMIP6 scenario run (ssp370).
# Every array is keyed by grid (d01, d02, ...); each grid in run[] needs an
# entry in all of them. See README.md §2.
#----------------------------------------------------------------

#--- Working directory (one subfolder per varset) ---------------
ROOT_RUN_DIR=$SCRATCH/ssp370

#--- Grids to process (comment a line out to skip it) ------------
declare -A run=(
  [d01]=1
)

#--- Domain ID per grid (picks the grid's two ini files) --------
declare -A DOMAIN_ID=(
  [d01]="EUR-12"
)

#--- WRF input folder per grid ----------------------------------
declare -A OUTPUT_WRF=(
  [d01]=$SCRATCH/wrf_run
)

#--- Output folder per grid (a different one for each grid) -----
declare -A OUTPUT_DIR=(
  [d01]=${ROOT_RUN_DIR}/output
)

#--- ECFS archive path per grid ---------------------------------
declare -A ECFS_BASE=(
  [d01]="ec:CORDEX/scenarios/ssp370/output"
)

#--- Remote archive path per grid (on REMOTE_HOST) --------------
declare -A REMOTE_BASE=(
  [d01]="/media/Synology14/CORDEX_CMIP6/scenarios/output/ssp370"
)
