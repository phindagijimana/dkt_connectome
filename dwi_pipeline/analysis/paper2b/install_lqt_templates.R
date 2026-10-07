#!/usr/bin/env Rscript
# One-time LQT Figshare template install (Tractography_Atlas, DSI Studio, etc.).
# Must run serially — parallel downloads corrupt zips on NFS.

lib <- Sys.getenv("R_LIBS_USER", unset = "")
if (nzchar(lib)) {
  dir.create(lib, recursive = TRUE, showWarnings = FALSE)
  .libPaths(c(lib, .libPaths()))
}

if (!requireNamespace("LQT", quietly = TRUE)) {
  stop("R package LQT not installed; run install_lqt_r.sh first")
}

tract_dir <- system.file("extdata", "Tractography_Atlas", package = "LQT")
if (dir.exists(tract_dir)) {
  message("LQT templates already present: ", tract_dir)
  quit(save = "no", status = 0)
}

message("Downloading LQT Figshare templates (one-time; may take 30+ minutes)...")
ns <- asNamespace("LQT")
if (!exists("download_templates", envir = ns, inherits = FALSE)) {
  stop("LQT::download_templates not found in installed package")
}
get("download_templates", envir = ns)()

if (!dir.exists(tract_dir)) {
  stop("download_templates finished but missing: ", tract_dir)
}
message("LQT templates OK: ", tract_dir)
