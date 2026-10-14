#!/bin/bash
#
# scripts/load_experiment.sh
#
# Sourced by run_out_generic.sh and run_cp_generic.sh, right after
# env.site.sh. Loads experiments/${EXPERIMENT}.sh and checks that every
# grid in run[] has all its per-grid settings, so a missing entry fails at
# the start of the job instead of half-way through.
#
# The experiment is chosen when a run is first submitted (EXPERIMENT in
# env.site.sh, or EXPERIMENT=<name> ./submit.sh ...). submit.sh passes it
# to every job as CMOR_EXPERIMENT, which wins over env.site.sh here — so a
# running chain keeps its experiment even if env.site.sh changes meanwhile.
#----------------------------------------------------------------
# shellcheck disable=SC2154  # run[] etc. come from the experiment file

EXPERIMENT="${CMOR_EXPERIMENT:-${EXPERIMENT:-}}"
: "${EXPERIMENT:?No EXPERIMENT set — add EXPERIMENT=\"<name>\" to env.site.sh, matching a file experiments/<name>.sh}"

EXPERIMENT_FILE="${ROOT_DIR}/experiments/${EXPERIMENT}.sh"
if [ ! -f "${EXPERIMENT_FILE}" ]; then
  echo "No experiment file ${EXPERIMENT_FILE} (EXPERIMENT=\"${EXPERIMENT}\")." >&2
  _avail=("${ROOT_DIR}"/experiments/*.sh)
  _avail=("${_avail[@]##*/}")
  echo "Available: ${_avail[*]%.sh}" >&2
  exit 1
fi

# Drop any per-experiment settings an older env.site.sh may still define,
# so only the experiment file's values are used.
unset run DOMAIN_ID OUTPUT_WRF OUTPUT_DIR ECFS_BASE REMOTE_BASE CP_RUN_DIR

# shellcheck source=/dev/null
source "${EXPERIMENT_FILE}"
# (run, DOMAIN_ID, OUTPUT_WRF, OUTPUT_DIR, ECFS_BASE, REMOTE_BASE and
# ROOT_RUN_DIR are all defined by the experiment file.)

: "${ROOT_RUN_DIR:?No ROOT_RUN_DIR set in ${EXPERIMENT_FILE}}"

if [ "$(declare -p run 2>/dev/null | cut -c1-10)" != "declare -A" ] || [ "${#run[@]}" -eq 0 ]; then
  echo "${EXPERIMENT_FILE}: run[] must list at least one grid, e.g. declare -A run=([d01]=1)." >&2
  exit 1
fi

# Grids in a fixed order (d01, d02, ...) — bash doesn't keep the order of
# an associative array's keys. Loop over GRIDS, not "${!run[@]}".
mapfile -t GRIDS < <(printf '%s\n' "${!run[@]}" | sort)

for _grid in "${GRIDS[@]}"; do
  for _arr in DOMAIN_ID OUTPUT_WRF OUTPUT_DIR ECFS_BASE REMOTE_BASE; do
    _ref="${_arr}[${_grid}]"
    if [ -z "${!_ref:-}" ]; then
      echo "${EXPERIMENT_FILE}: grid '${_grid}' is in run[] but has no ${_arr}[${_grid}] entry." >&2
      exit 1
    fi
  done
done

# Two grids writing to the same OUTPUT_DIR would be archived together to
# one grid's ECFS/remote paths.
declare -A _seen=()
for _grid in "${GRIDS[@]}"; do
  _d="${OUTPUT_DIR[$_grid]%/}"
  if [ -n "${_seen[$_d]:-}" ]; then
    echo "${EXPERIMENT_FILE}: grids '${_seen[$_d]}' and '${_grid}' share OUTPUT_DIR ${_d} — give each grid its own." >&2
    exit 1
  fi
  _seen[$_d]="${_grid}"
done
unset _grid _arr _ref _d _seen

echo "Experiment ${EXPERIMENT}: grids ${GRIDS[*]} (${EXPERIMENT_FILE})"
