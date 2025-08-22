ARG IMAGE=ubuntu:24.10
FROM ${IMAGE} AS development

ENV OPENSSL_LIB_DIR=/usr/lib/x86_64-linux-gnu/
ENV DEBIAN_FRONTEND=noninteractive

ENV CC=clang
ENV CXX=clang++

RUN apt-get update && \
  apt-get install -y \
    libcurl4-openssl-dev libssl-dev libxml2-dev git \
    make gcc g++ cmake vim p11-kit libp11-kit-dev \
    gnutls-bin ninja-build pkg-config curl zip unzip \
    tar libjson-c-dev clang

# install rustc for Azure SDK
RUN (curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y)

RUN git clone https://github.com/Azure/azure-sdk-for-cpp /tmp/sdk && \
  git -C /tmp/sdk checkout -f 800b05fc3022395d4243833a1087963300da36e9 && \
  AZURE_SDK_DISABLE_AUTO_VCPKG=1 cmake -S /tmp/sdk -B /tmp/build \
    -GNinja \
    -DCMAKE_BUILD_TYPE=Release \
    -DCMAKE_POSITION_INDEPENDENT_CODE=ON \
    -DDISABLE_AZURE_CORE_OPENTELEMETRY=1 \
    -DBUILD_WINDOWS_UWP=1 && \
  cmake --build /tmp/build -- -v && \
  cmake --install /tmp/build && \
  rm -rf /tmp/sdk /tmp/build

FROM development AS final
RUN git clone https://github.com/jepio/azure-keyvault-pkcs11.git /tmp/pkcs11 && \
  git -C /tmp/pkcs11 checkout -f 126ae2bc714f2867b6628b49962f388c4b314f5f && \
  cmake -S /tmp/pkcs11 -B /build -GNinja -DCMAKE_BUILD_TYPE=Release && \
  cmake --build /build -- -v && \
  cmake --install /build && \
  rm -rf /work /build

FROM ${IMAGE}
# dependencies for signing (PKCS11) and building sysexts
RUN apt-get update && DEBIAN_FRONTEND=noninteractive apt-get install -y \
    libcurl4 p11-kit libjson-c5 sudo curl systemd-repart \
    libengine-pkcs11-openssl

# preinstall sysext-bakery dependencies to speed up jobs
RUN DEBIAN_FRONTEND=noninteractive apt-get install -y \
    curl jq squashfs-tools xz-utils erofs-utils

COPY --from=final /usr/local/lib/pkcs11 /usr/local/lib/pkcs11
ENV PKCS11_MODULE_PATH="/usr/local/lib/pkcs11/azure-keyvault-pkcs11.so"

# move root home to /github/home as is expected by GitHub Actions
# (otherwise az CLI would look for configuration in /root)
RUN cd /tmp && \
  mkdir /github && \
  mv /root/ /github/home && \
  sed -i 's/:\/root:/:\/github\/home:/' /etc/passwd

# install Docker (for qemu GH action) an Azure CLI
RUN (curl --proto '=https' --tlsv1.2 -sSLf https://aka.ms/InstallAzureCLIDeb | bash)
RUN (curl --proto '=https' --tlsv1.2 -sSLf https://get.docker.com | bash)

RUN mkdir -p /etc/pkcs11/modules && \
  touch /etc/pkcs11/pkcs11.conf && \
  echo "module: /usr/local/lib/pkcs11/azure-keyvault-pkcs11.so" > /etc/pkcs11/modules/azure-keyvault-pkcs11.module && \
  echo "critical: yes" >> /etc/pkcs11/modules/azure-keyvault-pkcs11.module
