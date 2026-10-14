#!/bin/bash
#SBATCH --qos=nf
#SBATCH --nodes=1
#SBATCH --ntasks=1
#SBATCH --hint=nomultithread

# ------------------------------------------------------------------
#  Nothing site-specific lives in this file: --account / --mail-type /
#  --mail-user / --chdir come from env.site.sh (JOB_* settings), passed in
#  by submit.sh.
#
#  Run using:
#
#  ./submit.sh run_analysis.sh \
#         [initial date - yyyymmdd] [final date - yyyymmdd] [loop year limit - yyyy]
#
#  Use submit.sh rather than plain sbatch, or the env.site.sh job
#  settings won't be applied.
#
#  You can submit from anywhere (e.g. $SCRATCH/Analysis): call submit.sh by
#  its path or through a symlink — it finds the repo itself.
#-------------------------------------------------------------------

set -x

# ROOT_DIR is set by submit.sh (from its own location) and passed into the
# job. It can't be worked out here from $0, because Slurm runs a spooled
# copy of this script, not the file in the repo.
: "${ROOT_DIR:?ROOT_DIR is not set — submit this script through submit.sh, not plain sbatch (see README.md §10)}"
REPO_DIR="${ROOT_DIR}"

#### Load libraries used by this orchestration step only
intel_v="2021.4"
hdf5_v="1.12.2"
ncdf_v="4.9.3"
jasper_v="2.0.14"
nco_v="4.9.7"
module load prgenv/intel intel/${intel_v} hpcx-openmpi netcdf4/${ncdf_v} hdf5/${hdf5_v} jasper/${jasper_v} cdo nco/${nco_v} python3

export LD_LIBRARY_PATH="${LD_LIBRARY_PATH}:${NETCDF4_DIR}/lib"

date

datebeg=$1
dateend=$2
year_lim=$3

echo "$datebeg"
echo "$dateend"

source "${REPO_DIR}/config/varsets.sh"

if [ "${#ORDER[@]}" -eq 0 ]; then
  echo "ORDER in config/varsets.sh is empty — nothing to submit. (With the no-chaining varsets_single.sh, uncomment one of its ORDER batches first.)" >&2
  exit 1
fi

for vs in "${ORDER[@]}"; do
  ${REPO_DIR}/submit.sh --job-name="wrf-${vs}" --time="${TIME[$vs]}" --mem="${MEM[$vs]:-$DEFAULT_MEM}" \
         --output="wrf-${vs}.%j.out" --error="wrf-${vs}.%j.out" \
         "run_out_generic.sh" "${datebeg}" "${dateend}" "${year_lim}" "${vs}"
  sleep 120
done

echo "$0 done."
