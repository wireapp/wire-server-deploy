# Dockerfile to create an environment that contains the Nix package manager.

FROM ubuntu:18.04


ARG IMAGE_ARG_APT_MIRROR
ARG IMAGE_ARG_NIX_VERSION
ARG IMAGE_ARG_NIX_DIGEST


#${ARIA2C_DOWNLOAD} -d ${out_dir} -o ${out_file} ${url}
# wget -q -O ${out_dir}/${out_file} ${url}
# curl -o ${out_dir}/${out_file} ${url}
ENV ARIA2C_DOWNLOAD aria2c --file-allocation=none -c -x 10 -s 10 -m 0 --console-log-level=notice --log-level=notice --summary-interval=0


COPY --chown=root:root docker/etc /etc/
COPY --chown=root:root docker/root /root/

# Create a user with id 1000 to avoid premission problem when mount host's directory into container
# Install openssl to enable HTTPS support in wget.
RUN set -ex \
  && echo ===== Install libs and tools ===== \
  && sed -i "s/http:\/\/archive.ubuntu.com\/ubuntu\//http:\/\/${IMAGE_ARG_APT_MIRROR:-archive.ubuntu.com}\/ubuntu\//g" /etc/apt/sources.list \
  && apt -y update \
  && apt -y upgrade \
  && apt -y install apt-transport-https apt-utils aria2 bsdmainutils bzip2 ca-certificates curl git gnupg2 httpie jq lsb-release lzma nano openssh-client openssl software-properties-common sudo tar unzip vim wget xz-utils zip \
  && apt -y install bc dnsutils gawk iproute2 iproute2-doc linux-tools-common net-tools socat strace telnet tcpdump \
  && apt -q -y autoremove \
  && apt -q -y clean && rm -rf /var/lib/apt/lists/* && rm -f /var/cache/apt/*.bin \
  && echo ===== Create user ===== \
  && groupadd --gid 1000 ubuntu \
  && mkdir -p /home/ubuntu \
  && useradd -c "ubuntu user" --home-dir /home/ubuntu --shell /bin/bash -g ubuntu -m --uid 1000 ubuntu && chown -R ubuntu:ubuntu /home/ubuntu \
  && usermod -a -G root ubuntu \
  && echo 'if [ "$BASH" ]; then if [ -f ~/.bashrc ]; then . ~/.bashrc; fi; fi' | tee -a /root/.bash_profile \
  && cp /root/.profile /home/ubuntu/.profile \
  && cp /root/.bashrc /home/ubuntu/.bashrc \
  && cp /root/.bash_profile /home/ubuntu/.bash_profile \
  && chown -R 1000:1000 /home/ubuntu \
  && echo "ubuntu ALL=(ALL) NOPASSWD: ALL" > /etc/sudoers.d/ubuntu \
  && chmod 0440 /etc/sudoers.d/ubuntu


WORKDIR /home/ubuntu
USER    ubuntu
ENV HOME=/home/ubuntu \
	SHELL=/bin/bash \
	USER=ubuntu


COPY --chown=ubuntu:ubuntu docker/home/ubuntu /home/ubuntu/

# see: https://github.com/NixOS/docker/blob/master/Dockerfile
# see: https://github.com/nix-community/docker-nix/blob/master/Dockerfile

#${ARIA2C_DOWNLOAD} https://nixos.org/releases/nix/nix-${IMAGE_ARG_NIX_VERSION:-2.0.4}/nix-${IMAGE_ARG_NIX_VERSION:-2.0.4}-x86_64-linux.tar.bz2
#echo "${IMAGE_ARG_NIX_DIGEST:-d6db178007014ed47ad5460c1bd5b2cb9403b1ec543a0d6507cb27e15358341f}  nix-${IMAGE_ARG_NIX_VERSION:-2.0.4}-x86_64-linux.tar.bz2" | sha256sum -c
# Download Nix and install it into the system.
RUN set -ex \
  && sudo chown root:root /etc/profile && sudo chmod 0644 /etc/profile \
  && if [ ! -f nix-${IMAGE_ARG_NIX_VERSION:-2.2.1}-x86_64-linux.tar.bz2 ]; then ${ARIA2C_DOWNLOAD} https://nixos.org/releases/nix/nix-${IMAGE_ARG_NIX_VERSION:-2.2.1}/nix-${IMAGE_ARG_NIX_VERSION:-2.2.1}-x86_64-linux.tar.bz2; fi \
  && echo "${IMAGE_ARG_NIX_DIGEST:-e229e28f250cad684c278c9007b07a24eb4ead239280c237ed2245871eca79e0}  nix-${IMAGE_ARG_NIX_VERSION:-2.2.1}-x86_64-linux.tar.bz2" | sha256sum -c \
  && tar xjf nix-${IMAGE_ARG_NIX_VERSION:-2.2.1}-x86_64-linux.tar.bz2 && rm -f nix-${IMAGE_ARG_NIX_VERSION:-2.2.1}-x86_64-linux.tar.bz2 \
  && sudo groupadd --gid 30000 --system nixbld \
  && for i in $(seq 1 30); do sudo useradd --system --home-dir /var/empty --comment "Nix build user $i" --uid $((30000 + i)) --groups nixbld nixbld$i ; done \
  && sudo mkdir -m 0755 /nix /etc/nix && sudo chmod a+rwx /nix && sudo chown ubuntu:ubuntu /nix \
  && printf 'sandbox = false\nuse-sqlite-wal = false' | sudo tee /etc/nix/nix.conf \
  && mkdir -p /home/ubuntu/.config/nix && printf 'sandbox = false\nuse-sqlite-wal = false' | tee /home/ubuntu/.config/nix/nix.fonf \
  && sudo mkdir -p /root/.config/nix && printf 'sandbox = false\nuse-sqlite-wal = false' | sudo tee /root/.config/nix/nix.fonf \
  && touch /home/ubuntu/.bash_profile && USER=ubuntu sudo -E nix-${IMAGE_ARG_NIX_VERSION:-2.2.1}-x86_64-linux/install \
  && sudo mv nix-${IMAGE_ARG_NIX_VERSION:-2.2.1}-x86_64-linux /root/ \
  && sudo bash -c "cd /root; nix-${IMAGE_ARG_NIX_VERSION:-2.2.1}-x86_64-linux/install" \
  && printf 'if [ -e /root/.nix-profile/etc/profile.d/nix.sh ]; then . /root/.nix-profile/etc/profile.d/nix.sh; fi # added by Nix installer\n' | sudo tee -a /root/.bash_profile \
  && sudo mkdir -p /root/.nix-defexpr && sudo ln -s /nix/var/nix/profiles/per-user/root/channels /root/.nix-defexpr/channels \
  && sudo chown -R ubuntu:ubuntu /nix && sudo chown -R ubuntu:ubuntu /home/ubuntu \
  && sudo chown root:root /home /etc \
  && sudo ln -s /nix/var/nix/profiles/default/etc/profile.d/nix.sh /etc/profile.d/ \
# ~/.bash_profile is updated by nix installer
  && echo ". /home/ubuntu/.nix-profile/etc/profile.d/nix.sh" | tee -a /home/ubuntu/.bashrc \
  && echo ". /home/ubuntu/.nix-profile/etc/profile.d/nix.sh" | tee -a /home/ubuntu/.profile \
  && USER=ubuntu . /home/ubuntu/.profile \
  && nix-env -iA \
       nixpkgs.bashInteractive \
       nixpkgs.cacert \
       nixpkgs.coreutils \
       nixpkgs.gitMinimal \
       nixpkgs.gnutar \
       nixpkgs.gzip \
       nixpkgs.iana-etc \
       nixpkgs.xz \
  && true \
  && sudo rm -fr /root/nix-${IMAGE_ARG_NIX_VERSION:-2.2.1}-x86_64-linux \
  && sudo chown 0 /nix/var/nix/profiles/per-user/root \
  && sudo chown 0 /nix/var/nix/gcroots/per-user/root \
  && sudo su - root sh -c 'exit' \
  && /nix/var/nix/profiles/default/bin/nix-collect-garbage --delete-old \
  && /nix/var/nix/profiles/default/bin/nix-store --optimise \
  && /nix/var/nix/profiles/default/bin/nix-store --verify --check-contents \
  && if [ ! -L /nix/var/nix/profiles/default/etc/ssl ]; then \
       ln -s $(find /nix/store -type d -name "*nss-cacert*")/etc/ssl /nix/var/nix/profiles/default/etc/ssl; \
       sudo chown -h ubuntu:ubuntu /nix/var/nix/profiles/default/etc/ssl; \
     fi

# nixpkgs.cacert fixes following issue
# fatal: unable to access 'https://github.com/owner/repo.git/': error setting certificate verify locations:
#   CAfile: /nix/var/nix/profiles/default/etc/ssl/certs/ca-bundle.crt
#   CApath: none
RUN set -ex \
  && sudo git config --system http.sslcainfo /nix/var/nix/profiles/default/etc/ssl/certs/ca-bundle.crt \
  && sudo git config --global http.sslverify "false"

ONBUILD ENV \
    ENV=/etc/profile \
    USER=ubuntu \
    PATH=/nix/var/nix/profiles/default/bin:/nix/var/nix/profiles/default/sbin:/bin:/sbin:/usr/bin:/usr/sbin \
    GIT_SSL_CAINFO=/nix/var/nix/profiles/default/etc/ssl/certs/ca-bundle.crt \
    NIX_SSL_CERT_FILE=/nix/var/nix/profiles/default/etc/ssl/certs/ca-bundle.crt

ENV \
    ENV=/etc/profile \
    USER=ubuntu \
    PATH=/nix/var/nix/profiles/default/bin:/nix/var/nix/profiles/default/sbin:/bin:/sbin:/usr/bin:/usr/sbin \
    GIT_SSL_CAINFO=/nix/var/nix/profiles/default/etc/ssl/certs/ca-bundle.crt \
    NIX_SSL_CERT_FILE=/nix/var/nix/profiles/default/etc/ssl/certs/ca-bundle.crt \
    NIX_PATH=/nix/var/nix/profiles/per-user/ubuntu/channels