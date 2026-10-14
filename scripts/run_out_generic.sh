#!/bin/bash
#
# scripts/run_out_generic.sh
#
# Generic replacement for run_out.sh, run_out_rad.sh, run_out_soil.sh, ...
# (all run_out_* variants in this repo). Which variables/programs it runs is
# looked up from config/varsets.sh using the 4th argument.
#
# No #SBATCH lines and nothing site-specific in this file: --qos /
# --nodes / --ntasks / --hint / --account / --mail-type / --mail-user /
# --chdir all come from env.site.sh (JOB_* settings), passed in by
# submit.sh — which is also how this script submits its own follow-up
# jobs.
#
# Usage:
#   ./submit.sh --job-name=wrf-<varset> --time=<hh:mm:ss> --mem=<size> \
#          --output=wrf-<varset>.%j.out --error=wrf-<varset>.%j.out \
#          run_out_generic.sh <datebeg> <dateend> <year_lim> <varset>
#
# You can submit from anywhere (e.g. $SCRATCH/Analysis): call submit.sh by
# its path or through a symlink — it finds the repo itself.
#
# (--job-name / --time / --mem / --output / --error are set per varset on
#  the submit.sh command line, so there's no separate file per varset.)
#
# At the end of its year loop this script also submits
# scripts/run_cp_generic.sh for the same varset (archiving to ECFS/remote),
# unconditionally — matching the original scripts' unconditional call to
# their run_cp_<varset>.sh sibling — plus a second cp call for its "u"
# companion where config/varsets.sh:CP_EXTRA[<varset>] is set (plev_uava,
# zlev_uava0, zlev_uava1). It then re-submits itself for whatever
# config/varsets.sh:NEXT[<varset>] points to (only if year_lim hasn't been
# reached yet) — mirroring the original scripts' self/pair-resubmission
# pattern (e.g. out<->soil, or zlev_ta<->plev_ta).
#----------------------------------------------------------------

set -x

# ROOT_DIR is set by submit.sh (from its own location) and passed into the
# job. It can't be worked out here from $0, because Slurm runs a spooled
# copy of this script, not the file in the repo.
: "${ROOT_DIR:?ROOT_DIR is not set — submit this script through submit.sh, not plain sbatch (see README.md §10)}"
REPO_DIR="${ROOT_DIR}"

date1=$1
date2=$2
date3=$3
VARSET=$4

datebeg=${date1}
dateend=${date2}
year_lim=${date3}

if [ -z "${VARSET}" ]; then
  echo "Usage: $0 <datebeg> <dateend> <year_lim> <varset>" >&2
  exit 1
fi

#----------------------------------------------------------------
#                          ENVIRONMENT                            |
#----------------------------------------------------------------
# site/user-specific paths, modules, compiler flags -> env.site.sh
source "${REPO_DIR}/env.site.sh"

# experiment: grids, and per grid the WRF input / output / archive paths
# -> experiments/${EXPERIMENT}.sh
source "${REPO_DIR}/scripts/load_experiment.sh"

# variable-set definitions, walltimes, chaining -> config/varsets.sh
source "${REPO_DIR}/config/varsets.sh"

if [ -z "${VARSETS[$VARSET]+x}" ]; then
  echo "Unknown varset '${VARSET}'. Known varsets:" >&2
  printf ' %s\n' "${!VARSETS[@]}" >&2
  exit 1
fi

# The xtrm variant of the grid/domain-setup ini (<exp>_xtrm_<dom_id>_<grid>.ini,
# sourced from wrfxtrm rather than wrfout — see header_ini/README.md) is only
# correct for the varset that actually runs RCM_sfc_xtrm. Every other varset
# keeps using the plain <exp>_<dom_id>_<grid>.ini.
wrffile="wrfout"
if [ "${VARSET}" = "wxtrm" ] || [ "${VARSET}" = "testex" ]; then
  wrffile="wrfxtrm"
fi

# EXPERIMENT also picks the header_ini files (<exp>_<DOMAIN_ID>_<grid>.ini).
exp="${EXPERIMENT}"

# VARSETS[$VARSET] looks like "PROGRAM_A:var1,var2;PROGRAM_B:var3,var4"
# (one or more ';'-separated groups; each a program pattern + its variables)
IFS=';' read -r -a groups <<< "${VARSETS[$VARSET]}"

#----------------------------------------------------------------
#                        Processing                               |
#----------------------------------------------------------------
date

echo $datebeg
echo $dateend

yeari=`echo $datebeg | cut -c1-4`
echo $yeari
yearf=`echo $dateend | cut -c1-4`
echo $yearf

RUN_DIR="${ROOT_RUN_DIR}/${VARSET}"
mkdir -p "${RUN_DIR}"

cd "${RUN_DIR}" || exit 1
#
#  Time Loop (yeari <= yearf; it is usually =)
#
for(( j = ${yeari}; j <= ${yearf}; j++ )) ; do

 START_YY=`echo ${j}`
 END_YY=`echo ${j}`
#
# Domain
#
 for grid in "${GRIDS[@]}"; do

  dom_id="${DOMAIN_ID[${grid}]}"
  mkdir -p "${OUTPUT_DIR[${grid}]}"

  cp ${HEADER_INI_DIR}/${exp}_global_${dom_id}_${grid}.ini  global_data.inp

#
# Variables (a varset can have more than one group — see config/varsets.sh)
#
  for group in "${groups[@]}"; do
   prog_pattern="${group%%:*}"
   IFS=',' read -r -a var <<< "${group#*:}"

   for (( v=0; v<${#var[@]}; v++)); do
#
#  Create list from header_d0?.ini + header_[var]
#
    sed \
     -e "s|_START_YY_|$START_YY|g" \
     -e "s|_END_YY_|$END_YY|g" \
     -e "s|_WRFFILE_|${wrffile}|g" \
     -e "s|_OUTPUT_WRF_|${OUTPUT_WRF[${grid}]}/|g" \
     -e "s|_OUTPUT_DIR_|${OUTPUT_DIR[${grid}]}/|g" \
     "${HEADER_INI_DIR}/${exp}_${dom_id}_${grid}.ini" \
     > "${RUN_DIR}/header_${grid}"
    
    cat header_${grid} > inputlist.inp
    echo "!" >> inputlist.inp
    echo "! Variable" >> inputlist.inp
    echo "!" >> inputlist.inp
    cat ${HEADER_DIR}/header_${var[$v]} >> inputlist.inp
    echo "!" >> inputlist.inp
    echo "/" >> inputlist.inp
#
# Program name: literal, or with "VAR" substituted for the current variable
# (see config/varsets.sh header comment for examples).
#
    PROG_NAME="${prog_pattern/VAR/${var[$v]}}"
#
# Compiling
#
    $FC $FFLAGS -c "${PROG_DIR}/${MOD_NAME}.f90"
    $FC $FFLAGS -c "${PROG_DIR}/${SUB_NAME}.f90" $NC_INC
    $FC $FFLAGS ${PROG_DIR}/${PROG_NAME}.f90 ${MOD_NAME}.o ${SUB_NAME}.o -o ${PROG_NAME}.exe $ALL_LIBS

    ./${PROG_NAME}.exe

    rm inputlist.inp
    rm header_${grid}

   done #var
  done #group
 done #domain (grid)
done #year

#----------------------------------------------------------------
# Archive this varset's output (config/varsets.sh: CP_TIME[]) — matches the
# original scripts' unconditional call to their run_cp_<varset>.sh sibling.
# plev_uava/zlev_uava0/zlev_uava1 need a second cp call for their "u"
# companion (config/varsets.sh: CP_EXTRA[]), since they only process "v"
# but the underlying programs also produce matching "u" files.
#----------------------------------------------------------------
# cd ${REPO_DIR}
 ${REPO_DIR}/submit.sh --job-name="cp-${VARSET}" --time="${CP_TIME[$VARSET]:-$DEFAULT_CP_TIME}" \
       --output="cp-${VARSET}.%j.out" --error="cp-${VARSET}.%j.out" \
       "run_cp_generic.sh" "${datebeg}" "${dateend}" "${year_lim}" "${VARSET}"

extra="${CP_EXTRA[$VARSET]:-}"
if [ -n "${extra}" ]; then
  ${REPO_DIR}/submit.sh --job-name="cp-${extra}" --time="${CP_TIME[$extra]:-$DEFAULT_CP_TIME}" \
         --output="cp-${extra}.%j.out" --error="cp-${extra}.%j.out" \
         "run_cp_generic.sh" "${datebeg}" "${dateend}" "${year_lim}" "${extra}"
fi

#----------------------------------------------------------------
# Auto-chain to the next varset in the pipeline (config/varsets.sh: NEXT[])
#----------------------------------------------------------------
next="${NEXT[$VARSET]}"
if [ "${ADVANCE_YEAR[$VARSET]:-0}" = "1" ]; then
  # This varset advances the year -- only continue if there's a next year
  # left to run. This is the link that closes out year_lim: it runs
  # year_lim once, then stops instead of starting year_lim+1.
  chain_ok=0
  [ "$yeari" -lt "$year_lim" ] && chain_ok=1
else
  # This varset does not advance the year -- safe to run through year_lim
  # itself, since the advancing link (earlier or later in the cycle) is
  # what decides whether the cycle continues.
  chain_ok=0
  [ "$yeari" -le "$year_lim" ] && chain_ok=1
fi

if [ -n "${next}" ] && [ "$chain_ok" = "1" ]; then
  next_datebeg="${datebeg}"
  next_dateend="${dateend}"
  if [ "${ADVANCE_YEAR[$VARSET]:-0}" = "1" ]; then
    next_datebeg=$(( yeari + 1 ))
    next_dateend=$(( yearf + 1 ))
  fi
  ${REPO_DIR}/submit.sh --job-name="wrf-${next}" --time="${TIME[$next]}" --mem="${MEM[$next]:-$DEFAULT_MEM}" \
         --output="wrf-${next}.%j.out" --error="wrf-${next}.%j.out" \
         "run_out_generic.sh" "${next_datebeg}" "${next_dateend}" "${year_lim}" "${next}"
fi
echo "$0 (${VARSET}) done."
