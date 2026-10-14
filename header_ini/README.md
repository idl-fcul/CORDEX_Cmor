# `header_ini`

Per-domain grid and global-attribute configuration, read by every `RCM_*` Fortran program via `run_out_generic.sh` (see the main [README.md](../README.md), §2 and §3, for how these fit into a run).

There are two kinds of file `run_out_generic.sh` actually reads (Under normal circumstances you just need to setup these files once):

  1) The `&cordex_config` namelist with raw-data paths and grid dimensions

  ## `<EXPERIMENT>_<DOMAIN_ID>_<domain>.ini` — grid/domain setup

- **`<EXPERIMENT>`** — the experiment prefix, the experiment's name, i.e. its file `experiments/<EXPERIMENT>.sh`, selected by `EXPERIMENT` in `env.site.sh` (one value for all grids of that experiment); 
     e.g. `cordex` for standard CORDEX-CMIP6 runs, `fpsurb` for FPS-URB-RCC runs.

- **`<DOMAIN_ID>`** — the CORDEX domain identifier for that grid, from the experiment file's `DOMAIN_ID[]` map (e.g. `EUR-12`, `PARIS-3`) — this one
     *does* vary per grid, even within one experiment (euro-cordex is `EUR-12` on `d01` ,fpsurb is `EUR-12` on `d01`, `PARIS-3` on `d02`).

- **`<grid>`** — matches a key in the experiment file's `run` array (e.g. `d01`, `d02`).


  In the `&cordex_config` namelist, set:
  
  - **Domain & geography** — the experiment  domain (`nz`/`nlon`/`nlat`/`xoffset`/`yoffset`), and the matching `geog` name.
  - **Naming conventions** — `dom`/`outdom`, the domain and model names used in the CMORised output filenames.


  - **`dir` / `dir2`** — placeholders `_OUTPUT_WRF_`/`_OUTPUT_DIR_`, sed'd in by `run_out_generic.sh` from that grid's
     `OUTPUT_WRF[<grid>]`/`OUTPUT_DIR[<grid>]` in the experiment file (`experiments/<EXPERIMENT>.sh`; a trailing `/` is appended
     automatically, so don't include one). Don't hardcode real paths here — edit the experiment file instead. Both are per grid,
     so `d01` and `d02` can read from and write to different places (and each grid's output must go to its own directory).

  - **`wrffile`** - placeholder `_WRFFILE_`,  sed'd in by `run_out_generic.sh` automatically picks the `wrfout` or `wrfxtrm` the variant. When, and only when, `<varset>` is `wxtrm` 
     (the one that runs `RCM_sfc_xtrm`); every other varset uses wrfout.

  2) The `&global_metadata` namelist: global (file-level) CF/CMOR attributes written into every output NetCDF file (institution, driving experiment, domain ID, and so on).
  
## `<EXPERIMENT>_global_<DOMAIN_ID>_<domain>.ini` — global attributes


   **The actual values you fill in must come from the official CORDEX-CMIP6 controlled vocabulary, not be made up per-experiment:**

- **[WCRP-CORDEX/cordex-cmip6-cv](https://github.com/WCRP-CORDEX/cordex-cmip6-cv)**
  — the controlled vocabulary (CV) for CORDEX-CMIP6: valid domain IDs,
  institution IDs, driving-model/experiment IDs, and the other global
  attributes CMOR compliance depends on. Any global attribute here that
  identifies your experiment (domain, institution, driving model,
  experiment, ...) should be checked against this CV before a real run —
  using a value that isn't in it will produce output that isn't
  CORDEX-CMIP6 compliant even if it runs successfully.
