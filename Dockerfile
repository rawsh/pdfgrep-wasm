 FROM emscripten/emsdk:3.1.25


# Install dependencies
RUN apt-get update && apt-get install -y \
    git \
    python3 \
    python3-pip \
    gperf \
    libtool \
    gettext \
    autopoint \
    autoconf \
    pkg-config \
    python \
    texinfo \
    fig2dev \
    && rm -rf /var/lib/apt/lists/*

# Download zlib and unzip
RUN wget https://github.com/madler/zlib/releases/download/v1.2.13/zlib-1.2.13.tar.gz && \
    tar -xzf zlib-1.2.13.tar.gz && \
    rm zlib-1.2.13.tar.gz && \
    mv zlib-1.2.13 zlib

# download freetype
RUN wget https://github.com/freetype/freetype/archive/refs/tags/VER-2-12-1.tar.gz && \
    tar -xzf VER-2-12-1.tar.gz && \
    rm VER-2-12-1.tar.gz && \
    mv freetype-VER-2-12-1 freetype

# download fontconfig
RUN wget https://github.com/freedesktop/fontconfig/archive/refs/tags/2.14.1.tar.gz && \
    tar -xzf 2.14.1.tar.gz && \
    rm 2.14.1.tar.gz && \
    mv fontconfig-2.14.1 fontconfig

# download libexpat
RUN wget https://github.com/libexpat/libexpat/releases/download/R_2_5_0/expat-2.5.0.tar.gz && \
    tar -xzf expat-2.5.0.tar.gz && \
    rm expat-2.5.0.tar.gz && \
    mv expat-2.5.0 expat

# download poppler
RUN wget https://github.com/freedesktop/poppler/archive/refs/tags/poppler-22.11.0.tar.gz && \
    tar -xzf poppler-22.11.0.tar.gz && \
    rm poppler-22.11.0.tar.gz && \
    mv poppler-poppler-22.11.0 poppler
RUN git clone https://gitlab.freedesktop.org/poppler/test.git

# download pdfgrep
RUN wget https://github.com/hpdeifel/pdfgrep/archive/refs/tags/v2.1.2.tar.gz && \
    tar -xzf v2.1.2.tar.gz && \
    rm v2.1.2.tar.gz && \
    mv pdfgrep-2.1.2 pdfgrep

# download libjpeg-turbo
RUN wget https://github.com/libjpeg-turbo/libjpeg-turbo/archive/refs/tags/2.1.4.tar.gz && \
    tar -xzf 2.1.4.tar.gz && \
    rm 2.1.4.tar.gz && \
    mv libjpeg-turbo-2.1.4 libjpeg-turbo

# download openjpeg
RUN wget https://github.com/uclouvain/openjpeg/archive/refs/tags/v2.5.0.tar.gz && \
    tar -xzf v2.5.0.tar.gz && \
    rm v2.5.0.tar.gz && \
    mv openjpeg-2.5.0 openjpeg

# download libgpg-error
RUN wget https://github.com/gpg/libgpg-error/archive/refs/tags/libgpg-error-1.42.tar.gz && \
    tar -xzf libgpg-error-1.42.tar.gz && \
    rm libgpg-error-1.42.tar.gz && \
    mv libgpg-error-libgpg-error-1.42 libgpg-error

# download libgcrypt
RUN wget https://github.com/gpg/libgcrypt/archive/refs/tags/libgcrypt-1.9.3.tar.gz && \
    tar -xzf libgcrypt-1.9.3.tar.gz && \
    rm libgcrypt-1.9.3.tar.gz && \
    mv libgcrypt-libgcrypt-1.9.3 libgcrypt

# variable for emscripten lib path
ENV EMSCRIPTEN_PATH /emsdk/upstream/emscripten/cache/sysroot

# set pkg-config path
ENV PKG_CONFIG_PATH $EMSCRIPTEN_PATH/lib/pkgconfig


# ------------------------- #
# --- build dependencies --- #
# ------------------------- #

# build libgpg-error
# depends on binaries so we need to build it normally first
# TODO: sed Makefile to replace calls to native binaries with calls to generated js binaries
RUN cd libgpg-error && \
    ./autogen.sh && \
    ./configure --enable-maintainer-mode && \
    make -j && \
    mkdir native-bin && \
    cp ./src/gen-posix-lock-obj native-bin && \
    cp ./src/mkerrcodes native-bin && \
    cp ./src/mkheader native-bin && \
    cp ./src/gpg-error native-bin && \
    make install

# build libgpg-error for emscripten
# first make command fails because emcc builds the binaries for js
RUN cd libgpg-error && \
    emconfigure ./autogen.sh && \
    emconfigure ./configure --enable-static=yes --enable-shared=no --prefix=$EMSCRIPTEN_PATH && \
    emmake make -j; exit 0
RUN cd libgpg-error && \
    rm src/gen-posix-lock-obj src/mkerrcodes src/mkheader src/gpg-error && \
    cp ./native-bin/* src/ && \
    emmake make -j
RUN cd libgpg-error && \
    rm src/gen-posix-lock-obj src/mkerrcodes src/mkheader src/gpg-error && \
    cp ./native-bin/* src/ && \
    emmake make install


# build libjpeg-turbo
RUN cd libjpeg-turbo && \
    mkdir build && \
    cd build && \
    emcmake cmake -DENABLE_SHARED=0 -DCMAKE_INSTALL_PREFIX:PATH=${EMSCRIPTEN_PATH} .. && \
    emmake make -j && \
    emmake make install

# build openjpeg
RUN cd openjpeg && \
    mkdir build && \
    cd build && \
    emcmake cmake -DBUILD_SHARED_LIBS=0 -DCMAKE_INSTALL_PREFIX:PATH=${EMSCRIPTEN_PATH} .. && \
    emmake make -j && \
    emmake make install

# build libexpat
# need shared libraries or get `undefined symbol: XML_ErrorString` compiling poppler
# --disable-shared
RUN cd expat && \
    emconfigure ./buildconf.sh && \
    emconfigure ./configure --prefix=${EMSCRIPTEN_PATH} && \
    emmake make -j && \
    emmake make install

# build zlib
RUN cd zlib && \
    emconfigure ./configure --static --prefix=${EMSCRIPTEN_PATH} && \
    emmake make -j && \
    emmake make install

# build freetype
RUN cd freetype && \
    mkdir build && \
    cd build && \
    emcmake cmake -DBUILD_SHARED_LIBS=0 -DCMAKE_INSTALL_PREFIX:PATH=${EMSCRIPTEN_PATH} .. && \
    emmake make -j && \
    emmake make install

# build libgcrypt
# depends on binaries so we need to build it normally first
# TODO: sed Makefile to use ./gost-s-box.js instead of ./gost-s-box
RUN cd libgcrypt && \
    ./autogen.sh && \
    ./configure --enable-maintainer-mode --disable-asm && \
    make -j && \
    mkdir native-bin && \
    cp ./cipher/gost-s-box native-bin && \
    make install && \
    make distclean

# build libgcrypt for emscripten
# first make command fails because emcc builds the binaries for js
# need --disable-asm because emscripten does not support inline assembly
# need --disable-doc to avoid building ./yat2m
# need --enable-kfds=no to avoid building ./kfds
# --enable-static=yes --enable-shared=no
RUN cd libgcrypt && \
    emconfigure ./autogen.sh && \
    emconfigure ./configure --enable-maintainer-mode --disable-asm --disable-doc --prefix=$EMSCRIPTEN_PATH && \
    emmake make -j; exit 0

# need to remove tests from Makefile
RUN cd libgcrypt && \
    sed -ie 's:DIST_SUBDIRS = m4 compat mpi cipher random src doc tests:DIST_SUBDIRS = m4 compat mpi cipher random src:' Makefile && \
    sed -ie 's:SUBDIRS = compat mpi cipher random src \$(doc) tests:SUBDIRS = compat mpi cipher random src:' Makefile && \
    rm cipher/gost-s-box && \
    cp ./native-bin/gost-s-box cipher/ && \
    emmake make -j && \
    emmake make install

# # build fontconfig
# RUN cd fontconfig && \
#     emconfigure ./autogen.sh && \
#     emconfigure ./configure --disable-cache-build --disable-shared --enable-static --prefix=${EMSCRIPTEN_PATH} && \
#     emmake make -j && \
#     emmake make install

# download boost
# RUN wget https://boostorg.jfrog.io/artifactory/main/release/1.76.0/source/boost_1_76_0.tar.gz && \
#     tar -xzf boost_1_76_0.tar.gz && \
#     rm boost_1_76_0.tar.gz && \
#     mv boost_1_76_0 boost

# patch boost with emscripten patches
# COPY patches/boost.patch boost/
# RUN cd boost && \
#     patch -p0 < boost.patch

# # # # build boost
# RUN cd boost && \
#     ./bootstrap.sh --prefix=${EMSCRIPTEN_PATH}
# RUN cd boost && \
#     ./b2 variant=release toolset=emscripten 
    
# build poppler
# had to build without fontconfig to get it to work
# -DFONT_CONFIGURATION=generic
# -DTESTDATADIR=/src/test
# -DBUILD_SHARED_LIBS=0 
# TODO: fix build with fontconfig
# TODO: compile boost with emscripten
RUN cd poppler && \
    mkdir build && \
    cd build && \
    emcmake cmake -DFONT_CONFIGURATION=generic -DCMAKE_BUILD_TYPE=RELEASE -DENABLE_BOOST=OFF -DENABLE_QT5=OFF -DENABLE_QT6=OFF -DTESTDATADIR=/src/test -DCMAKE_INSTALL_PREFIX:PATH=${EMSCRIPTEN_PATH} ..; exit 0

RUN cd poppler/build && \
    LIBS="-s USE_BOOST_HEADERS=1" \
    emcmake cmake -DFONT_CONFIGURATION=generic -DCMAKE_BUILD_TYPE=RELEASE -DENABLE_BOOST=OFF -DENABLE_QT5=OFF -DENABLE_QT6=OFF -DTESTDATADIR=$PWD/testfiles -DCMAKE_INSTALL_PREFIX:PATH=${EMSCRIPTEN_PATH} .. && \
    emmake make -j && \
    emmake make install

RUN rm -rf pdfgrep
RUN mkdir /src/target/

# download pdfgrep
RUN wget https://pdfgrep.org/download/pdfgrep-2.1.2.tar.gz && \
    tar -xvf pdfgrep-2.1.2.tar.gz && \
    rm pdfgrep-2.1.2.tar.gz && \
    mv pdfgrep-2.1.2 pdfgrep


# build html file with emscripten
# RUN sed -ie "s|pdfgrep\$(EXEEXT)|pdfgrep.html\$(EXEEXT)|g" pdfgrep/src/Makefile.in
RUN sed -ie "s|pdfgrep\$(EXEEXT)|pdfgrep.js\$(EXEEXT)|g" pdfgrep/src/Makefile.in

# -s EXPORTED_RUNTIME_METHODS='[\"cwrap\",\"ENV\"]'
# -s EXPORTED_RUNTIME_METHODS='[\"FS\"]'
# -s EXPORTED_FUNCTIONS='["_main", "_flush_streams"]'
# -s BUILD_AS_WORKER=1
# -s STANDALONE_WASM

# compile standalone pdfgrep
RUN cd pdfgrep && \
    LIBS="-sSTANDALONE_WASM -sASSERTIONS -sALLOW_MEMORY_GROWTH -sINVOKE_RUN=0 -sEXPORTED_RUNTIME_METHODS='[\"FS\",\"callMain\"]'" \
    poppler_cpp_LIBS="-lpoppler -lpoppler-cpp -ljpeg -lopenjp2 -lfreetype -lz" \
    emconfigure ./configure --target=wasm32-wasi --without-libpcre --bindir=/src/target --prefix=${EMSCRIPTEN_PATH} && \
    emmake make -j && \
    emmake make install

# build pdfgrep
# RUN cd pdfgrep && \
#     LIBS="-sASSERTIONS -sALLOW_MEMORY_GROWTH -sINVOKE_RUN=0 -sEXIT_RUNTIME=0 -sEXPORTED_RUNTIME_METHODS='[\"FS\",\"callMain\"]'" \
#     poppler_cpp_LIBS="-lpoppler -lpoppler-cpp -ljpeg -lopenjp2 -lfreetype -lz" \
#     emconfigure ./configure --without-libpcre --bindir=/src/target --prefix=${EMSCRIPTEN_PATH} && \
#     emmake make -j && \
#     emmake make install

# RUN cp pdfgrep/src/pdfgrep.wasm target
# RUN cp pdfgrep/src/pdfgrep.js target
# RUN cp pdfgrep/src/pdfgrep.html target