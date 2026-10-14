#!/bin/bash
#
# scripts/run_cp_generic.sh — archive one varset's output to ECFS and the remote server.
# Usage: ./submit.sh [sbatch options] run_cp_generic.sh <datebeg> <dateend> <year_lim> <varset>
# Normally submitted by run_out_generic.sh. See README.md §7.
#----------------------------------------------------------------

set -x

#--- Repo location (set by submit.sh) ---------------------------
: "${ROOT_DIR:?ROOT_DIR is not set — submit this script through submit.sh, not plain sbatch (see README.md §10)}"
REPO_DIR="${ROOT_DIR}"

#--- Arguments --------------------------------------------------
datebeg=$1
dateend=$2
year_lim=$3
VARSET=$4

if [ -z "${VARSET}" ]; then
  echo "Usage: $0 <datebeg> <dateend> <year_lim> <varset>" >&2
  exit 1
fi

#--- Environment: site, experiment, varsets ---------------------
source "${REPO_DIR}/env.site.sh"
source "${REPO_DIR}/scripts/load_experiment.sh"
source "${REPO_DIR}/config/varsets.sh"

if [ -z "${VARSETS[$VARSET]+x}" ]; then
  echo "Unknown varset '${VARSET}'. Known varsets:" >&2
  printf ' %s\n' "${!VARSETS[@]}" >&2
  exit 1
fi

#--- Modules for the archive step -------------------------------
# shellcheck disable=SC2086
module load ${CP_MODULES}

export LD_LIBRARY_PATH="${LD_LIBRARY_PATH}:${NETCDF4_DIR}/lib"

#--- Variable list (all groups of the varset) -------------------
IFS=';' read -r -a groups <<< "${VARSETS[$VARSET]}"
var=()
for group in "${groups[@]}"; do
  IFS=',' read -r -a group_vars <<< "${group#*:}"
  var+=("${group_vars[@]}")
done

#--- Years ------------------------------------------------------
date

echo "$datebeg"
echo "$dateend"

yeari=$(echo "$datebeg" | cut -c1-4)
echo "$yeari"
yearf=$(echo "$dateend" | cut -c1-4)
echo "$yearf"

#--- Archive, grid by grid (ECFS, then remote) ------------------
for grid in "${GRIDS[@]}"; do
  echo "Archiving grid ${grid}: ${OUTPUT_DIR[$grid]} -> ${ECFS_BASE[$grid]}, ${REMOTE_HOST}:${REMOTE_BASE[$grid]}"
  cd "${OUTPUT_DIR[$grid]}" || exit 1

  for (( v=0; v<${#var[@]}; v++)); do
    emkdir -p "${ECFS_BASE[$grid]}/${var[$v]}"
    ecp -o "${var[$v]}"_* "${ECFS_BASE[$grid]}/${var[$v]}/"
  done

  for (( v=0; v<${#var[@]}; v++)); do
    scp "${var[$v]}"_*.nc "${REMOTE_HOST}:${REMOTE_BASE[$grid]}/${var[$v]}/raw"
  done
done

echo "$0 (${VARSET}) done."
