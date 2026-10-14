#!/bin/bash
#
# submit.sh
#
# Thin wrapper around sbatch, used for EVERY job in this pipeline (the
# first run_analysis.sh submission and every job the scripts chain to).
# It:
#   - auto-detects ROOT_DIR from where THIS file lives and passes it into
#     the job's environment via `sbatch --export`, and
#   - reads the site's Slurm settings from env.site.sh (JOB_ACCOUNT,
#     JOB_MAIL_TYPE, JOB_MAIL_USER, JOB_CHDIR) and passes them as
#     --account / --mail-type / --mail-user / --chdir.
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

# Read only the four JOB_* values, in a subshell, so nothing else that
# env.site.sh sets or loads (modules, compiler settings, ...) leaks into
# the job's environment through --export=ALL. set -u is relaxed there
# because env.site.sh is plain user config.
# Each value is printed with a trailing "|" so empty values still produce
# a line (command substitution would otherwise drop trailing empty lines).
job_settings="$(
  set +eu
  # shellcheck source=/dev/null
  source "${env_file}" >/dev/null 2>&1
  printf '%s|\n' "${JOB_ACCOUNT:-}" "${JOB_MAIL_TYPE:-}" "${JOB_MAIL_USER:-}" "${JOB_CHDIR:-}"
)"
mapfile -t job_values <<< "${job_settings}"
JOB_ACCOUNT="${job_values[0]%|}"
JOB_MAIL_TYPE="${job_values[1]%|}"
JOB_MAIL_USER="${job_values[2]%|}"
JOB_CHDIR="${job_values[3]%|}"

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
add_site_arg() {
  if [ -n "$2" ] && ! caller_has "$1"; then
    site_args+=("$1=$2")
  fi
}
add_site_arg --account   "${JOB_ACCOUNT}"
add_site_arg --mail-type "${JOB_MAIL_TYPE}"
add_site_arg --mail-user "${JOB_MAIL_USER}"
add_site_arg --chdir     "${JOB_CHDIR}"

if [ -z "${JOB_ACCOUNT}" ] && ! caller_has --account; then
  echo "WARNING: JOB_ACCOUNT is empty in ${env_file} — the job will use your default Slurm account." >&2
fi

echo "ROOT_DIR=${ROOT_DIR} (auto-detected from submit.sh's location)"

# Site settings first, then the caller's own flags, so the caller's win.
exec sbatch --export=ALL,ROOT_DIR="${ROOT_DIR}" \
     ${site_args[@]+"${site_args[@]}"} \
     ${sbatch_args[@]+"${sbatch_args[@]}"} \
     "${target_path}" "$@"
