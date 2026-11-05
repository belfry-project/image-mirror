# syntax=docker/dockerfile:1

# Receptor rebuilt from the upstream release with the newest Go toolchain and
# Go modules upgraded past upstream's pins (see go-upgrades.txt). The runtime
# image has the same layout as quay.io/ansible/receptor
# (upstream packaging/container/Dockerfile): /usr/bin/receptor, receptorctl,
# receptor-python-worker, ansible-runner and dumb-init on UBI 9.

# renovate: datasource=github-tags depName=ansible/receptor
ARG RECEPTOR_VERSION=v1.6.9
ARG RECEPTOR_COMMIT=58f9101cfb0d3bc0c11228bebcb51e729d0b99b4
# Rebuild number in the image tag (<upstream version>-belfry.<n>); reset to 1 for a new upstream version
ARG BELFRY_RELEASE=1

FROM scratch AS source
ARG RECEPTOR_COMMIT
ADD https://github.com/ansible/receptor.git#${RECEPTOR_COMMIT} /

FROM docker.io/library/golang:1.27.3@sha256:0c050feb47802ae436b9030833694a0b80160d08e3b3049ad30bf7c9e724e09d AS builder
ARG RECEPTOR_VERSION
COPY --from=source / /source
COPY scripts/upgrade-go-modules.sh receptor/go-upgrades.txt /build/
WORKDIR /source
RUN /build/upgrade-go-modules.sh /build/go-upgrades.txt \
 && make receptor VERSION="${RECEPTOR_VERSION#v}" \
 && ./receptor --version

FROM registry.access.redhat.com/ubi9/ubi:9.8@sha256:1963e00991088221a3405be7eb315a3dbc0be0f1f7440f0bd537d481cf33c83e AS wheels
ARG RECEPTOR_VERSION
COPY --from=source /receptorctl /source/receptorctl
COPY --from=source /receptor-python-worker /source/receptor-python-worker
RUN dnf -y install python3.12-pip \
 && python3.12 -m pip install --no-cache-dir build \
 && export SETUPTOOLS_SCM_PRETEND_VERSION="${RECEPTOR_VERSION#v}" \
 && python3.12 -m build --wheel --outdir /wheels /source/receptorctl \
 && python3.12 -m build --wheel --outdir /wheels /source/receptor-python-worker

FROM registry.access.redhat.com/ubi9/ubi:9.8@sha256:1963e00991088221a3405be7eb315a3dbc0be0f1f7440f0bd537d481cf33c83e
ARG RECEPTOR_VERSION

LABEL license="ASL2"
LABEL name="receptor"
LABEL version="${RECEPTOR_VERSION}"

COPY --from=source /packaging/container/receptor.conf /etc/receptor/receptor.conf

# The newer pip used for installing is removed again (it vendors an old
# setuptools); the pip3.12 of the python3.12-pip package stays available.
RUN --mount=type=bind,from=wheels,source=/wheels,target=/wheels \
    dnf -y update && \
    dnf -y install python3.12-pip && \
    dnf clean all && \
    rm -rf /var/cache/dnf && \
    pip3.12 install --no-cache-dir --upgrade pip && \
    pip3.12 install --no-cache-dir dumb-init ansible-runner /wheels/*.whl && \
    pip3.12 check && \
    pip3.12 uninstall -y pip

COPY --from=builder /source/receptor /usr/bin/receptor

RUN groupadd -r receptor && \
    useradd -r -g receptor -s /sbin/nologin receptor && \
    chown -R receptor:receptor /etc/receptor

ENV RECEPTORCTL_SOCKET=/tmp/receptor.sock

EXPOSE 7323

USER receptor

ENTRYPOINT ["/usr/local/bin/dumb-init", "--"]
CMD ["/usr/bin/receptor", "-c", "/etc/receptor/receptor.conf"]
