FROM wctbld

ARG WCTOOLKIT_VERSION=hybrid-wcls

## remove previous screw up
RUN rm -rf /usr/local/\{bin\,lib\,include/
RUN mkdir -p /usr/local/{bin,lib,include}


RUN cd /root \
    && git clone https://github.com/WireCell/wire-cell-toolkit.git \
    && cd wire-cell-toolkit \
    && git checkout ${WCTOOLKIT_VERSION} \
    && ./wcb configure \
    --prefix=/usr/local \
    --with-jsonnet=/usr/local \
    --with-jsonnet-libs=gojsonnet \
    --with-tbb=/opt/oneapi-tbb-2021.1.1 \
    --with-tbb-include=/opt/oneapi-tbb-2021.1.1/include \
    --with-tbb-lib=/opt/oneapi-tbb-2021.1.1/lib/intel64/gcc4.8 \
    --boost-include=/usr/local/include \
    --boost-libs=/usr/local/lib --boost-mt \
    --with-spdlog=/usr/local \
    --with-libtorch=/opt/libtorch \
    --with-cuda=no \
    && ./wcb --notests install \
    && rm -rf /usr/local/share/wirecell \
    && cp -a cfg /usr/local/share/wirecell \
    && cd /root && rm -rf wire-cell-toolkit

RUN ls -l /usr/local/bin

RUN cd /root \
    && git clone https://github.com/WireCell/wire-cell-data.git \
    && cp -a wire-cell-data/* /usr/local/share/wirecell \
    && rm -rf wire-cell-data

# COPY --from=0 /opt/wct /opt/wct
