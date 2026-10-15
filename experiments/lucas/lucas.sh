#!/bin/bash
#
# experiments/lucas/lucas.sh — EURO-CORDEX CMIP6 scenario run (ssp370).
# Every array is keyed by grid (d01, d02, ...); each grid in run[] needs an
# entry in all of them. See README.md §2.
#----------------------------------------------------------------

#
#--- Working directory (one subfolder per varset) ---------------
# Each varset works (namelists, compiled programs) in ${ROOT_RUN_DIR}/<varset>.
#
ROOT_RUN_DIR=$SCRATCH/ssp370

#
#--- Grids to process (comment a line out to skip it) ------------
# Only the keys matter; every job processes these grids in order (d01, d02, ...).
# Enabling a second grid makes every job longer: raise TIME[] to match.
#
declare -A run=(
  [d01]=1
)

#
#--- Domain ID per grid (picks the grid's two ini files) --------
# Picks the grid's <name>_<DOMAIN_ID>_<grid>.ini and
# <name>_global_<DOMAIN_ID>_<grid>.ini in this folder.
#
declare -A DOMAIN_ID=(
  [d01]="EUR-12"
)

#
#--- WRF input folder per grid ----------------------------------
# Where the raw wrfout_d0N_* / wrfxtrm_d0N_* files are.
#
declare -A OUTPUT_WRF=(
  [d01]=$SCRATCH/wrf_run
)

#
#--- Output folder per grid (a different one for each grid) -----
# Where the CMORised files are written; it is also what the archive step
# copies from, so each grid needs its own.
#
declare -A OUTPUT_DIR=(
  [d01]=${ROOT_RUN_DIR}/output
)

#
#--- ECFS archive path per grid ---------------------------------
# ECFS base path; each variable goes to <path>/<var>/.
#
declare -A ECFS_BASE=(
  [d01]="ec:LUCAS/scenarios/ssp370/output"
)

#
#--- Remote archive path per grid (on REMOTE_HOST) --------------
# Base path on REMOTE_HOST (env.site.sh); each variable goes to <path>/<var>/raw.
#
declare -A REMOTE_BASE=(
  [d01]="/media/Synology14/LUCAS/scenarios/output/ssp370"
)
