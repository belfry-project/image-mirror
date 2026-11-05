# syntax=docker/dockerfile:1

# The ansible-operator base image rebuilt from the upstream release
# (operator-framework/ansible-operator-plugins, images/ansible-operator/Dockerfile)
# with the newest Go toolchain, Go modules upgraded past upstream's pins
# (see go-upgrades.txt), the newest UBI 9 minimal with all updates, and Python
# packages from requirements.txt (upstream's Pipfile.lock with vulnerable
# packages upgraded). Same layout as quay.io/operator-framework/ansible-operator.

# renovate: datasource=github-tags depName=operator-framework/ansible-operator-plugins
ARG ANSIBLE_OPERATOR_VERSION=v1.42.3
ARG ANSIBLE_OPERATOR_COMMIT=292a56a4877c8093037c0533f3ef3c7a6bbd78e2
# Rebuild number in the image tag (<upstream version>-belfry.<n>); reset to 1 for a new upstream version
ARG BELFRY_RELEASE=1

FROM scratch AS source
ARG ANSIBLE_OPERATOR_COMMIT
ADD https://github.com/operator-framework/ansible-operator-plugins.git#${ANSIBLE_OPERATOR_COMMIT} /

FROM docker.io/library/golang:1.27.3@sha256:0c050feb47802ae436b9030833694a0b80160d08e3b3049ad30bf7c9e724e09d AS builder
ARG ANSIBLE_OPERATOR_VERSION
ARG ANSIBLE_OPERATOR_COMMIT
COPY --from=source / /source
COPY scripts/upgrade-go-modules.sh ansible-operator/go-upgrades.txt /build/
WORKDIR /source
# Same flags as upstream's Makefile (GO_BUILD_LDFLAGS), which needs a git checkout
RUN /build/upgrade-go-modules.sh /build/go-upgrades.txt \
 && repo=$(go list -m) \
 && k8s_version=$(sed -n 's/^export K8S_VERSION = //p' Makefile) \
 && CGO_ENABLED=0 go build \
      -trimpath \
      -ldflags "-X '${repo}/internal/version.Version=${ANSIBLE_OPERATOR_VERSION}' \
                -X '${repo}/internal/version.GitVersion=${ANSIBLE_OPERATOR_VERSION}' \
                -X '${repo}/internal/version.GitCommit=${ANSIBLE_OPERATOR_COMMIT}' \
                -X '${repo}/internal/version.KubernetesVersion=v${k8s_version}' \
                -X '${repo}/internal/version.ImageVersion=${ANSIBLE_OPERATOR_VERSION}'" \
      -o /ansible-operator ./cmd/ansible-operator \
 && /ansible-operator version

FROM registry.access.redhat.com/ubi9/ubi-minimal:9.8@sha256:4b79c93106c14ad1c234907f83441ff0e4f8d24e78426a36e159098e9f7e6fa5 AS basebuilder
COPY ansible-operator/requirements.txt /build/requirements.txt
COPY --from=source /images/ansible-operator/ansible_runner_http /build/ansible_runner_http
ENV PIP_NO_CACHE_DIR=1
# Binary wheels only, verified against the hashes in requirements.txt; pip
# itself is removed again, as upstream does.
RUN set -e && microdnf clean all && rm -rf /var/cache/dnf/* \
  && microdnf update -y \
  && microdnf install -y python3.12 \
  && pushd /usr/local/bin && ln -sf ../../bin/python3.12 python3 && popd \
  && python3 -m ensurepip --upgrade \
  && python3 -m pip install --only-binary=:all: --require-hashes -r /build/requirements.txt \
  && python3 -m pip install --no-deps /build/ansible_runner_http/ \
  && python3 -m pip check \
  && python3 -m pip uninstall -y pip \
  && microdnf clean all \
  && rm -rf /var/cache/dnf

FROM registry.access.redhat.com/ubi9/ubi-minimal:9.8@sha256:4b79c93106c14ad1c234907f83441ff0e4f8d24e78426a36e159098e9f7e6fa5 AS base
ARG TARGETARCH
ARG ANSIBLE_OPERATOR_COMMIT
LABEL git_commit=${ANSIBLE_OPERATOR_COMMIT}

RUN mkdir -p /etc/ansible \
  && echo "localhost ansible_connection=local" > /etc/ansible/hosts \
  && echo '[defaults]' > /etc/ansible/ansible.cfg \
  && echo 'roles_path = /opt/ansible/roles' >> /etc/ansible/ansible.cfg \
  && echo 'library = /usr/share/ansible/openshift' >> /etc/ansible/ansible.cfg

RUN set -e && microdnf clean all && rm -rf /var/cache/dnf/* \
  && microdnf update -y \
  && microdnf install -y python3.12 \
  && microdnf clean all \
  && rm -rf /var/cache/dnf

COPY --from=basebuilder /usr/local/lib64/python3.12/site-packages /usr/local/lib64/python3.12/site-packages
COPY --from=basebuilder /usr/local/lib/python3.12/site-packages /usr/local/lib/python3.12/site-packages
COPY --from=basebuilder /usr/local/bin /usr/local/bin

ARG TINI_VERSION=v0.19.0
ADD --chmod=755 https://github.com/krallin/tini/releases/download/${TINI_VERSION}/tini-${TARGETARCH} /tini
RUN set -e \
  && case "${TARGETARCH}" in \
       amd64) sum=93dcc18adc78c65a028a84799ecf8ad40c936fdfc5f2a57b1acda5a8117fa82c ;; \
       arm64) sum=07952557df20bfd2a95f9bef198b445e006171969499a1d361bd9e6f8e5e0e81 ;; \
       *) echo "unsupported architecture ${TARGETARCH}"; exit 1 ;; \
     esac \
  && echo "${sum}  /tini" | sha256sum -c - \
  && /tini --version

FROM base AS final

ENV HOME=/opt/ansible \
  USER_NAME=ansible \
  USER_UID=1001

RUN echo "${USER_NAME}:x:${USER_UID}:0:${USER_NAME} user:${HOME}:/sbin/nologin" >> /etc/passwd \
  && mkdir -p ${HOME}/.ansible/tmp \
  && chown -R ${USER_UID}:0 ${HOME} \
  && chmod -R ug+rwx ${HOME}

WORKDIR ${HOME}
USER ${USER_UID}

COPY --from=builder /ansible-operator /usr/local/bin/ansible-operator

ENTRYPOINT ["/tini", "--", "/usr/local/bin/ansible-operator", "run", "--watches-file=./watches.yaml"]
