#!/bin/bash

### on hokum
# ./wcb configure \
#       --build-debug="-O2 -ggdb3" \
#       --prefix=/home/bv/work/ls4gan/frappe/wct-nat/install \
#       --with-jsonnet=/home/bv/opt/go-jsonnet \
#       --with-tbb=/home/bv/opt/tbb \
#       --with-tbb-include=/home/bv/opt/tbb/include \
#       --with-tbb-lib=/home/bv/opt/tbb/lib/intel64/gcc4.8 \
#       --boost-include=/home/bv/opt/boost/include \
#       --boost-libs=/home/bv/opt/boost/lib \
#       --boost-mt \
#       --with-spdlog=/home/bv/opt/spdlog \
#       --with-libtorch=/home/bv/opt/libtorch \
#       --with-cuda=no

## for hdf5
## wget http://h5cpp.org/download/hdf5-1.10.6.tar.gz
## unpack and
## ./configure --prefix=$HOME/opt/hdf5 --disable-hl --enable-threadsafe --enable-build-mode=production --enable-shared --enable-static --enable-optimization=high --with-default-api-version=v110
## make -j (nproc)
## make install
##
## wget http://h5cpp.org/download/libh5cpp-dev_1.10.4.6-1~exp1_all.deb
## sudo dpkg -i libh5cpp-dev_1.10.4.6-1~exp1_all.deb 

top=$(dirname $(realpath $BASH_SOURCE))

prefix=$(dirname $(dirname $(which python)))
maybe=$(dirname $(dirname $prefix))
if [ "$maybe" != "$top" ] ; then
    echo "fixme"
    echo "$maybe"
    echo "$top"
    exit -1
fi

cd $top/wire-cell-toolkit

./wcb configure \
      --prefix=$prefix \
      --with-jsonnet=$HOME/opt/jsonnet \
      --with-jsonnet-libs=gojsonnet \
      --with-tbb=$HOME/opt/oneapi-tbb-2021.3.0 \
      --with-tbb-include=$HOME/opt/oneapi-tbb-2021.3.0/include \
      --with-tbb-lib=$HOME/opt/oneapi-tbb-2021.3.0//lib/intel64/gcc4.8 \
      --boost-include=$HOME/opt/boost-1-76-0/include/ \
      --boost-libs=$HOME/opt/boost-1-76-0/lib \
      --boost-mt \
      --with-spdlog=$HOME/opt/spdlog \
      --with-libtorch=$HOME/opt/libtorch \
      --with-hdf5=$HOME/opt/hdf5 \
      --with-h5cpp=/usr \
      --with-cuda=no


