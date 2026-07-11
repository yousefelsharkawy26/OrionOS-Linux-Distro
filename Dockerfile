FROM archlinux:latest

# Install all build dependencies in one layer
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
        openssl \
        pacman-contrib \
        parted \
        sed \
        squashfs-tools \
        syslinux \
        reflector \
        git \
        wget \
        curl && \
    pacman -Scc --noconfirm && \
    rm -rf /var/cache/pacman/pkg/* /tmp/*

WORKDIR /build/orionos
