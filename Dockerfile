FROM archlinux:latest

# Update system and install build dependencies
RUN pacman -Syu --noconfirm && \
    pacman -S --noconfirm --needed \
        base-devel \
        archiso \
        arch-install-scripts \
        btrfs-progs \
        dosfstools \
        e2fsprogs \
        efibootmgr \
        grub \
        libisoburn \
        mtools \
        nasm \
        openssl \
        pacman-contrib \
        parted \
        patch \
        sed \
        squashfs-tools \
        syslinux \
        reflector \
        git \
        wget \
        curl \
    && pacman -Scc --noconfirm

# Set up build user
RUN useradd -m builder && \
    echo "builder ALL=(ALL) NOPASSWD: ALL" >> /etc/sudoers.d/builder

# Copy project
COPY --chown=builder:builder . /build/orionos

WORKDIR /build/orionos

USER builder

ENTRYPOINT ["/build/orionos/scripts/build/build-iso-docker.sh"]
