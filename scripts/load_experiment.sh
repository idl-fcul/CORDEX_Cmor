#!/bin/bash
#
# scripts/load_experiment.sh — load and check experiments/<name>/<name>.sh.
# Sourced by run_out_generic.sh and run_cp_generic.sh. See README.md §2.
#----------------------------------------------------------------
# shellcheck disable=SC2154  # run[] etc. come from the experiment file

#
#--- Experiment name (CMOR_EXPERIMENT from submit.sh wins) ------
# CMOR_EXPERIMENT (passed by submit.sh) wins over env.site.sh, so a
# running chain keeps the experiment it was started with.
#
EXPERIMENT="${CMOR_EXPERIMENT:-${EXPERIMENT:-}}"
: "${EXPERIMENT:?No EXPERIMENT set — add EXPERIMENT=\"<name>\" to env.site.sh, matching a folder experiments/<name>/}"

#
#--- Experiment folder and file ---------------------------------
# experiments/<name>/<name>.sh must exist; otherwise lists the
# experiments that do.
#
EXPERIMENT_DIR="${ROOT_DIR}/experiments/${EXPERIMENT}"
EXPERIMENT_FILE="${EXPERIMENT_DIR}/${EXPERIMENT}.sh"
if [ ! -f "${EXPERIMENT_FILE}" ]; then
  echo "No experiment file ${EXPERIMENT_FILE} (EXPERIMENT=\"${EXPERIMENT}\")." >&2
  _avail=("${ROOT_DIR}"/experiments/*/)
  _avail=("${_avail[@]%/}")
  echo "Available: ${_avail[*]##*/}" >&2
  exit 1
fi

#
#--- Load it (dropping old env.site.sh values first) ------------
# Drops per-experiment settings an older env.site.sh may still set, then
# loads the experiment file and checks it defines ROOT_RUN_DIR and run[].
#
unset run DOMAIN_ID OUTPUT_WRF OUTPUT_DIR ECFS_BASE REMOTE_BASE CP_RUN_DIR

# shellcheck source=/dev/null
source "${EXPERIMENT_FILE}"

: "${ROOT_RUN_DIR:?No ROOT_RUN_DIR set in ${EXPERIMENT_FILE}}"

if [ "$(declare -p run 2>/dev/null | cut -c1-10)" != "declare -A" ] || [ "${#run[@]}" -eq 0 ]; then
  echo "${EXPERIMENT_FILE}: run[] must list at least one grid, e.g. declare -A run=([d01]=1)." >&2
  exit 1
fi

#
#--- Grids in sorted order (d01, d02, ...) ----------------------
# GRIDS = the keys of run[], sorted, so d01 is always processed before d02.
#
mapfile -t GRIDS < <(printf '%s\n' "${!run[@]}" | sort)

#
#--- Check every grid has all its entries and ini files ---------
# Each grid needs DOMAIN_ID, OUTPUT_WRF, OUTPUT_DIR, ECFS_BASE and
# REMOTE_BASE entries, and its two ini files in the experiment folder.
#
for _grid in "${GRIDS[@]}"; do
  for _arr in DOMAIN_ID OUTPUT_WRF OUTPUT_DIR ECFS_BASE REMOTE_BASE; do
    _ref="${_arr}[${_grid}]"
    if [ -z "${!_ref:-}" ]; then
      echo "${EXPERIMENT_FILE}: grid '${_grid}' is in run[] but has no ${_arr}[${_grid}] entry." >&2
      exit 1
    fi
  done
  for _ini in "${EXPERIMENT}_${DOMAIN_ID[$_grid]}_${_grid}.ini" "${EXPERIMENT}_global_${DOMAIN_ID[$_grid]}_${_grid}.ini"; do
    if [ ! -f "${EXPERIMENT_DIR}/${_ini}" ]; then
      echo "${EXPERIMENT_DIR}: grid '${_grid}' (DOMAIN_ID ${DOMAIN_ID[$_grid]}) needs ${_ini}, which isn't there." >&2
      exit 1
    fi
  done
done

#
#--- Check no two grids share an OUTPUT_DIR ---------------------
# Each grid must write to its own OUTPUT_DIR, or the archive step would
# send both grids' files to one grid's archive paths.
#
declare -A _seen=()
for _grid in "${GRIDS[@]}"; do
  _d="${OUTPUT_DIR[$_grid]%/}"
  if [ -n "${_seen[$_d]:-}" ]; then
    echo "${EXPERIMENT_FILE}: grids '${_seen[$_d]}' and '${_grid}' share OUTPUT_DIR ${_d} — give each grid its own." >&2
    exit 1
  fi
  _seen[$_d]="${_grid}"
done
unset _grid _arr _ref _ini _d _seen

echo "Experiment ${EXPERIMENT}: grids ${GRIDS[*]} (${EXPERIMENT_FILE})"
