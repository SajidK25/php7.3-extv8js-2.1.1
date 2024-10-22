FROM php:7.3-cli-buster
ENV V8_VERSION=7.4.288.21

# Install required packages
RUN apt-get update -y --fix-missing \
    && apt-get upgrade -y \
    && apt-get install -y --no-install-recommends \
    libtinfo5 \
    libtinfo-dev \
    build-essential \
    curl \
    git \
    libglib2.0-dev \
    libxml2 \
    python \
    patchelf \
    ca-certificates \
    && rm -rf /var/lib/apt/lists/*

# Set up depot_tools and fetch v8
RUN cd /tmp \
    && git clone https://chromium.googlesource.com/chromium/tools/depot_tools.git \
    && export PATH="/tmp/depot_tools:$PATH" \
    # Fix the functools.lru_cache issue
    && sed -i 's/@functools.lru_cache()/@functools.lru_cache(maxsize=None)/' /tmp/depot_tools/gclient_paths.py \
    # Initialize git config
    && git config --global user.email "docker@example.com" \
    && git config --global user.name "Docker Build" \
    # Create v8 directory explicitly
    && mkdir -p /tmp/v8 \
    && cd /tmp/v8 \
    && git clone https://chromium.googlesource.com/v8/v8.git . \
    && git checkout $V8_VERSION \
    && gclient config --spec 'solutions = [{"name": ".", "url": "https://chromium.googlesource.com/v8/v8.git", "deps_file": "DEPS", "managed": False, "custom_deps": {}}]' \
    && gclient sync -v \
    && tools/dev/v8gen.py -vv x64.release -- is_component_build=true use_custom_libcxx=false

# Build v8
RUN export PATH="/tmp/depot_tools:$PATH" \
    && cd /tmp/v8 \
    && ninja -C out.gn/x64.release/ \
    && mkdir -p /opt/v8/lib /opt/v8/include \
    && cp out.gn/x64.release/lib*.so out.gn/x64.release/*_blob.bin out.gn/x64.release/icudtl.dat /opt/v8/lib/ \
    && cp -R include/* /opt/v8/include/ \
    && for A in /opt/v8/lib/*.so; do patchelf --set-rpath '$ORIGIN' $A; done

# Install php-v8js
RUN cd /tmp \
    && git clone --depth 1 --branch 2.1.1 https://github.com/phpv8/v8js.git \
    && cd v8js \
    && phpize \
    && ./configure --with-v8js=/opt/v8 LDFLAGS="-lstdc++" \
    && make \
    && make test \
    && make install \
    && docker-php-ext-enable v8js

# Cleanup
RUN rm -rf /tmp/depot_tools /tmp/v8 /tmp/v8js