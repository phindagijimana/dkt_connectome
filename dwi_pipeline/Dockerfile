# DKT Connectome — BIDS App orchestrator (Docker + Apptainer on HPC via build_orchestrator_sif.sh).
#
# Production on URMC HPC: submit.sh with PIPELINE_ENGINE=bids_app (default).
# This Dockerfile is for cloud/docker-only deployments if needed later.
#
# Bundles Python + Snakemake + ./run only. Step images must still be mounted at runtime.
#
# Local build (from repo root):
#   docker build -f dwi_pipeline/Dockerfile -t dkt-connectome:local .

FROM python:3.12-slim-bookworm

LABEL org.opencontainers.image.title="DKT Connectome"
LABEL org.opencontainers.image.version="0.2.1"
LABEL org.opencontainers.image.source="https://github.com/phindagijimana/dkt_connectome"
LABEL org.opencontainers.image.documentation="https://dkt-connectome.readthedocs.io/en/latest/"
LABEL org.opencontainers.image.description="BIDS App orchestrator for lesion-aware structural connectomics (multi-container; mount step images at runtime)"
LABEL org.opencontainers.image.licenses="Apache-2.0"

RUN apt-get update && apt-get install -y --no-install-recommends \
    bash \
    git \
    wget \
    ca-certificates \
    && wget -q -O /tmp/apptainer.deb \
      https://github.com/apptainer/apptainer/releases/download/v1.3.4/apptainer_1.3.4_amd64.deb \
    && (dpkg -i /tmp/apptainer.deb || apt-get install -f -y) \
    && rm -f /tmp/apptainer.deb \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /opt/dkt-connectome

# Copy pipeline code only (keeps image small; bind-mount BIDS/data at runtime)
COPY dwi_pipeline /opt/dkt-connectome/dwi_pipeline

RUN pip install --no-cache-dir \
    "snakemake>=8.0,<10" \
    pyyaml \
    numpy \
    scipy \
    nibabel

RUN chmod +x /opt/dkt-connectome/dwi_pipeline/run \
    /opt/dkt-connectome/dwi_pipeline/docker-entrypoint.sh

WORKDIR /opt/dkt-connectome/dwi_pipeline
ENV PATH="/opt/dkt-connectome/dwi_pipeline:${PATH}"
ENV DKT_CONTAINER_CACHE="/opt/dkt-connectome/containers"
RUN mkdir -p "${DKT_CONTAINER_CACHE}"

ENTRYPOINT ["./docker-entrypoint.sh"]
CMD ["--help"]
