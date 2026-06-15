#!/bin/bash

set -e

. ./config.sh

PROTOBUF_VERSION=3.6.1
PROTOBUF_URL="https://github.com/protocolbuffers/protobuf/releases/download/v${PROTOBUF_VERSION}/protobuf-cpp-${PROTOBUF_VERSION}.tar.gz"
PROTOBUF_DIR="${EXTERNAL_IOS_SOURCE_DIR}/protobuf-${PROTOBUF_VERSION}"
PROTOBUF_TAR="${EXTERNAL_IOS_SOURCE_DIR}/protobuf-cpp-${PROTOBUF_VERSION}.tar.gz"
NATIVE_BUILD_DIR="${EXTERNAL_IOS_SOURCE_DIR}/protobuf-native-build"
IOS_BUILD_DIR="${EXTERNAL_IOS_SOURCE_DIR}/protobuf-ios-build"
NATIVE_PREFIX="${EXTERNAL_DIR}/ios/native"

MIN_IOS_VERSION=13.0
IOS_SDK=$(xcrun --sdk iphoneos --show-sdk-path)

echo "============================ Protobuf ${PROTOBUF_VERSION} ============================"

# Skip if already built
if [ -f "${EXTERNAL_IOS_LIB_DIR}/libprotobuf.a" ] && [ -f "${NATIVE_PREFIX}/bin/protoc" ]; then
    echo "Protobuf already built, skipping."
    exit 0
fi

# Download if needed
if [ ! -f "$PROTOBUF_TAR" ]; then
    echo "Downloading protobuf ${PROTOBUF_VERSION}..."
    mkdir -p "${EXTERNAL_IOS_SOURCE_DIR}"
    curl -L -o "$PROTOBUF_TAR" "$PROTOBUF_URL"
fi

# Extract if needed
if [ ! -d "$PROTOBUF_DIR" ]; then
    echo "Extracting protobuf..."
    cd "${EXTERNAL_IOS_SOURCE_DIR}"
    tar xzf "$PROTOBUF_TAR"
fi

# ---- Step 1: Build native protoc (runs on macOS host) ----

if [ ! -f "${NATIVE_PREFIX}/bin/protoc" ]; then
    echo "Building native protoc for host..."
    rm -rf "$NATIVE_BUILD_DIR"
    mkdir -p "$NATIVE_BUILD_DIR"
    mkdir -p "$NATIVE_PREFIX"

    cd "$PROTOBUF_DIR"
    # Clean any previous build
    make distclean 2>/dev/null || true

    ./configure \
        --prefix="${NATIVE_PREFIX}" \
        --disable-shared \
        --enable-static \
        CXXFLAGS="-std=c++11"

    make -j$(sysctl -n hw.physicalcpu)
    make install
    make distclean
    echo "Native protoc built at ${NATIVE_PREFIX}/bin/protoc"
else
    echo "Native protoc already exists at ${NATIVE_PREFIX}/bin/protoc"
fi

# ---- Step 2: Cross-compile libprotobuf.a for iOS arm64 ----

if [ ! -f "${EXTERNAL_IOS_LIB_DIR}/libprotobuf.a" ]; then
    echo "Cross-compiling libprotobuf for iOS arm64..."
    rm -rf "$IOS_BUILD_DIR"
    mkdir -p "$IOS_BUILD_DIR"

    cd "$PROTOBUF_DIR"
    make distclean 2>/dev/null || true

    CC="clang -arch arm64 -isysroot ${IOS_SDK} -miphoneos-version-min=${MIN_IOS_VERSION}" \
    CXX="clang++ -arch arm64 -isysroot ${IOS_SDK} -miphoneos-version-min=${MIN_IOS_VERSION} -std=c++11" \
    ./configure \
        --prefix="${IOS_BUILD_DIR}" \
        --host=arm-apple-darwin \
        --disable-shared \
        --enable-static \
        --with-protoc="${NATIVE_PREFIX}/bin/protoc" \
        CXXFLAGS="-std=c++11 -O2"

    make -C src libprotobuf.la -j$(sysctl -n hw.physicalcpu)
    make -C src install-libLTLIBRARIES install-nobase_includeHEADERS
    make install-pkgconfigDATA

    # Copy to iOS build output
    cp -r "${IOS_BUILD_DIR}/include/google" "${EXTERNAL_IOS_INCLUDE_DIR}/"
    cp "${IOS_BUILD_DIR}/lib/libprotobuf.a" "${EXTERNAL_IOS_LIB_DIR}/"

    # Remove protoc lib (not needed for iOS)
    rm -f "${EXTERNAL_IOS_LIB_DIR}/libprotoc.a" 2>/dev/null || true

    echo "iOS libprotobuf.a built successfully"
else
    echo "iOS libprotobuf.a already exists"
fi

echo "============================ Protobuf Done ============================"
echo "  Native protoc: ${NATIVE_PREFIX}/bin/protoc"
echo "  iOS lib:       ${EXTERNAL_IOS_LIB_DIR}/libprotobuf.a"
echo "  iOS headers:   ${EXTERNAL_IOS_INCLUDE_DIR}/google/protobuf/"
