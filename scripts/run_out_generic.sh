#!/bin/bash
#
# scripts/run_out_generic.sh — process one varset, then archive and chain.
# Usage: ./submit.sh [sbatch options] run_out_generic.sh <datebeg> <dateend> <year_lim> <varset>
# See README.md §6, §8 and §10.
#----------------------------------------------------------------

set -x

#--- Repo location (set by submit.sh) ---------------------------
: "${ROOT_DIR:?ROOT_DIR is not set — submit this script through submit.sh, not plain sbatch (see README.md §10)}"
REPO_DIR="${ROOT_DIR}"

#--- Arguments --------------------------------------------------
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

#--- Environment: site, experiment, varsets ---------------------
source "${REPO_DIR}/env.site.sh"
source "${REPO_DIR}/scripts/load_experiment.sh"
source "${REPO_DIR}/config/varsets.sh"

if [ -z "${VARSETS[$VARSET]+x}" ]; then
  echo "Unknown varset '${VARSET}'. Known varsets:" >&2
  printf ' %s\n' "${!VARSETS[@]}" >&2
  exit 1
fi

#--- WRF file type (wrfxtrm for wxtrm, else wrfout) -------------
wrffile="wrfout"
if [ "${VARSET}" = "wxtrm" ] || [ "${VARSET}" = "testex" ]; then
  wrffile="wrfxtrm"
fi

#--- Varset groups ("PROGRAM:var1,var2;PROGRAM:var3") -----------
exp="${EXPERIMENT}"
IFS=';' read -r -a groups <<< "${VARSETS[$VARSET]}"

#--- Years and working directory --------------------------------
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

#--- Processing loop: year -> grid -> group -> variable ---------
for(( j = ${yeari}; j <= ${yearf}; j++ )) ; do

 START_YY=`echo ${j}`
 END_YY=`echo ${j}`

 # Grid (domain)
 for grid in "${GRIDS[@]}"; do

  dom_id="${DOMAIN_ID[${grid}]}"
  mkdir -p "${OUTPUT_DIR[${grid}]}"

  cp "${EXPERIMENT_DIR}/${exp}_global_${dom_id}_${grid}.ini" global_data.inp

  # Group
  for group in "${groups[@]}"; do
   prog_pattern="${group%%:*}"
   IFS=',' read -r -a var <<< "${group#*:}"

   # Variable
   for (( v=0; v<${#var[@]}; v++)); do

    # Namelist: grid ini (placeholders filled in) + variable header
    sed \
     -e "s|_START_YY_|$START_YY|g" \
     -e "s|_END_YY_|$END_YY|g" \
     -e "s|_WRFFILE_|${wrffile}|g" \
     -e "s|_OUTPUT_WRF_|${OUTPUT_WRF[${grid}]}/|g" \
     -e "s|_OUTPUT_DIR_|${OUTPUT_DIR[${grid}]}/|g" \
     "${EXPERIMENT_DIR}/${exp}_${dom_id}_${grid}.ini" \
     > "${RUN_DIR}/header_${grid}"

    cat header_${grid} > inputlist.inp
    echo "!" >> inputlist.inp
    echo "! Variable" >> inputlist.inp
    echo "!" >> inputlist.inp
    cat ${HEADER_DIR}/header_${var[$v]} >> inputlist.inp
    echo "!" >> inputlist.inp
    echo "/" >> inputlist.inp

    # Program name (VAR -> variable name)
    PROG_NAME="${prog_pattern/VAR/${var[$v]}}"

    # Compile and run
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

#--- Archive job(s): this varset, plus its CP_EXTRA companion ---
 ${REPO_DIR}/submit.sh --job-name="cp-${VARSET}" --time="${CP_TIME[$VARSET]:-$DEFAULT_CP_TIME}" \
       --output="cp-${VARSET}.%j.out" --error="cp-${VARSET}.%j.out" \
       "run_cp_generic.sh" "${datebeg}" "${dateend}" "${year_lim}" "${VARSET}"

extra="${CP_EXTRA[$VARSET]:-}"
if [ -n "${extra}" ]; then
  ${REPO_DIR}/submit.sh --job-name="cp-${extra}" --time="${CP_TIME[$extra]:-$DEFAULT_CP_TIME}" \
         --output="cp-${extra}.%j.out" --error="cp-${extra}.%j.out" \
         "run_cp_generic.sh" "${datebeg}" "${dateend}" "${year_lim}" "${extra}"
fi

#--- Chain to the next varset (NEXT[], ADVANCE_YEAR[]) ----------
next="${NEXT[$VARSET]}"
if [ "${ADVANCE_YEAR[$VARSET]:-0}" = "1" ]; then
  chain_ok=0
  [ "$yeari" -lt "$year_lim" ] && chain_ok=1
else
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
