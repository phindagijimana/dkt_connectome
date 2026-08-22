# Lausanne-60 atlas assets (Connectome Mapper / easy_lausanne, BSD license).
#
# Bundled:
#   resolution150.graphml  — node metadata (129 regions at scale60)
#   gcs/myatlas_60_{lh,rh}.gcs — FreeSurfer spherical atlas files
#   mrtrix_lut/lausanne60_{fs,mrtrix}_lut.txt — labelconvert tables
#   atlas-Lausanne60_nodes.tsv — matrix row/column order
#
# Regenerate LUTs after graphml changes:
#   python3 scripts/generate_lausanne60_lut.py
#
# Reference: Hagmann et al. 2008; Cammoun et al. 2012; easy_lausanne.
