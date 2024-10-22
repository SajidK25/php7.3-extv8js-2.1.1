FROM php:7.3-cli-buster
ENV V8_VERSION=7.4.288.21

RUN apt-get update -y --fix-missing && apt-get upgrade -y;

# Install v8js (see https://github.com/phpv8/v8js/blob/php7/README.Linux.md)
RUN apt-get install -y --no-install-recommends \
    libtinfo5 libtinfo-dev \
    build-essential \
    curl \
    git \
    libglib2.0-dev \
    libxml2 \
    python \
    patchelf \
    && cd /tmp \
    \
    && git clone https://chromium.googlesource.com/chromium/tools/depot_tools.git --progress --verbose \
    \
    # Pull the latest changes from depot_tools to ensure it’s up-to-date
    && cd /tmp/depot_tools && git pull \
    \
    # Fix the functools.lru_cache issue in gclient_paths.py
    && sed -i 's/@functools.lru_cache()/@functools.lru_cache(maxsize=None)/' /tmp/depot_tools/gclient_paths.py \
    \
    && export PATH="$PATH:/tmp/depot_tools" \
    # Fetch v8 and check for errors
    && fetch v8 || (echo "Error: fetch v8 failed" && exit 1) \
    # Ensure that /tmp/v8 exists
    && [ -d /tmp/v8 ] || (echo "Error: /tmp/v8 directory not found" && exit 1) \
    \
    && cd /tmp/v8 \
    && git checkout $V8_VERSION \
    && gclient sync \
    \
    && tools/dev/v8gen.py -vv x64.release -- is_component_build=true use_custom_libcxx=false

RUN export PATH="$PATH:/tmp/depot_tools" \
    && cd /tmp/v8 \
    && ninja -C out.gn/x64.release/ \
    && mkdir -p /opt/v8/lib && mkdir -p /opt/v8/include \
    && cp out.gn/x64.release/lib*.so out.gn/x64.release/*_blob.bin out.gn/x64.release/icudtl.dat /opt/v8/lib/ \
    && cp -R include/* /opt/v8/include/ \
    && apt-get install patchelf \
    && for A in /opt/v8/lib/*.so; do patchelf --set-rpath '$ORIGIN' $A;done

# Install php-v8js
RUN cd /tmp \
    && git clone --depth 1 --branch 2.1.1 https://github.com/phpv8/v8js.git \
    && cd v8js \
    && phpize \
    && ./configure --with-v8js=/opt/v8 LDFLAGS="-lstdc++" \
    && make \
    && make test \
    && make install

RUN docker-php-ext-enable v8js
