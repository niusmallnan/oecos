FROM quay.io/luet/base:0.32.5 AS framework-build
COPY files/etc/luet/luet.yaml /etc/luet/luet.yaml
ENV LUET_NOLOCK=true

SHELL ["/usr/bin/luet", "install", "-y", "--system-target", "/framework"]

RUN system/cos-setup
RUN system/immutable-rootfs
RUN cloud-config/network
RUN cloud-config/recovery
RUN cloud-config/live
RUN cloud-config/boot-assessment
RUN cloud-config/default-services
RUN system/grub2-config
RUN system/base-dracut-modules
RUN system/grub2-efi-image
RUN system/grub2-artifacts

FROM ghcr.io/rancher/elemental-toolkit/elemental-cli:v0.10.7 AS elemental

FROM openeuler/openeuler:22.03-lts-sp2

ARG ARCH=amd64
ENV ARCH=${ARCH}

RUN dnf -y update && \
    dnf install -y dracut kernel grub2 dracut-network dracut-live rsync && \
    dnf clean all && \
    rm -rf /var/cache/yum

# Copy installed files from the luet repos
COPY --from=framework-build /framework /

# Copy elemental cli
COPY --from=elemental /usr/bin/elemental /usr/bin/elemental

## System layout

# Copy custom files
COPY files/ /

# Generate initrd with required elemental services
RUN dracut -f --regenerate-all

# OS level configuration
RUN echo "VERSION=6666" > /etc/os-release && \
    echo "GRUB_ENTRY_NAME=OECOS" >> /etc/os-release

RUN mkdir -p /usr/share/grub2/ && \
    cp -rf /x86_64-efi /usr/share/grub2/ && \
    mkdir -p /usr/share/efi/ && \
    cp -rf /x86_64 /usr/share/efi/
