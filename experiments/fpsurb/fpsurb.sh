#!/bin/bash
#
# experiments/fpsurb/fpsurb.sh — FPS-URB-RCC urban downscaling (Paris).
# Every array is keyed by grid (d01, d02, ...); each grid in run[] needs an
# entry in all of them. See README.md §2.
#----------------------------------------------------------------

#--- Working directory (one subfolder per varset) ---------------
ROOT_RUN_DIR=$SCRATCH/fpsurb

#--- Grids to process (comment a line out to skip it) ------------
declare -A run=(
  [d01]=1
#  [d02]=1
)

#--- Domain ID per grid (picks the grid's two ini files) --------
declare -A DOMAIN_ID=(
  [d01]="EUR-12"
  [d02]="PARIS-3"
)

#--- WRF input folder per grid ----------------------------------
declare -A OUTPUT_WRF=(
  [d01]=$SCRATCH/urb_wrf_run
  [d02]=$SCRATCH/urb_wrf_run
)

#--- Output folder per grid (a different one for each grid) -----
declare -A OUTPUT_DIR=(
  [d01]=${ROOT_RUN_DIR}/output
  [d02]=${ROOT_RUN_DIR}/output_d02
)

#--- ECFS archive path per grid ---------------------------------
declare -A ECFS_BASE=(
  [d01]="ec:FPS_URBAN/STAGE1/eval/output_d01"
  [d02]="ec:FPS_URBAN/STAGE1/eval/output_d02"
)

#--- Remote archive path per grid (on REMOTE_HOST) --------------
declare -A REMOTE_BASE=(
  [d01]="/media/Synology14/FPS_URBAN/eval/output_d01"
  [d02]="/media/Synology14/FPS_URBAN/eval/output_d02"
)
