# dkt_deep_atropos — Deep Atropos seg → base_5tt_native.mif (MRtrix staged from qsirecon.sif)

FROM ubuntu:22.04

ENV LD_LIBRARY_PATH=/opt/mrtrix3-latest/lib \
    PATH=/opt/mrtrix3-latest/bin:/usr/bin:/bin

RUN apt-get update && apt-get install -y --no-install-recommends \
      ca-certificates python3 python3-pip libgomp1 libgfortran5 zlib1g \
      libtiff5 libpng16-16 libfftw3-double3 \
    && pip3 install --no-cache-dir nibabel numpy scipy \
    && rm -rf /var/lib/apt/lists/*

COPY mrtrix3-latest /opt/mrtrix3-latest
COPY convert_deep_atropos_to_5tt.py /opt/deep_atropos/convert_deep_atropos_to_5tt.py
COPY run_deep_atropos_5tt.sh /usr/local/bin/run_deep_atropos_5tt
RUN chmod +x /usr/local/bin/run_deep_atropos_5tt

WORKDIR /work
ENTRYPOINT ["/usr/local/bin/run_deep_atropos_5tt"]
CMD ["--help"]
