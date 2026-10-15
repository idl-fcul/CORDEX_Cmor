#!/bin/bash
#
# submit.sh — wrapper around sbatch used for every job in the pipeline.
# Usage: ./submit.sh [sbatch options...] <script-name> [script-args...]
# e.g.   ./submit.sh run_analysis.sh 20010101 20011231 2005
#        ./submit.sh run_out_generic.sh 20010101 20011231 2001 soil
# See README.md §6 and §9.
#----------------------------------------------------------------

set -euo pipefail

#--- Repo location (from this file, symlinks resolved) ---------
SCRIPT_DIR="$(cd -- "$(dirname -- "$(realpath -- "${BASH_SOURCE[0]}")")" &>/dev/null && pwd)"
export ROOT_DIR="${SCRIPT_DIR}"

#--- Split sbatch options from the script name and its args ----
sbatch_args=()
script_name=""

while [ $# -gt 0 ]; do
  case "$1" in
    -*)
      sbatch_args+=("$1")
      shift
      ;;
    *)
      script_name="$1"
      shift
      break
      ;;
  esac
done

if [ -z "${script_name}" ]; then
  echo "Usage: $0 [sbatch-options...] <script-name> [script-args...]" >&2
  echo "e.g.:  $0 run_out_generic.sh 20010101 20011231 2001 fx" >&2
  exit 1
fi

#--- Target script ---------------------------------------------
target_path="${ROOT_DIR}/scripts/${script_name}"
if [ ! -f "${target_path}" ]; then
  echo "No such script: ${target_path}" >&2
  echo "(Looked under ROOT_DIR=${ROOT_DIR}, auto-detected from submit.sh's location.)" >&2
  exit 1
fi

#--- env.site.sh ------------------------------------------------
env_file="${ROOT_DIR}/env.site.sh"
if [ ! -f "${env_file}" ]; then
  echo "No ${env_file} found — copy env.site.sh.example to env.site.sh and fill it in (README.md §4)." >&2
  exit 1
fi

#--- Slurm settings: env.site.sh name / sbatch flag / default --
job_vars=(  JOB_QOS JOB_NODES JOB_NTASKS JOB_HINT        JOB_ACCOUNT JOB_MAIL_TYPE JOB_MAIL_USER JOB_CHDIR )
job_flags=( --qos   --nodes   --ntasks   --hint          --account   --mail-type   --mail-user   --chdir   )
job_defs=(  nf      1         1          nomultithread   ""          ALL           ""            ""        )

#--- Read JOB_* values and the experiment (in a subshell) -------
job_settings="$(
  set +eu
  # shellcheck source=/dev/null
  source "${env_file}" >/dev/null 2>&1
  for i in "${!job_vars[@]}"; do
    name="${job_vars[$i]}"
    if [ -n "${!name+x}" ]; then
      printf '%s|\n' "${!name}"
    else
      printf '%s|\n' "${job_defs[$i]}"
    fi
  done
  printf '%s|\n' "${CMOR_EXPERIMENT:-${EXPERIMENT:-}}"
)"
mapfile -t job_values <<< "${job_settings}"

#--- Experiment check ------------------------------------------
CMOR_EXPERIMENT="${job_values[${#job_vars[@]}]%|}"
if [ -z "${CMOR_EXPERIMENT}" ]; then
  echo "No EXPERIMENT set in ${env_file} — add EXPERIMENT=\"<name>\" matching a folder experiments/<name>/." >&2
  exit 1
fi
if [ ! -f "${ROOT_DIR}/experiments/${CMOR_EXPERIMENT}/${CMOR_EXPERIMENT}.sh" ]; then
  echo "No experiment file ${ROOT_DIR}/experiments/${CMOR_EXPERIMENT}/${CMOR_EXPERIMENT}.sh (EXPERIMENT=\"${CMOR_EXPERIMENT}\")." >&2
  exit 1
fi

#--- Build sbatch flags (caller's own flags take precedence) ----
caller_has() {
  local a
  for a in ${sbatch_args[@]+"${sbatch_args[@]}"}; do
    [[ "${a}" == "$1" || "${a}" == "$1="* ]] && return 0
  done
  return 1
}

site_args=()
for i in "${!job_vars[@]}"; do
  value="${job_values[$i]%|}"
  printf -v "${job_vars[$i]}" '%s' "${value}"
  if [ -n "${value}" ] && ! caller_has "${job_flags[$i]}"; then
    site_args+=("${job_flags[$i]}=${value}")
  fi
done

#--- Per-varset flags for run_out_generic.sh / run_cp_generic.sh -
# From config/varsets.sh: job name, --time, --mem (processing only) and
# log files, unless given on the command line. Varset = 4th script arg.
if [[ "${script_name}" == run_out_generic.sh || "${script_name}" == run_cp_generic.sh ]] && [ $# -ge 4 ]; then
  vs="$4"
  if [ "${script_name}" = run_out_generic.sh ]; then prefix="wrf"; else prefix="cp"; fi
  vs_settings="$(
    set +eu
    # shellcheck source=/dev/null
    source "${ROOT_DIR}/config/varsets.sh" >/dev/null 2>&1
    if [ -z "${VARSETS[$vs]+x}" ]; then echo "UNKNOWN|"; exit 0; fi
    if [ "${prefix}" = wrf ]; then
      printf '%s|\n' "${TIME[$vs]:-}" "${MEM[$vs]:-${DEFAULT_MEM:-}}"
    else
      printf '%s|\n' "${CP_TIME[$vs]:-${DEFAULT_CP_TIME:-}}" ""
    fi
  )"
  mapfile -t vs_values <<< "${vs_settings}"
  if [ "${vs_values[0]}" = "UNKNOWN|" ]; then
    echo "Unknown varset '${vs}' — not in config/varsets.sh." >&2
    exit 1
  fi
  vs_time="${vs_values[0]%|}"
  vs_mem="${vs_values[1]%|}"

  caller_has --job-name || caller_has -J || site_args+=("--job-name=${prefix}-${vs}")
  if ! caller_has --time && ! caller_has -t; then
    if [ -n "${vs_time}" ]; then
      site_args+=("--time=${vs_time}")
    else
      echo "WARNING: no TIME[${vs}] in config/varsets.sh — the job gets the queue's default time limit." >&2
    fi
  fi
  if [ -n "${vs_mem}" ] && ! caller_has --mem; then site_args+=("--mem=${vs_mem}"); fi
  caller_has --output || caller_has -o || site_args+=("--output=${prefix}-${vs}.%j.out")
  caller_has --error  || caller_has -e || site_args+=("--error=${prefix}-${vs}.%j.out")
fi

if [ -z "${JOB_ACCOUNT}" ] && ! caller_has --account; then
  echo "WARNING: JOB_ACCOUNT is empty in ${env_file} — the job will use your default Slurm account." >&2
fi

echo "ROOT_DIR=${ROOT_DIR} (auto-detected from submit.sh's location), EXPERIMENT=${CMOR_EXPERIMENT}"

#--- Submit -----------------------------------------------------
exec sbatch --export=ALL,ROOT_DIR="${ROOT_DIR}",CMOR_EXPERIMENT="${CMOR_EXPERIMENT}" \
     ${site_args[@]+"${site_args[@]}"} \
     ${sbatch_args[@]+"${sbatch_args[@]}"} \
     "${target_path}" "$@"
