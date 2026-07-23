# dk_connectome — lean legacy-staged Desikan–Killiany connectome image
#
# build_ctx from build_dk_connectome.sh:
#   freesurfer/      — mri_label2vol, mri_convert, FreeSurferColorLUT.txt
#   ants/            — from qsirecon.sif (/opt/ants)
#   mrtrix3-latest/  — from qsirecon.sif (/opt/mrtrix3-latest)

FROM ubuntu:22.04

ENV FREESURFER_HOME=/opt/freesurfer \
    ANTSPATH=/opt/ants/bin \
    LD_LIBRARY_PATH=/opt/ants/lib:/opt/mrtrix3-latest/lib \
    PATH=/opt/freesurfer/bin:/opt/ants/bin:/opt/mrtrix3-latest/bin:/usr/bin:/bin \
    MRTRIX_LUT=/opt/mrtrix3-latest/share/mrtrix3/labelconvert/fs_default.txt

RUN apt-get update && apt-get install -y --no-install-recommends \
      ca-certificates \
      bc \
      libgomp1 \
      libgfortran5 \
      zlib1g \
      libtiff5 \
      libjpeg62 \
    && rm -rf /var/lib/apt/lists/*

COPY ants /opt/ants
COPY mrtrix3-latest /opt/mrtrix3-latest
COPY freesurfer /opt/freesurfer
COPY run_dk_connectome.sh /usr/local/bin/run_dk_connectome
RUN chmod +x /usr/local/bin/run_dk_connectome

WORKDIR /work
ENTRYPOINT ["/usr/local/bin/run_dk_connectome"]
CMD ["--help"]
