#!/bin/bash
#
# merge_soil_monthly.sh — join monthly 6hr soil files (tsl, mrsol, mrsfl) into
# one file per year, as CORDEX-CMIP6 wants, and bring the metadata up to date.
# Usage: ./merge_soil_monthly.sh -g <global ini> [options] <dir with monthly files>
# See README.md ("Merging monthly soil files").
#----------------------------------------------------------------

set -euo pipefail

#
#--- Options ----------------------------------------------------
# -g  the experiment's global ini (values for the corrected global attributes)
# -o  where to write the yearly files (default: the same folder)
#
usage() {
  cat >&2 <<EOF
Usage: $0 -g <global ini> [-o <out dir>] [-v "tsl mrsol mrsfl"] [-y "2015 2016"] [-m] [-p] [-f] <dir>
  -g  experiment global ini, e.g. experiments/cordex/cordex_global_EUR-12_d01.ini
  -o  output folder (default: <dir>)
  -v  variables to merge (default: "tsl mrsol mrsfl")
  -y  only these years (default: every year found)
  -m  merge only: keep the metadata exactly as in the monthly files
  -p  allow a year with fewer than 12 monthly files (default: skip it)
  -f  overwrite a yearly file that already exists
The monthly files are never changed or deleted.
EOF
  exit 1
}

GLOBAL_INI=""; OUT_DIR=""; VARS="tsl mrsol mrsfl"; YEARS=""
MERGE_ONLY=0; PARTIAL=0; FORCE=0
while getopts "g:o:v:y:mpfh" opt; do
  case "$opt" in
    g) GLOBAL_INI="$OPTARG" ;;
    o) OUT_DIR="$OPTARG" ;;
    v) VARS="$OPTARG" ;;
    y) YEARS="$OPTARG" ;;
    m) MERGE_ONLY=1 ;;
    p) PARTIAL=1 ;;
    f) FORCE=1 ;;
    *) usage ;;
  esac
done
shift $((OPTIND - 1))
[ $# -eq 1 ] || usage
IN_DIR="${1%/}"
OUT_DIR="${OUT_DIR:-$IN_DIR}"
[ -d "$IN_DIR" ] || { echo "No such folder: $IN_DIR" >&2; exit 1; }
mkdir -p "$OUT_DIR"

#
#--- Tools and global ini ---------------------------------------
# Needs NCO (ncrcat, ncks, ncatted, ncap2, ncrename); the ini is needed
# unless -m (merge only) is given.
#
for t in ncrcat ncks ncatted ncap2 ncrename; do
  command -v "$t" >/dev/null || { echo "$t not found — load NCO first (e.g. module load nco)." >&2; exit 1; }
done
if [ "$MERGE_ONLY" = 0 ]; then
  [ -f "$GLOBAL_INI" ] || { echo "Give the experiment's global ini with -g (or -m for merge only)." >&2; usage; }
fi

# value of  key = 'value'  in the global ini
ini_val() {
  sed -n "s/^[[:space:]]*$1[[:space:]]*=[[:space:]]*'\(.*\)'.*/\1/p" "$GLOBAL_INI" | sed -n '1p'
}

new_uuid() {
  cat /proc/sys/kernel/random/uuid 2>/dev/null || uuidgen 2>/dev/null \
    || python3 -c 'import uuid; print(uuid.uuid4())'
}

#
#--- Time stamp for the file name -------------------------------
# YYYYMMDDhhmm of a time value in "days since <ref>" (or hours since).
#
stamp() {   # stamp <value> <units>
  local val="$1" units="$2" ref mins
  ref=$(echo "$units" | sed -E 's/^[a-z]+ since ([0-9]{4}-[0-9]{2}-[0-9]{2}).*/\1/')
  case "$units" in
    hours*) mins=$(awk -v v="$val" 'BEGIN{printf "%d", v*60 + (v<0?-0.5:0.5)}') ;;
    *)      mins=$(awk -v v="$val" 'BEGIN{printf "%d", v*1440 + (v<0?-0.5:0.5)}') ;;
  esac
  date -u -d "${ref} 00:00 UTC + ${mins} minutes" +%Y%m%d%H%M
}

# run one NCO step; on failure report it and return 1 (the caller stops)
step() {
  "$@" || { echo "ERROR in: $*" >&2; return 1; }
}

# (header read into a variable first: grep -q on a pipe would make ncks fail under pipefail)
has_var() { local h; h=$(ncks -m "$2" 2>/dev/null); grep -qE "^[[:space:]]+[a-z0-9]+ $1 ;" <<< "$h"; }
has_att() { local h; h=$(ncks -M -m "$2" 2>/dev/null); grep -q "$1 = " <<< "$h"; }

time_val() {   # time_val <file> <index>
  ncks -H -C -s '%.6f\n' -v time -d time,"$2" "$1" | awk 'NF && !d {print; d=1}'
}

#
#--- Merge and correct (one variable, one year) -----------------
# Joins the months in time order with ncrcat; unless -m, corrects the
# metadata as the current write routines do; writes NetCDF-4 classic, deflate 1.
#
work() {   # work <var> <tmp file> <monthly files>...
  local var="$1" f="$2"; shift 2
  local units ref now hist
  step ncrcat -O "$@" "$f" || return 1

  if [ "$MERGE_ONLY" = 0 ]; then
    # names: grid-mapping variable and global attributes
    for old in rotated_pole rotted_pole; do
      if has_var "$old" "$f"; then step ncrename -O -h -v "${old},rotated_latitude_longitude" "$f" >/dev/null || return 1; fi
    done
    for pair in driving_variant_lable,driving_variant_label version_realisation,version_realization; do
      if has_att ":${pair%%,*}" "$f"; then step ncrename -O -h -a ".${pair}" "$f" >/dev/null || return 1; fi
    done

    # time in days since <ref>T00:00:00Z (old files count hours)
    units=$(ncks -m -v time "$f" | sed -n 's/.*time:units = "\(.*\)".*/\1/p' | sed -n '1p')
    ref=$(echo "$units" | sed -E 's/^[a-z]+ since ([0-9]{4}-[0-9]{2}-[0-9]{2}).*/\1/')
    case "$units" in
      hours*) step ncap2 -O -h -s 'time=time/24.0;time_bnds=time_bnds/24.0' "$f" "$f" || return 1 ;;
    esac

    # soil depth: double, at the middle of each layer
    step ncap2 -O -h -s 'sdepth_bnds=rint(1.0e6*double(sdepth_bnds))/1.0e6;sdepth=rint(5.0e5*(sdepth_bnds(:,0)+sdepth_bnds(:,1)))/1.0e6' "$f" "$f" || return 1

    now=$(date -u +%Y-%m-%dT%H:%M:%SZ)
    hist="${now};rewrote data to be consistent with correct frequency 6hr for variable ${var} found in table CORDEX-CMIP6_6hr."
    step ncatted -O -h \
      -a "grid_mapping,${var},o,c,rotated_latitude_longitude" \
      -a earth_radius,rotated_latitude_longitude,o,f,6370000. \
      -a units,time,o,c,"days since ${ref}T00:00:00Z" \
      -a calender,time,d,, -a calendar,time,o,c,"standard" \
      -a long_name,time_bnds,d,, -a units,time_bnds,d,, -a calender,time_bnds,d,, -a calendar,time_bnds,d,, \
      -a long_name,sdepth_bnds,d,, -a units,sdepth_bnds,d,, -a positive,sdepth_bnds,d,, -a axis,sdepth_bnds,d,, \
      -a driving_variant_label,global,o,c,"$(ini_val driving_variant)" \
      -a project_id,global,o,c,"$(ini_val project_id)" \
      -a source_type,global,o,c,"$(ini_val source_type)" \
      -a institution,global,o,c,"$(ini_val institution)" \
      -a source,global,o,c,"$(ini_val source_desc)" \
      -a creation_date,global,o,c,"${now}" \
      -a tracking_id,global,o,c,"hdl:21.14103/$(new_uuid)" \
      -a history,global,o,c,"${hist}" \
      -a external_variables,global,o,c,"areacella" \
      -a frequency,global,o,c,"6hr" \
      "$f" || return 1
  fi

  # NetCDF-4 classic, deflate level 1 with shuffle, one time step per chunk
  step ncks -O -h -7 -L 1 --cnk_dmn time,1 "$f" "$(dirname "$f")/out.nc" || return 1
  # drop the version attribute NCO adds itself
  step ncatted -O -h -a NCO,global,d,, "$(dirname "$f")/out.nc" || return 1
}

#
#--- Merge one variable and year --------------------------------
# Checks there are 12 months, merges them and names the yearly file.
#
merge_one() {   # merge_one <var> <year> <file>...
  local var="$1" year="$2"; shift 2
  local files=("$@") n=$# tmp f prefix units first last out

  if [ "$n" -lt 12 ] && [ "$PARTIAL" = 0 ]; then
    echo "SKIP ${var} ${year}: only ${n} monthly files (use -p to merge anyway)." >&2
    return 1
  fi

  tmp=$(mktemp -d "${OUT_DIR}/.merge_${var}_${year}.XXXX")
  f="${tmp}/cat.nc"
  if ! work "$var" "$f" "${files[@]}"; then
    echo "FAIL ${var} ${year}: not merged (monthly files unchanged)." >&2
    rm -rf "$tmp"; return 1
  fi

  # yearly name: monthly prefix + first-last time step (YYYYMMDDhhmm)
  units=$(ncks -m -v time "${tmp}/out.nc" | sed -n 's/.*time:units = "\(.*\)".*/\1/p' | sed -n '1p')
  first=$(stamp "$(time_val "${tmp}/out.nc" 0)" "$units")
  last=$(stamp "$(time_val "${tmp}/out.nc" -1)" "$units")
  prefix=$(basename "${files[0]}" | sed -E 's/_[0-9]{10}-[0-9]{10}\.nc$//')
  out="${OUT_DIR}/${prefix}_${first}-${last}.nc"

  [ -n "$first" ] && [ -n "$last" ] || { echo "FAIL ${var} ${year}: could not read the time axis." >&2; rm -rf "$tmp"; return 1; }
  if [ -e "$out" ] && [ "$FORCE" = 0 ]; then
    echo "SKIP ${var} ${year}: ${out} already exists (use -f to overwrite)." >&2
    rm -rf "$tmp"; return 1
  fi
  mv "${tmp}/out.nc" "$out"
  rm -rf "$tmp"
  echo "OK   ${var} ${year}: ${n} months -> $(basename "$out")"
}

#
#--- Find the monthly files and merge each variable and year ----
# Monthly names end in _6hr_YYYYMM0100-YYYYMMDDhh.nc (10-digit stamps).
#
shopt -s nullglob
failed=0
for var in $VARS; do
  years=$YEARS
  if [ -z "$years" ]; then
    years=$(for f in "$IN_DIR"/"${var}"_*_6hr_[0-9][0-9][0-9][0-9][0-9][0-9]0100-[0-9][0-9][0-9][0-9][0-9][0-9][0-9][0-9][0-9][0-9].nc; do
              basename "$f" | sed -E 's/.*_6hr_([0-9]{4}).*/\1/'
            done | sort -u)
  fi
  [ -n "$years" ] || { echo "No monthly ${var} files in ${IN_DIR}." >&2; continue; }
  for y in $years; do
    files=( "$IN_DIR"/"${var}"_*_6hr_"${y}"[0-9][0-9]0100-[0-9][0-9][0-9][0-9][0-9][0-9][0-9][0-9][0-9][0-9].nc )
    [ ${#files[@]} -gt 0 ] || { echo "No monthly ${var} files for ${y}." >&2; failed=1; continue; }
    merge_one "$var" "$y" "${files[@]}" || failed=1
  done
done

[ "$failed" = 0 ] || { echo "Some years were not merged (see above). The monthly files were not changed." >&2; exit 1; }
echo "Done. The monthly files were not changed or deleted."
