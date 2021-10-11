# coups container -o build-larsoft-09.32.00.sh larsoft-09.32.00-Linux64bit+3.10-2.17-s112-e20-prof_MANIFEST.txt
FROM brettviren/coups-larsoft:09.32.00-slf7-prof-e20-s112
# note, this version needs to be manually copied to a vunder in the setup below

# ARG WCTOOLKIT_VERSION=0.17.0
ARG WCTOOLKIT_VERSION=hybrid-wcls

## fixme: better to do a shallow clone

RUN source /products/setup && \
    setup larsoft v09_32_00 -q e20:prof && \
    setup git && \
    git clone https://github.com/WireCell/wire-cell-data.git && \
    git clone https://github.com/WireCell/wire-cell-toolkit.git && \
    cd wire-cell-toolkit && \
    git checkout $WCTOOLKIT_VERSION && \
    ./wcb configure \
    --prefix=/opt/wct \
    --with-eigen-include=$EIGEN_INC \
    --with-jsonnet=$GOJSONNET_FQ_DIR \
    --with-jsoncpp=$JSONCPP_FQ_DIR \
    --with-tbb=$TBB_FQ_DIR \
    --with-spdlog=$SPDLOG_FQ_DIR \
    --with-spdlog-lib=$SPDLOG_LIB \
    --boost-include=$BOOST_INC --boost-lib=$BOOST_LIB --boost-mt && \
    ./wcb install -p --notests && \
    cd .. && \
    cp -a wire-cell-toolkit/cfg/* /opt/wct/share/wirecell && \
    cp -a wire-cell-data/* /opt/wct/share/wirecell && \
    rm -rf wire-cell-toolkit rm -rf wire-cell-data

