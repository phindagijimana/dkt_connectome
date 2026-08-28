# dkt_deep_atropos_seg — ANTsPyNet Deep Atropos segmentation on native T1w

FROM ubuntu:22.04

ENV PYTHONUNBUFFERED=1 \
    ANTSXNET_CACHE=/opt/antsxnet_cache \
    PATH=/usr/bin:/bin

RUN apt-get update && apt-get install -y --no-install-recommends \
      ca-certificates python3 python3-pip libgomp1 \
    && pip3 install --no-cache-dir \
      numpy nibabel ants antspynet \
    && rm -rf /var/lib/apt/lists/* \
    && mkdir -p /opt/antsxnet_cache /opt/deep_atropos_seg

COPY run_deep_atropos_seg.py /opt/deep_atropos_seg/run_deep_atropos_seg.py
COPY run_deep_atropos_seg.sh /usr/local/bin/run_deep_atropos_seg
RUN chmod +x /usr/local/bin/run_deep_atropos_seg

WORKDIR /work
ENTRYPOINT ["/usr/local/bin/run_deep_atropos_seg"]
CMD ["--help"]
