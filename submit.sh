#!/bin/bash
#
# submit.sh — wrapper around sbatch used for every job in the pipeline.
# Usage: ./submit.sh [sbatch options...] <script-name> [script-args...]
# e.g.   ./submit.sh run_analysis.sh 20010101 20011231 2005
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
  echo "e.g.:  $0 --job-name=wrf-fx --time=12:00:00 run_out_generic.sh 20010101 20011231 2000 fx" >&2
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

if [ -z "${JOB_ACCOUNT}" ] && ! caller_has --account; then
  echo "WARNING: JOB_ACCOUNT is empty in ${env_file} — the job will use your default Slurm account." >&2
fi

echo "ROOT_DIR=${ROOT_DIR} (auto-detected from submit.sh's location), EXPERIMENT=${CMOR_EXPERIMENT}"

#--- Submit -----------------------------------------------------
exec sbatch --export=ALL,ROOT_DIR="${ROOT_DIR}",CMOR_EXPERIMENT="${CMOR_EXPERIMENT}" \
     ${site_args[@]+"${site_args[@]}"} \
     ${sbatch_args[@]+"${sbatch_args[@]}"} \
     "${target_path}" "$@"
