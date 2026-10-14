#!/bin/bash
#
# submit.sh
#
# Thin wrapper around sbatch, used for EVERY job in this pipeline (the
# first run_analysis.sh submission and every job the scripts chain to).
# It:
#   - auto-detects ROOT_DIR from where THIS file lives and passes it into
#     the job's environment via `sbatch --export`,
#   - passes the experiment (EXPERIMENT in env.site.sh, or
#     EXPERIMENT=<name> ./submit.sh ...) to the job as CMOR_EXPERIMENT, so
#     every job of a chain uses the experiment it was started with, and
#   - reads the site's Slurm settings from env.site.sh (JOB_QOS,
#     JOB_NODES, JOB_NTASKS, JOB_HINT, JOB_ACCOUNT, JOB_MAIL_TYPE,
#     JOB_MAIL_USER, JOB_CHDIR) and passes them as --qos / --nodes /
#     --ntasks / --hint / --account / --mail-type / --mail-user / --chdir.
#
# #SBATCH lines are read by sbatch before a script runs, so a script can't
# load these values itself — passing them here is what lets them live in
# env.site.sh instead of being edited into every script.
#
# Accepts both direct Slurm flags and target script arguments:
#   ./submit.sh [sbatch options...] <script-name> [script-args...]
#
# Flags given on the command line override the env.site.sh values.
#
# Examples:
#   ./submit.sh run_analysis.sh 20010101 20011231 2005
#   ./submit.sh --job-name=wrf-fx --time=12:00:00 --mem=8G --output=wrf-fx.%j.out run_out_generic.sh 20010101 20011231 2000 fx

set -euo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "$(realpath -- "${BASH_SOURCE[0]}")")" &>/dev/null && pwd)"
export ROOT_DIR="${SCRIPT_DIR}"

sbatch_args=()
script_name=""

# Separate Slurm options (leading with '-') from the target script name
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

target_path="${ROOT_DIR}/scripts/${script_name}"
if [ ! -f "${target_path}" ]; then
  echo "No such script: ${target_path}" >&2
  echo "(Looked under ROOT_DIR=${ROOT_DIR}, auto-detected from submit.sh's location.)" >&2
  exit 1
fi

#----------------------------------------------------------------
# Slurm job settings from env.site.sh
#----------------------------------------------------------------
env_file="${ROOT_DIR}/env.site.sh"
if [ ! -f "${env_file}" ]; then
  echo "No ${env_file} found — copy env.site.sh.example to env.site.sh and fill it in (README.md §4)." >&2
  exit 1
fi

# env.site.sh setting -> sbatch flag, and the value used when the setting
# is missing from env.site.sh altogether (so an older env.site.sh keeps the
# previous behaviour). A setting that is present but empty ("") passes no
# flag at all.
job_vars=(  JOB_QOS JOB_NODES JOB_NTASKS JOB_HINT        JOB_ACCOUNT JOB_MAIL_TYPE JOB_MAIL_USER JOB_CHDIR )
job_flags=( --qos   --nodes   --ntasks   --hint          --account   --mail-type   --mail-user   --chdir   )
job_defs=(  nf      1         1          nomultithread   ""          ALL           ""            ""        )

# Read only these JOB_* values, in a subshell, so nothing else that
# env.site.sh sets or loads (modules, compiler settings, ...) leaks into
# the job's environment through --export=ALL. set -u is relaxed there
# because env.site.sh is plain user config. Each value is printed with a
# trailing "|" so empty values still produce a line (command substitution
# would otherwise drop trailing empty lines).
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
  # Experiment: the one this chain was started with (CMOR_EXPERIMENT, set
  # by an earlier submit.sh) wins over env.site.sh.
  printf '%s|\n' "${CMOR_EXPERIMENT:-${EXPERIMENT:-}}"
)"
mapfile -t job_values <<< "${job_settings}"

CMOR_EXPERIMENT="${job_values[${#job_vars[@]}]%|}"
if [ -z "${CMOR_EXPERIMENT}" ]; then
  echo "No EXPERIMENT set in ${env_file} — add EXPERIMENT=\"<name>\" matching a file experiments/<name>.sh." >&2
  exit 1
fi
if [ ! -f "${ROOT_DIR}/experiments/${CMOR_EXPERIMENT}.sh" ]; then
  echo "No experiment file ${ROOT_DIR}/experiments/${CMOR_EXPERIMENT}.sh (EXPERIMENT=\"${CMOR_EXPERIMENT}\")." >&2
  exit 1
fi

# True if the caller already passed this sbatch flag (e.g. --account=...).
caller_has() {
  local a
  for a in ${sbatch_args[@]+"${sbatch_args[@]}"}; do
    [[ "${a}" == "$1" || "${a}" == "$1="* ]] && return 0
  done
  return 1
}

# Add "--flag=value" unless the value is empty or the caller set it.
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

# Site settings first, then the caller's own flags, so the caller's win.
exec sbatch --export=ALL,ROOT_DIR="${ROOT_DIR}",CMOR_EXPERIMENT="${CMOR_EXPERIMENT}" \
     ${site_args[@]+"${site_args[@]}"} \
     ${sbatch_args[@]+"${sbatch_args[@]}"} \
     "${target_path}" "$@"
