#!/bin/bash
#
# scripts/run_analysis.sh — submit the first job of every stream in ORDER.
# Usage: ./submit.sh run_analysis.sh <datebeg yyyymmdd> <dateend yyyymmdd> <year_lim yyyy>
# See README.md §0.
#----------------------------------------------------------------

set -x

#--- Repo location (set by submit.sh) ---------------------------
: "${ROOT_DIR:?ROOT_DIR is not set — submit this script through submit.sh, not plain sbatch (see README.md §0)}"
REPO_DIR="${ROOT_DIR}"

#--- Modules ----------------------------------------------------
intel_v="2021.4"
hdf5_v="1.12.2"
ncdf_v="4.9.3"
jasper_v="2.0.14"
nco_v="4.9.7"
module load prgenv/intel intel/${intel_v} hpcx-openmpi netcdf4/${ncdf_v} hdf5/${hdf5_v} jasper/${jasper_v} cdo nco/${nco_v} python3

export LD_LIBRARY_PATH="${LD_LIBRARY_PATH}:${NETCDF4_DIR}/lib"

#--- Arguments --------------------------------------------------
date

datebeg=$1
dateend=$2
year_lim=$3

echo "$datebeg"
echo "$dateend"

#--- Varsets ----------------------------------------------------
source "${REPO_DIR}/config/varsets.sh"

if [ "${#ORDER[@]}" -eq 0 ]; then
  echo "ORDER in config/varsets.sh is empty — nothing to submit. (With varsets_single.sh, uncomment one of its ORDER batches first.)" >&2
  exit 1
fi

#--- Submit each ORDER entry, 120 s apart -----------------------
for vs in "${ORDER[@]}"; do
  ${REPO_DIR}/submit.sh "run_out_generic.sh" "${datebeg}" "${dateend}" "${year_lim}" "${vs}"
  sleep 120
done

echo "$0 done."
