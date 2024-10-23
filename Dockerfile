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
    && git checkout $V8_VERSION

# Configure gclient and build v8 with minimal dependencies
RUN cd /tmp/v8 \
    && export PATH="/tmp/depot_tools:$PATH" \
    && echo 'solutions = [{"name": ".","url": "https://chromium.googlesource.com/v8/v8.git","deps_file": "DEPS","managed": False,"custom_deps": {"v8/test/*": None,"v8/testing/*": None,"v8/third_party/android_tools": None,"v8/third_party/catapult": None,"v8/third_party/colorama/src": None,"v8/tools/gyp": None,"v8/tools/luci-go": None,"v8/test/wasm-js": None}}]' > /tmp/v8/.gclient \
    && export DEPOT_TOOLS_UPDATE=0 \
    && export GCLIENT_SUPPRESS_GIT_VERSION_WARNING=1 \
    && yes | gclient sync --no-history --reset --nohooks \
    && tools/dev/v8gen.py -vv x64.release -- \
       is_component_build=true \
       use_custom_libcxx=false \
       v8_enable_test_features=false \
       v8_enable_i18n_support=true \
       treat_warnings_as_errors=false \
       use_goma=false \
       v8_static_library=false \
       is_debug=false \
       v8_enable_webassembly=false \
       v8_enable_debugging_features=false \
       v8_optimized_debug=false \
       exclude_unwind_tables=true \
       enable_iterator_debugging=false

# Build v8
RUN cd /tmp/v8 \
    && export PATH="/tmp/depot_tools:$PATH" \
    && ninja -C out.gn/x64.release d8 \
    && mkdir -p /opt/v8/{lib,include} \
    && find out.gn/x64.release -name "*.so" -exec cp {} /opt/v8/lib/ \; \
    && cp out.gn/x64.release/*_blob.bin /opt/v8/lib/ 2>/dev/null || true \
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