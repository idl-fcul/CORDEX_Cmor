#!/bin/bash
#
# config/varsets.sh
#
# Single source of truth for every "run_out_*" variant.
# To add/remove/change a variable set, edit ONLY this file — nothing else.
#
#----------------------------------------------------------------
# VARSETS[name] format
#
# One or more "groups", separated by ';'. Each group is:
#
#     <program-pattern>:<var1>,<var2>,...
#
# <program-pattern> is either:
#   - a literal program name (used as-is for every var in the group), or
#   - a name containing the literal string VAR, which gets substituted with
#     each variable in turn.
#
# Either way, run_out_generic.sh calls the program ONCE PER VARIABLE (or
# level), and each call is an independent pass over the year's WRF files.
# So every varset can be split between variables/levels — including the
# fixed-program ones (cloud, rad, plev_*, zlev_*). A single variable/level
# is the smallest unit that can't be divided further.
#
# Exception: [wxtrm] must keep that exact name — run_out_generic.sh reads
# wrfxtrm instead of wrfout only for the varset called "wxtrm" (or "testex").
#----------------------------------------------------------------
#
# 2026-10-14 REDISTRIBUTION — 10 processing streams (+1 processor left
# free for the archive "cp-*" jobs, so at most 11 run at once).
#
# Based on measured maximum run times (sacct, Aug–Oct 2026). Split costs
# are scaled per variable/level from the measured varset (e.g. cloud =
# 24h06 for 4 vars -> 6h02 per var). "est" = no measured run yet.
#
# Changes from the 2026-08-13 layout:
#   - zlev_uava0/zlev_uava1 (16G memory) replace the separate
#     zlev_ua0/1 + zlev_va0/1 processing runs.
#   - [cloud] (24h06, the old ceiling) split into cloud1 + cloud2.
#   - [wpth1] (17h25 for 2 vars) split into wpth1 (clivi) + wpth3 (clwvi).
#   - [out3] and [tau] folded into out1/out2 (fewer chain hops).
#
# Stream -> chain (per model year)                          ~time/year
#   1  plev_uava -> wxtrm                                   19h38
#   2  zlev_uava0 (self)                                    20h54 est
#   3  zlev_uava1 (self)                                    20h54 est
#   4  cloud1 -> wpth1                                      20h46
#   5  cloud2 -> wpth3                                      20h46
#   6  plev_zg -> snw                                       20h41
#   7  plev_ta -> wpth2                                     20h01
#   8  rad -> out1                                          20h51 (out1 est)
#   9  plev_wa -> zlev_hus -> zlev_ta                       20h39
#   10 plev_hus -> soil -> out2                             20h59 (out2 est)
#
# Previous ceiling: plev_hus -> wpth1 at 28h06 per year (wpth1 alone was
# 17h25), then zlev_uava0 -> out2 ~24h27 est and cloud -> wxtrm 24h07.
# New ceiling: ~21h per year (~25% faster per model year). Total work is
# unchanged (~206h/year); it is just spread evenly across the 10 streams.
#
# zlev_uava0/1 estimate = 1.1 x zlev_va0 (taken as its 19h limit — no
# measured run yet). Re-run report_walltimes.sh after the first full year
# and rebalance if these, out1 or out2 differ much from the estimates.
#----------------------------------------------------------------

declare -A VARSETS=(
  [out1]="RCM_sfc_VAR:tas,ts,th,hurs,huss,hfls,hfss,evspsbl,psl,zmla,od550aer,uas,vas"
  [out2]="RCM_sfc_VAR:ps,sfcWind,z0,tauu,tauv"
  [soil]="RCM_sfc_VAR:mrfso,mrfsos,mrso,mrsos,mrro,mrros,tsl,mrsfl,mrsol"
  [rad]="RCM_sfc_rad:rsds,rlds,rsus,rlus,rldscs,rluscs,rlut,rlutcs,rsdscs,rsdsdir,rsdt,rsuscs,rsut,rsutcs"
  [snw]="RCM_sfc_VAR:prsn,snm,snc,snw,snd,siconca,pr,prc,sund"
  [cloud1]="RCM_sfc_cloud:clh,clm"
  [cloud2]="RCM_sfc_cloud:cll,clt"
  [wxtrm]="RCM_sfc_xtrm:tasmax,tasmin,sfcWindmax,prcmax,prncmax"
  [wpth1]="RCM_sfc_VAR:clivi"
  [wpth2]="RCM_sfc_VAR:prw"
  [wpth3]="RCM_sfc_VAR:clwvi"
  [plev_wa]="RCM_plev_wa:wa1000,wa925,wa850,wa750,wa700,wa600,wa500,wa400,wa300,wa250,wa200,wa150,wa100,wa70,wa50,wa30"
  [plev_zg]="RCM_plev_zg:zg1000,zg925,zg850,zg750,zg700,zg600,zg500,zg400,zg300,zg250,zg200,zg150,zg100,zg70,zg50,zg30"
  [plev_uava]="RCM_plev_uava:va1000,va925,va850,va750,va700,va600,va500,va400,va300,va250,va200,va150,va100,va70,va50,va30"
  [plev_hus]="RCM_plev_hus:hus1000,hus925,hus850,hus750,hus700,hus600,hus500,hus400,hus300,hus250,hus200,hus150,hus100,hus70,hus50,hus30"
  [plev_ta]="RCM_plev_ta:ta1000,ta925,ta850,ta750,ta700,ta600,ta500,ta400,ta300,ta250,ta200,ta150,ta100,ta70,ta50,ta30"
  [zlev_hus]="RCM_zlev_hus:hus50m"
  [zlev_ta]="RCM_zlev_ta:ta50m"
  [zlev_uava0]="RCM_zlev_uava:va50m,va100m,va150m"
  [zlev_uava1]="RCM_zlev_uava:va200m,va250m,va300m"
  [fx]="RCM_fx_VAR:orog,sftlaf,sftlf,sfturf,sftgif"
  [testex]="RCM_sfc_xtrm:tasmax,tasmin,sfcWindmax,prcmax,prncmax"
  [teste]="RCM_sfc_rad:rsds"
  #
  # Not in any stream — kept only for one-off manual runs. [cloud] and
  # [tau] are now covered by cloud1/cloud2 and out2; zlev_va0/1 by
  # zlev_uava0/1.
  [cloud]="RCM_sfc_cloud:clh,clm,cll,clt"
  [tau]="RCM_sfc_VAR:tauu,tauv"
  [zlev_va0]="RCM_zlev_va:va50m,va100m,va150m"
  [zlev_va1]="RCM_zlev_va:va200m,va250m,va300m"
  #
  # Archive-only companions — NOT for processing (not in ORDER/NEXT).
  # They exist so run_cp_generic.sh can archive the "u" files alongside the
  # "v" files that plev_uava/zlev_uava0/zlev_uava1 produce — see CP_EXTRA[].
  [plev_ua]="RCM_plev_ua:ua1000,ua925,ua850,ua750,ua700,ua600,ua500,ua400,ua300,ua250,ua200,ua150,ua100,ua70,ua50,ua30"
  [zlev_ua0]="RCM_zlev_ua:ua100m,ua150m,ua50m"
  [zlev_ua1]="RCM_zlev_ua:ua300m,ua250m,ua200m"
)

#----------------------------------------------------------------
# TIME[name] — --time for the processing job.
# Unchanged varsets keep their limit (all are above the measured maximum).
# New/re-split varsets: expected run time + 4h, rounded up to the hour.
#----------------------------------------------------------------
declare -A TIME=(
  [out1]="14:00:00"        # est ~9h12 (13 vars)
  [out2]="10:00:00"        # est ~5h12 (ps,sfcWind,z0 + tau's 3h05)
  [soil]="12:00:00"        # max 5h05
  [rad]="18:00:00"         # max 11h39
  [snw]="12:00:00"         # max 6h06
  [cloud1]="17:00:00"      # ~12h03 (half of cloud's 24h06)
  [cloud2]="17:00:00"      # ~12h03
  [wxtrm]="08:00:00"       # max 0h00m17s
  [wpth1]="13:00:00"       # ~8h43 (half of old wpth1's 17h25)
  [wpth2]="10:00:00"       # max 7h58
  [wpth3]="13:00:00"       # ~8h43
  [plev_wa]="22:00:00"     # max 10h57
  [plev_zg]="22:00:00"     # max 14h35
  [plev_uava]="28:00:00"   # max 19h38
  [plev_hus]="18:00:00"    # max 10h41
  [plev_ta]="18:00:00"     # max 12h03
  [zlev_hus]="10:00:00"    # max 4h05
  [zlev_ta]="10:00:00"     # max 5h37
  [zlev_uava0]="25:00:00"  # est ~20h54 (was 12:00 — too short)
  [zlev_uava1]="25:00:00"  # est ~20h54 (was 12:00 — too short)
  [fx]="01:00:00"
  [testex]="08:00:00"
  [teste]="08:00:00"
  # manual-only
  [cloud]="28:00:00"       # max 24h06 (was 26:00 — less than 2h headroom)
  [tau]="16:00:00"         # max 3h05
  [zlev_va0]="19:00:00"
  [zlev_va1]="19:00:00"
)

#----------------------------------------------------------------
# CP_TIME[name] — walltime for this varset's archive/copy job
# (run_cp_generic.sh). Longest archive job measured: cp-out1 at 1h31.
#----------------------------------------------------------------
DEFAULT_CP_TIME="20:00:00"
declare -A CP_TIME=(
  [out1]="20:00:00"
  [out2]="20:00:00"
)

#----------------------------------------------------------------
# MEMORY of the processing job, only for the varsets that need more
# than the default of the machine (8 GB per job at ECMWF).
#
# A program keeps the whole year of its output in memory:
#   one hourly variable   424 x 412 x 8760 x 4 bytes =  6.1 GB  (fits)
#   zlev_uava: ua and va, both hourly                = 12.2 GB  (does not)
#----------------------------------------------------------------
DEFAULT_MEM="8G"
declare -A MEM=(
  [zlev_uava0]="16G"
  [zlev_uava1]="16G"
)

#----------------------------------------------------------------
# CP_EXTRA[name] — an additional varset to archive alongside this one.
# plev_uava/zlev_uava0/zlev_uava1 only ever *process* the v-component
# (their VARSETS[] entry lists va* variables), but the underlying programs
# produce matching u-component files too. So archiving needs both: the
# varset itself (v) plus its CP_EXTRA companion (u, from the archive-only
# plev_ua/zlev_ua0/zlev_ua1 entries above). run_out_generic.sh submits
# run_cp_generic.sh twice when CP_EXTRA[$VARSET] is set.
#----------------------------------------------------------------
declare -A CP_EXTRA=(
  [plev_uava]="plev_ua"
  [zlev_uava0]="zlev_ua0"
  [zlev_uava1]="zlev_ua1"
)

#----------------------------------------------------------------
# ADVANCE_YEAR[name] — whether this varset's own script increments
# yeari/yearf by 1 before resubmitting. Exactly ONE link per stream
# advances: the last link before the chain returns to its ORDER entry (or
# the varset itself, for self-loops). The chain stops after that link has
# run year_lim.
#----------------------------------------------------------------
declare -A ADVANCE_YEAR=(
  [wxtrm]=1        [zlev_uava0]=1  [zlev_uava1]=1
  [wpth1]=1        [wpth3]=1       [snw]=1
  [wpth2]=1        [out1]=1        [zlev_ta]=1
  [out2]=1
  [testex]=1       [teste]=1
  # plev_uava, cloud1, cloud2, plev_zg, plev_ta, rad, plev_wa, zlev_hus,
  # plev_hus, soil: unset -> 0 (the last link of their stream advances)
)

#----------------------------------------------------------------
# NEXT[name] — what a varset's own year-loop resubmits when it finishes.
# One chain per stream — see the table at the top of this file.
#----------------------------------------------------------------
declare -A NEXT=(
  [plev_uava]="wxtrm"   [wxtrm]="plev_uava"
  [zlev_uava0]="zlev_uava0"
  [zlev_uava1]="zlev_uava1"
  [cloud1]="wpth1"      [wpth1]="cloud1"
  [cloud2]="wpth3"      [wpth3]="cloud2"
  [plev_zg]="snw"       [snw]="plev_zg"
  [plev_ta]="wpth2"     [wpth2]="plev_ta"
  [rad]="out1"          [out1]="rad"
  [plev_wa]="zlev_hus"  [zlev_hus]="zlev_ta"  [zlev_ta]="plev_wa"
  [plev_hus]="soil"     [soil]="out2"         [out2]="plev_hus"
#  [testex]="testex"
  [teste]="teste"
)

# The set (and order) run_Analysis_v2.sh submits directly — the first link
# of each stream (the rest of each chain is reached via NEXT).
ORDER=(plev_uava zlev_uava0 zlev_uava1 cloud1 cloud2 plev_zg plev_ta rad plev_wa plev_hus)
