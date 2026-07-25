# connectome — lean legacy-staged structural connectome image (DK or DKT)
#
# build_ctx from build_connectome.sh:
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
      libpng16-16 \
      libfftw3-double3 \
    && rm -rf /var/lib/apt/lists/*

COPY ants /opt/ants
COPY mrtrix3-latest /opt/mrtrix3-latest
COPY freesurfer /opt/freesurfer
COPY run_connectome.sh /usr/local/bin/run_connectome
RUN chmod +x /usr/local/bin/run_connectome

# Missing runtime libraries do not break the build, only every later run
# (exit 127), so assert here instead of shipping a broken image.
RUN unresolved=0; \
    for d in /opt/mrtrix3-latest/bin /opt/freesurfer/bin /opt/ants/bin; do \
      for f in "$d"/*; do \
        [ -f "$f" ] && [ -x "$f" ] || continue; \
        if ldd "$f" 2>/dev/null | grep -q 'not found'; then \
          echo "BUILD ERROR: unresolved libraries for $f" >&2; \
          ldd "$f" 2>/dev/null | grep 'not found' >&2; \
          unresolved=1; \
        fi; \
      done; \
    done; \
    [ "$unresolved" -eq 0 ] || exit 1; \
    echo "[build] all staged binaries resolve their shared libraries"

WORKDIR /work
ENTRYPOINT ["/usr/local/bin/run_connectome"]
CMD ["--help"]
