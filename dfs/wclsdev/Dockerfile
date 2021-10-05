FROM brettviren/coups-larsoft:09.31.00-slf7-prof-e20-s112

RUN mkdir -p /products && \
    wget https://scisoft.fnal.gov/scisoft/bundles/tools/pullPackage && \
    chmod +x pullPackage && \
    ./pullPackage -r /products slf7 gojsonnet-v0_17_0 e20 

ARG WCTOOLKIT_VERSION=0.17.0

RUN source /products/setup \
    && setup git \
    && git clone https://github.com/WireCell/wire-cell-toolkit.git \
    && cd wire-cell-toolkit \
    && git checkout ${WCTOOLKIT_VERSION} 

RUN source /products/setup \
    && setup larsoft v09_31_00 -q e20:prof \
    && setup gojsonnet v0_17_0 -q e20 \
    && cd wire-cell-toolkit \
    && ./wcb configure -vv --prefix=/usr/local \
    --with-fftw-include=$FFTW_INC \
    --with-fftw-lib=$FFTW_LIBRARY \
    --with-jsoncpp-include=$JSONCPP_INC \
    --with-jsoncpp-lib=$JSONCPP_LIB \
    --with-jsonnet-include=$GOJSONNET_INC \
    --with-jsonnet-lib=$GOJSONNET_LIB \
    --with-jsonnet-libs=jsonnet \
    --with-tbb-include=$TBB_INC \
    --with-tbb-lib=$TBB_LIB \
    --with-eigen-include=$EIGEN_INC \
    --with-spdlog-lib=$SPDLOG_LIB \
    --with-spdlog-include=$SPDLOG_INC \
    --boost-include=$BOOST_INC \
    --boost-libs=$BOOST_LIB \
    --boost-mt || cat /wire-cell-toolkit/build/config.log 

RUN source /products/setup \
    && setup larsoft v09_31_00 -q e20:prof \
    && setup gojsonnet v0_17_0 -q e20 \
    && cd wire-cell-toolkit \
    && ./wcb --notests install \
    && rm -rf /usr/local/share/wirecell \
    && mkdir -p /usr/local/share/wirecell \
    && cp -a cfg /usr/local/share/wirecell/ \
    && cd / \
    && rm -rf wire-cell-toolkit

FROM brettviren/sl7plus

RUN mkdir -p /products && \
    wget https://scisoft.fnal.gov/scisoft/bundles/tools/pullPackage && \
    chmod +x pullPackage && \
    ./pullPackage -r /products slf7 gojsonnet-v0_17_0 e20 

COPY --from=0 /usr/local /usr/local
