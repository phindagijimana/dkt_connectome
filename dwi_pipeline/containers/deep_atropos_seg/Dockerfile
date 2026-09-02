# dkt_deep_atropos_seg — ANTsPyNet Deep Atropos segmentation on native T1w

FROM python:3.10-slim-bookworm

ENV PYTHONUNBUFFERED=1 \
    ANTSXNET_CACHE=/opt/antsxnet_cache \
    PATH=/usr/local/bin:/usr/bin:/bin

RUN apt-get update && apt-get install -y --no-install-recommends \
      ca-certificates libgomp1 \
    && pip install --no-cache-dir \
      numpy==1.26.4 nibabel==5.2.1 scipy==1.11.4 \
      antspynet==0.2.7 \
    && rm -rf /var/lib/apt/lists/* \
    && mkdir -p /opt/antsxnet_cache /opt/deep_atropos_seg

COPY run_deep_atropos_seg.py /opt/deep_atropos_seg/run_deep_atropos_seg.py
COPY run_deep_atropos_seg.sh /usr/local/bin/run_deep_atropos_seg
RUN chmod +x /usr/local/bin/run_deep_atropos_seg

WORKDIR /work
ENTRYPOINT ["/usr/local/bin/run_deep_atropos_seg"]
CMD ["--help"]
