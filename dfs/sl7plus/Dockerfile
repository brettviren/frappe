# This builds base sl7 plus:
# - some grid crypto
# - enough to get and pass checkPrerequisites

FROM docker.io/scientificlinux/sl:7

RUN yum -y install epel-release \
    && yum -y install https://repo.ius.io/ius-release-el7.rpm \
    && yum -y update \
    && yum -y install \
    redhat-lsb-core \
    subversion asciidoc bzip2-devel fontconfig-devel freetype-devel ftgl-devel gdbm-devel giflib-devel gl2ps-devel glew-devel glibc-devel ncurses-devel openssl-devel openldap-devel pcre2-devel readline-devel autoconf automake libtool lz4-devel swig texinfo tcl-devel tk-devel xz-devel xmlto xxhash xxhash-devel zlib-devel zstd libAfterImage-devel libcurl-devel libjpeg-turbo-devel libpng-devel libstdc++-devel libuuid-devel libX11-devel libXext-devel libXft-devel libXi-devel libXrender-devel libXt-devel libXpm-devel libXmu-devel libzstd-devel mesa-libGL-devel mesa-libGLU-devel perl-DBD-SQLite perl-ExtUtils-MakeMaker gcc gcc-c++ libgcc.i686 glibc-devel.i686 libstdc++.i686 libffi-devel \
    ftgl-devel gl2ps-devel xxhash xxhash-devel zstd libAfterImage-devel libzstd-devel \
    less wget curl git strace \
    && yum clean all
RUN curl https://scisoft.fnal.gov/scisoft/bundles/tools/checkPrerequisites | bash




#    yum -y install less curl wget tar perl redhat-lsb-core zip unzip rsync xxhash xxhash-libs cyrus-sasl-devel libzstd libzstd-devel mesa-libGL-devel mesa-libGLU-devel ftgl glew-devel gl2ps libstdc++-devel gcc gcc-c++ libgcc.i686 glibc-devel.i686 libstdc++.i686  libffi-devel libXft libXpm libSM libX11 libXext libXi libXrender libXt libXmu libAfterImage openssl openssl-devel sqlite strace krb5-workstation osg-wn-client voms-clients-cpp-2.0.14-1.el6.x86_64 gdbm-devel zstd libcurl-devel subversion asciidoc bzip2-devel fontconfig-devel freetype-devel ftgl-devel giflib-devel gl2ps-devel ncurses-devel openldap-devel pcre2-devel readline-devel autoconf automake libtool lz4-devel swig texinfo tcl-devel tk-devel xz-devel xmlto xxhash-devel libAfterImage-devel libjpeg-turbo-devel libpng-devel libuuid-devel libXft-devel libXi-devel libXrender-devel libXt-devel libXpm-devel libXmu-devel perl-DBD-SQLite perl-ExtUtils-MakeMaker strace git && \
