# Shared checks for LQT Figshare extdata (Tractography_Atlas + DSI Studio).
lqt_tract_ok <- function() {
  dir.exists(system.file("extdata", "Tractography_Atlas", package = "LQT"))
}

lqt_dsi_ok <- function() {
  extdata <- system.file("extdata", package = "LQT")
  if (!nzchar(extdata)) {
    return(FALSE)
  }
  hits <- list.files(
    file.path(extdata, "DSI_studio"),
    pattern = "^dsi_studio$",
    recursive = TRUE,
    full.names = TRUE
  )
  hits <- hits[file.exists(hits)]
  length(hits) > 0L
}

lqt_templates_ok <- function() {
  lqt_tract_ok() && lqt_dsi_ok()
}
