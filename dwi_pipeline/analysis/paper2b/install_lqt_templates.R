#!/usr/bin/env Rscript
# One-time LQT Figshare template install (Tractography_Atlas, DSI Studio, etc.).
# Must run serially — parallel downloads corrupt zips on NFS.

args <- commandArgs(trailingOnly = TRUE)
do_repair <- !("--no-repair-dsi" %in% args)

lib <- Sys.getenv("R_LIBS_USER", unset = "")
if (nzchar(lib)) {
  dir.create(lib, recursive = TRUE, showWarnings = FALSE)
  .libPaths(c(lib, .libPaths()))
}

if (!requireNamespace("LQT", quietly = TRUE)) {
  stop("R package LQT not installed; run install_lqt_r.sh first")
}

script_dir <- Sys.getenv("LQT_SCRIPT_DIR", unset = "")
ok_path <- if (nzchar(script_dir)) {
  file.path(script_dir, "lqt_templates_ok.R")
} else {
  "lqt_templates_ok.R"
}
if (file.exists(ok_path)) {
  source(ok_path, local = TRUE)
} else {
  lqt_templates_ok <- function() {
    dir.exists(system.file("extdata", "Tractography_Atlas", package = "LQT"))
  }
}

if (lqt_templates_ok()) {
  message("LQT templates already complete")
  quit(save = "no", status = 0)
}

if (!lqt_tract_ok()) {
  message("Downloading LQT Figshare templates (one-time; may take 30+ minutes)...")
  ns <- asNamespace("LQT")
  if (!exists("download_templates", envir = ns, inherits = FALSE)) {
    stop("LQT::download_templates not found in installed package")
  }
  tryCatch(
    get("download_templates", envir = ns)(),
    error = function(e) message("download_templates error (may be partial): ", conditionMessage(e))
  )
}

if (!lqt_tract_ok()) {
  stop("Tractography_Atlas missing after download_templates")
}

if (!lqt_dsi_ok() && do_repair) {
  message("DSI Studio missing; run repair_lqt_dsi_studio.sh from shell")
  quit(save = "no", status = 2)
}

if (!lqt_templates_ok()) {
  stop("LQT templates incomplete (Tractography and/or DSI Studio)")
}
message("LQT templates OK")
