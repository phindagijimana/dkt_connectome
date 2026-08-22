# dkt_lesion_act — Post-QSIRecon lesion-aware ACT (ANTs + MRtrix from qsirecon.sif)

FROM ubuntu:22.04

ENV ANTSPATH=/opt/ants/bin \
    LD_LIBRARY_PATH=/opt/ants/lib:/opt/mrtrix3-latest/lib \
    PATH=/opt/ants/bin:/opt/mrtrix3-latest/bin:/usr/bin:/bin

RUN apt-get update && apt-get install -y --no-install-recommends \
      ca-certificates bc libgomp1 libgfortran5 zlib1g \
      libtiff5 libpng16-16 libfftw3-double3 \
    && rm -rf /var/lib/apt/lists/*

COPY ants /opt/ants
COPY mrtrix3-latest /opt/mrtrix3-latest
COPY run_lesion_aware_act.sh /usr/local/bin/run_lesion_aware_act
RUN chmod +x /usr/local/bin/run_lesion_aware_act

WORKDIR /work
ENTRYPOINT ["/usr/local/bin/run_lesion_aware_act"]
CMD ["--help"]
