# Use the php:7.3-cli-buster base image
FROM php:7.3-cli-buster

# Environment variable for the V8 version
ENV V8_VERSION=7.4.288.21

# Update package lists and install necessary dependencies including python 2.7
RUN apt-get update -y --fix-missing && apt-get upgrade -y && \
    apt-get install -y --no-install-recommends \
    libtinfo5 libtinfo-dev \
    build-essential \
    curl \
    git \
    libglib2.0-dev \
    libxml2 \
    python2.7 \
    python2.7-dev \
    patchelf \
    ca-certificates \
    pkg-config \
    wget \
    && ln -sf /usr/bin/python2.7 /usr/bin/python && \
    rm -rf /var/lib/apt/lists/*

# Clone depot_tools and pull latest changes
RUN cd /tmp && \
    git clone https://chromium.googlesource.com/chromium/tools/depot_tools.git && \
    cd /tmp/depot_tools && git pull && \
    export PATH="$PATH:/tmp/depot_tools"

# Fetch and build V8
RUN export PATH="$PATH:/tmp/depot_tools" && \
    cd /tmp && fetch v8 && cd v8 && git checkout $V8_VERSION && gclient sync && \
    tools/dev/v8gen.py -vv x64.release -- is_component_build=true use_custom_libcxx=false && \
    ninja -C out.gn/x64.release/ && \
    mkdir -p /opt/v8/lib /opt/v8/include && \
    cp out.gn/x64.release/lib*.so out.gn/x64.release/*_blob.bin out.gn/x64.release/icudtl.dat /opt/v8/lib/ && \
    cp -R include/* /opt/v8/include/ && \
    for A in /opt/v8/lib/*.so; do patchelf --set-rpath '$ORIGIN' $A;done

# Install PHP V8JS extension (version 2.1.1)
RUN pecl install v8js-2.1.1 && \
    docker-php-ext-enable v8js

# Clean up unnecessary files after build
RUN rm -rf /tmp/*

# Verify PHP installation and V8JS extension
RUN php -m | grep -i v8js

# Default command
CMD ["php", "-a"]
