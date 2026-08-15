# TrackTBI Connectome Pipeline — OPTIONAL Docker orchestrator (not used on HPC).
#
# Production on URMC/TrackTBI HPC: use submit.sh + Apptainer .sif files (see docs/installation.md).
# This Dockerfile is for cloud/docker-only deployments if needed later. Not published to a registry.
#
# Bundles Python + Snakemake + ./run only. Step images must still be mounted at runtime.
#
# Local build (from repo root):
#   docker build -f dwi_pipeline/Dockerfile -t tracktbi-connectome:local .

FROM python:3.11-slim-bookworm

LABEL org.opencontainers.image.title="TrackTBI Connectome Pipeline"
LABEL org.opencontainers.image.version="0.2.0"
LABEL org.opencontainers.image.source="https://github.com/phindagijimana/dkt_connectome"
LABEL org.opencontainers.image.documentation="https://dkt-connectome.readthedocs.io/en/latest/"
LABEL org.opencontainers.image.description="BIDS App orchestrator for lesion-aware structural connectomics (multi-container; mount step images at runtime)"
LABEL org.opencontainers.image.licenses="Apache-2.0"

RUN apt-get update && apt-get install -y --no-install-recommends \
    bash \
    git \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /opt/tracktbi

# Copy pipeline code only (keeps image small; bind-mount BIDS/data at runtime)
COPY dwi_pipeline /opt/tracktbi/dwi_pipeline

RUN pip install --no-cache-dir \
    "snakemake>=8.0,<10" \
    pyyaml \
    numpy \
    scipy \
    nibabel

RUN chmod +x /opt/tracktbi/dwi_pipeline/run \
    /opt/tracktbi/dwi_pipeline/docker-entrypoint.sh

WORKDIR /opt/tracktbi/dwi_pipeline
ENV PATH="/opt/tracktbi/dwi_pipeline:${PATH}"

ENTRYPOINT ["./docker-entrypoint.sh"]
CMD ["--help"]
