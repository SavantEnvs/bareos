# syntax=docker/dockerfile:1.7
#
# Commit-image Dockerfile (small form) on the org C/C++ base. Build from the repo root:
#   DOCKER_BUILDKIT=1 docker build -f mayhem/Dockerfile --build-arg COMMIT=$(git rev-parse HEAD) -t mytag .
FROM ghcr.io/savantenvs/base:20261023

ARG COMMIT
ARG REPO_URL
ARG SOURCE_DATE_EPOCH
ARG SANITIZER_FLAGS
ARG COVERAGE_FLAGS=
ARG MAYHEM_JOBS=

# Build dependencies: apt -dev packages, plus two CMake-fetched dependencies that apt ships too old or
# not at all, cached once from pinned release tarballs (SPEC §6.2 item 19) so build.sh runs offline.
USER root
ARG TL_EXPECTED_VER=1.1.0
ARG TL_EXPECTED_SHA256=1db357f46dd2b24447156aaf970c4c40a793ef12a8a9c2ad9e096d9801368df6
ARG UTFCPP_VER=4.2.1
ARG UTFCPP_SHA256=6d6a5493a111884cc085ee31babfe6d9960c8fb08fc80a64852eaeea8323dbc1
RUN [ -n "$SOURCE_DATE_EPOCH" ] && repro-sources-list.sh || true ; \
    apt-get update && apt-get install -yq --no-install-recommends \
        libacl1-dev libattr1-dev libcap-dev libcli11-dev libfmt-dev libgmock-dev libgtest-dev \
        libjansson-dev liblzo2-dev libmsgsl-dev libncurses-dev libpcre2-dev libpq-dev \
        libreadline-dev libtirpc-dev libxml2-dev libxxhash-dev \
 && rm -rf /var/lib/apt/lists/*
RUN set -e; \
    fetch() { name=$1; ver=$2; url=$3; sha=$4; d=/opt/toolchains/deps/$name-$ver; \
      mkdir -p "$d/src"; curl -fsSL -o /tmp/dep.tgz "$url"; \
      echo "$sha  /tmp/dep.tgz" | sha256sum -c -; \
      tar -xzf /tmp/dep.tgz --strip-components=1 -C "$d/src"; rm -f /tmp/dep.tgz; chmod -R a+rX "$d"; }; \
    fetch tl-expected "$TL_EXPECTED_VER" "https://github.com/TartanLlama/expected/archive/refs/tags/v${TL_EXPECTED_VER}.tar.gz" "$TL_EXPECTED_SHA256"; \
    fetch utfcpp "$UTFCPP_VER" "https://github.com/nemtrif/utfcpp/archive/refs/tags/v${UTFCPP_VER}.tar.gz" "$UTFCPP_SHA256"

USER mayhem
WORKDIR /mayhem
COPY --chown=2000:2000 . /mayhem

# Build everything (sanitized harnesses + normal-flags tests), under the compile-cache prefill when the base has it.
RUN if [ -x /opt/mayhem/ccache/prefill ]; then /opt/mayhem/ccache/prefill bash mayhem/build.sh; \
    else bash mayhem/build.sh; fi

RUN if [ -f mayhem/test.sh ]; then bash mayhem/test.sh; else echo "no mayhem/test.sh — repo ships no functional tests"; fi

LABEL org.opencontainers.image.source="${REPO_URL}" \
      org.opencontainers.image.revision="${COMMIT}" \
      rlenv.tier="commit" \
      rlenv.source_date_epoch="${SOURCE_DATE_EPOCH}" \
      rlenv.user="mayhem"

USER mayhem
WORKDIR /mayhem
