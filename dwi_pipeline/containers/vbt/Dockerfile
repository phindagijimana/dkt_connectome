# Staged FSL from qsiprep.sif ships its own libs under /opt/fsl/lib.
# Use Ubuntu 22.04 for CI apt; FSL binaries remain qsiprep-compatible at runtime.

FROM ubuntu:22.04

ENV FSLDIR=/opt/fsl \
    FSLOUTPUTTYPE=NIFTI_GZ \
    LD_LIBRARY_PATH=/opt/fsl/lib \
    PATH=/opt/fsl/bin:/usr/local/bin:/usr/bin:/bin

RUN apt-get update && apt-get install -y --no-install-recommends \
      ca-certificates \
      python3 \
      python3-pip \
      libgomp1 \
      libgfortran5 \
      zlib1g \
      libtiff5 \
      libpng16-16 \
      libfftw3-double3 \
      bc \
    && rm -rf /var/lib/apt/lists/* \
    && pip3 install --no-cache-dir nibabel numpy scipy

COPY fsl /opt/fsl
COPY run_vbt.py /opt/vbt/run_vbt.py
RUN chmod +x /opt/vbt/run_vbt.py \
    && ln -sf /opt/vbt/run_vbt.py /usr/local/bin/run_vbt.py

WORKDIR /work
ENTRYPOINT ["python3", "/opt/vbt/run_vbt.py"]
CMD ["--help"]
