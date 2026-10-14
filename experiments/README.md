# `experiments`

One folder per experiment. The folder name is the experiment name, and it's what `EXPERIMENT` in `env.site.sh` selects (see the main [README.md](../README.md), §2). Each folder holds everything for that experiment:

```
experiments/<name>/
  <name>.sh                              <- grids to process and, per grid, WRF input / output / archive paths
  <name>_<DOMAIN_ID>_<grid>.ini          <- grid/domain setup        (one per grid)
  <name>_global_<DOMAIN_ID>_<grid>.ini   <- global attributes        (one per grid)
```

e.g. `experiments/fpsurb/` has `fpsurb.sh`, `fpsurb_EUR-12_d01.ini`, `fpsurb_global_EUR-12_d01.ini`, `fpsurb_PARIS-3_d02.ini` and `fpsurb_global_PARIS-3_d02.ini`.

To add an experiment, copy an existing folder, rename the folder and the files inside to the new name, and fill them in. Under normal circumstances you only set these files up once.

The settings in `<name>.sh` are described in the main README, §2. The rest of this page covers the two ini files each grid needs, both read by every `RCM_*` Fortran program via `run_out_generic.sh`:

  1) The `&cordex_config` namelist with raw-data paths and grid dimensions

  ## `<name>_<DOMAIN_ID>_<grid>.ini` — grid/domain setup

- **`<name>`** — the experiment name, the same as its folder (one value for all grids of that experiment);
     e.g. `cordex` for standard CORDEX-CMIP6 runs, `fpsurb` for FPS-URB-RCC runs.

- **`<DOMAIN_ID>`** — the CORDEX domain identifier for that grid, from `DOMAIN_ID[]` in `<name>.sh` (e.g. `EUR-12`, `PARIS-3`) — this one
     *does* vary per grid, even within one experiment (euro-cordex is `EUR-12` on `d01` ,fpsurb is `EUR-12` on `d01`, `PARIS-3` on `d02`).

- **`<grid>`** — matches a key in `run[]` in `<name>.sh` (e.g. `d01`, `d02`).


  In the `&cordex_config` namelist, set:
  
  - **Domain & geography** — the experiment  domain (`nz`/`nlon`/`nlat`/`xoffset`/`yoffset`), and the matching `geog` name.
  - **Naming conventions** — `dom`/`outdom`, the domain and model names used in the CMORised output filenames.


  - **`dir` / `dir2`** — placeholders `_OUTPUT_WRF_`/`_OUTPUT_DIR_`, sed'd in by `run_out_generic.sh` from that grid's
     `OUTPUT_WRF[<grid>]`/`OUTPUT_DIR[<grid>]` in `<name>.sh` (a trailing `/` is appended
     automatically, so don't include one). Don't hardcode real paths here — edit `<name>.sh` instead. Both are per grid,
     so `d01` and `d02` can read from and write to different places (and each grid's output must go to its own directory).

  - **`wrffile`** - placeholder `_WRFFILE_`,  sed'd in by `run_out_generic.sh` automatically picks the `wrfout` or `wrfxtrm` the variant. When, and only when, `<varset>` is `wxtrm` 
     (the one that runs `RCM_sfc_xtrm`); every other varset uses wrfout.

  2) The `&global_metadata` namelist: global (file-level) CF/CMOR attributes written into every output NetCDF file (institution, driving experiment, domain ID, and so on).
  
## `<name>_global_<DOMAIN_ID>_<grid>.ini` — global attributes


   **The actual values you fill in must come from the official CORDEX-CMIP6 controlled vocabulary, not be made up per-experiment:**

- **[WCRP-CORDEX/cordex-cmip6-cv](https://github.com/WCRP-CORDEX/cordex-cmip6-cv)**
  — the controlled vocabulary (CV) for CORDEX-CMIP6: valid domain IDs,
  institution IDs, driving-model/experiment IDs, and the other global
  attributes CMOR compliance depends on. Any global attribute here that
  identifies your experiment (domain, institution, driving model,
  experiment, ...) should be checked against this CV before a real run —
  using a value that isn't in it will produce output that isn't
  CORDEX-CMIP6 compliant even if it runs successfully.
