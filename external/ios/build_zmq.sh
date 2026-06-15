#!/bin/bash

set -e

. ./config.sh

ZMQ_PATH="${EXTERNAL_IOS_SOURCE_DIR}/libzmq"

echo "============================ ZMQ ============================"

# Skip if already built
if [ -f "${EXTERNAL_IOS_LIB_DIR}/libzmq.a" ]; then
    echo "ZMQ already built, skipping."
    exit 0
fi

echo "Cloning ZMQ from - $ZMQ_URL"

# Check if the directory already exists.
if [ -d "$ZMQ_PATH" ]; then
    echo "ZeroMQ directory already exists."
else
    echo "Cloning ZeroMQ from $ZeroMQ_URL"
    mkdir -p $ZMQ_PATH || true
    rm -rf $ZMQ_PATH
	cp -r "${MONEROC_DIR}/external/libzmq" $ZMQ_PATH
fi

cd $ZMQ_PATH

# iOS toolchain setup
IOS_SDK=$(xcrun --sdk iphoneos --show-sdk-path)
IOS_ARCH="arm64"
IOS_MIN_VERSION="13.0"

mkdir -p cmake-build
cd cmake-build
cmake .. \
    -DCMAKE_POLICY_VERSION_MINIMUM=3.5 \
    -DCMAKE_SYSTEM_NAME=iOS \
    -DCMAKE_OSX_DEPLOYMENT_TARGET=${IOS_MIN_VERSION} \
    -DCMAKE_OSX_ARCHITECTURES=${IOS_ARCH} \
    -DCMAKE_OSX_SYSROOT=${IOS_SDK} \
    -DBUILD_SHARED=OFF \
    -DBUILD_STATIC=ON \
    -DWITH_PERF_TOOL=OFF \
    -DWITH_DOC=OFF \
    -DZMQ_BUILD_TESTS=OFF \
    -DWITH_LIBSODIUM=OFF
make -j$(sysctl -n hw.logicalcpu)


cp ${ZMQ_PATH}/include/* $EXTERNAL_IOS_INCLUDE_DIR
cp ${ZMQ_PATH}/cmake-build/lib/libzmq.a $EXTERNAL_IOS_LIB_DIR