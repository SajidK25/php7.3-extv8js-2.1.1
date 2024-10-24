# Use PHP 7.3 CLI as the base image
FROM php:7.3-cli-buster

# Set environment variable for the desired V8 version
ENV V8_VERSION=7.4.288.21

# Update package list and install dependencies
RUN apt-get update -y --fix-missing && apt-get upgrade -y \
    && apt-get install -y --no-install-recommends \
    curl \
    git \
    build-essential \
    libglib2.0-dev \
    libtinfo5 libtinfo-dev \
    libxml2-dev \
    python \
    patchelf

# Install depot_tools to fetch V8
RUN cd /tmp \
    && git clone https://chromium.googlesource.com/chromium/tools/depot_tools.git \
    && export PATH="$PATH:/tmp/depot_tools" \
    && fetch v8 \
    && cd v8 \
    && git checkout $V8_VERSION \
    && gclient sync \
    && tools/dev/v8gen.py -vv x64.release -- is_component_build=true use_custom_libcxx=false

# Build and install V8
RUN export PATH="$PATH:/tmp/depot_tools" \
    && cd /tmp/v8 \
    && ninja -C out.gn/x64.release/ \
    && mkdir -p /opt/v8/lib && mkdir -p /opt/v8/include \
    && cp out.gn/x64.release/lib*.so out.gn/x64.release/*_blob.bin out.gn/x64.release/icudtl.dat /opt/v8/lib/ \
    && cp -R include/* /opt/v8/include/ \
    && apt-get install -y patchelf \
    && for A in /opt/v8/lib/*.so; do patchelf --set-rpath '$ORIGIN' $A;done

# Install PHP-V8JS extension (version 2.1.1)
RUN pecl install v8js-2.1.1 \
    && docker-php-ext-enable v8js

# Clean up unnecessary files to reduce image size
RUN apt-get remove -y build-essential git curl python patchelf \
    && apt-get autoremove -y \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/*

# Verify installation
RUN php -m | grep v8js

# Set default entrypoint to start PHP CLI
ENTRYPOINT ["php"]
