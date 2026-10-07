#!/usr/bin/env Rscript
# Paper 2B — normative SDC via R LQT (jdwor/LQT), Griffis 2021 equivalent.
#
# Install once (interactive node):
#   remotes::install_github("jdwor/LQT")
#
# Usage:
#   Rscript run_lqt_r_one_subject.R TBI011011 /path/to/lesion_mni.nii.gz /path/to/out_dir
#
# Env:
#   LQT_PARCEL_NII — MNI parcellation NIfTI (must match DKT-78 order for head-to-head;
#                    ship custom atlas or remap — see docs/papers/LQT.md)

args <- commandArgs(trailingOnly = TRUE)
if (length(args) < 3) {
  stop("Usage: run_lqt_r_one_subject.R SUBJECT LESION_MNI OUT_DIR")
}

subject <- args[[1]]
lesion_mni <- args[[2]]
out_dir <- args[[3]]
dir.create(out_dir, recursive = TRUE, showWarnings = FALSE)

lib <- Sys.getenv("R_LIBS_USER", unset = "")
if (nzchar(lib)) {
  dir.create(lib, recursive = TRUE, showWarnings = FALSE)
  .libPaths(c(lib, .libPaths()))
}

if (!requireNamespace("LQT", quietly = TRUE)) {
  stop(
    "R package 'LQT' not installed. Run: bash dwi_pipeline/analysis/paper2b/install_lqt_r.sh"
  )
}

parcel_path <- Sys.getenv("LQT_PARCEL_NII", unset = NA_character_)
if (is.na(parcel_path) || !file.exists(parcel_path)) {
  stop(
    "Set LQT_PARCEL_NII to an MNI-registered DKT-78 (or comparable) parcellation NIfTI."
  )
}

pat_id <- paste0("sub-", subject)
cfg <- LQT::create_cfg_object(
  pat_ids = pat_id,
  lesion_paths = lesion_mni,
  out_path = out_dir,
  parcel_path = parcel_path,
  con_type = "end"
)

LQT::get_parcel_cons(cfg)

# R LQT writes *_percent_parcel_mats.RData under Parcel_Disconnection/
rdata <- list.files(
  out_dir,
  pattern = "_percent_parcel_mats\\.RData$",
  recursive = TRUE,
  full.names = TRUE
)
if (length(rdata) == 0) {
  stop("LQT finished but no *_percent_parcel_mats.RData found under ", out_dir)
}

load(rdata[[1]])
if (!exists("pct_sdc_matrix")) {
  stop("pct_sdc_matrix missing in ", rdata[[1]])
}

out_csv <- file.path(out_dir, "lqt_disconnection_matrix.csv")
write.table(
  pct_sdc_matrix / 100,
  out_csv,
  sep = ",",
  row.names = FALSE,
  col.names = FALSE
)
message("Wrote ", out_csv)
