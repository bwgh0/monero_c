#!/bin/bash
set -e

echo "=== MoneroOne iOS Build (Trezor-enabled) ==="

cd "$(dirname "$0")"
WDIR="$PWD"

IOS_CC="clang -arch arm64 -isysroot /Applications/Xcode.app/Contents/Developer/Platforms/iPhoneOS.platform/Developer/SDKs/iPhoneOS.sdk"
IOS_CXX="clang++ -arch arm64 -isysroot /Applications/Xcode.app/Contents/Developer/Platforms/iPhoneOS.platform/Developer/SDKs/iPhoneOS.sdk"

IOS_PREFIX="$WDIR/external/ios/build/ios"

function verbose_copy() {
    echo "==> cp $1 $2"
    cp "$1" "$2"
}

# Step 1: Check all deps exist
echo "Checking dependencies..."
for lib in libssl.a libcrypto.a libsodium.a libzmq.a libunbound.a libprotobuf.a; do
    if [ ! -f "$IOS_PREFIX/lib/$lib" ]; then
        echo "MISSING: $IOS_PREFIX/lib/$lib"
        echo "Run the full build_single.sh first to build deps."
        exit 1
    fi
    echo "  OK: $lib"
done
if [ ! -d "$IOS_PREFIX/include/boost" ]; then
    echo "MISSING: boost headers"
    exit 1
fi
echo "  OK: boost headers"
if [ ! -f "$IOS_PREFIX/native/bin/protoc" ]; then
    echo "MISSING: native protoc"
    exit 1
fi
echo "  OK: native protoc"
echo "All deps present."

# Step 2: Build polyseed
echo ""
echo "=== Building polyseed ==="
POLYSEED_DIR="$WDIR/external/polyseed/build/host-apple-ios"
rm -rf "$POLYSEED_DIR"
mkdir -p "$POLYSEED_DIR"
pushd "$POLYSEED_DIR"
    CC="$IOS_CC" CXX="$IOS_CXX" cmake -DCMAKE_TOOLCHAIN_FILE=../../../ios-cmake/ios.toolchain.cmake -DPLATFORM=OS64 ../..
    make -j10
popd

# Step 3: Copy libs to depends dir
echo ""
echo "=== Copying libraries ==="
DEPENDS_DIR="$WDIR/monero/contrib/depends"
IOS_LIBS_DIR="$DEPENDS_DIR/host-apple-ios"
rm -rf "$IOS_LIBS_DIR"
mkdir -p "$IOS_LIBS_DIR/lib"
verbose_copy "$IOS_PREFIX/lib/libunbound.a" "$IOS_LIBS_DIR/lib/libunbound.a"
verbose_copy "$IOS_PREFIX/lib/libboost_chrono.a" "$IOS_LIBS_DIR/lib/libboost_chrono.a"
verbose_copy "$IOS_PREFIX/lib/libboost_locale.a" "$IOS_LIBS_DIR/lib/libboost_locale.a"
verbose_copy "$IOS_PREFIX/lib/libboost_date_time.a" "$IOS_LIBS_DIR/lib/libboost_date_time.a"
verbose_copy "$IOS_PREFIX/lib/libboost_filesystem.a" "$IOS_LIBS_DIR/lib/libboost_filesystem.a"
verbose_copy "$IOS_PREFIX/lib/libboost_program_options.a" "$IOS_LIBS_DIR/lib/libboost_program_options.a"
verbose_copy "$IOS_PREFIX/lib/libboost_regex.a" "$IOS_LIBS_DIR/lib/libboost_regex.a"
verbose_copy "$IOS_PREFIX/lib/libboost_serialization.a" "$IOS_LIBS_DIR/lib/libboost_serialization.a"
verbose_copy "$IOS_PREFIX/lib/libboost_system.a" "$IOS_LIBS_DIR/lib/libboost_system.a"
verbose_copy "$IOS_PREFIX/lib/libboost_thread.a" "$IOS_LIBS_DIR/lib/libboost_thread.a"
verbose_copy "$IOS_PREFIX/lib/libboost_wserialization.a" "$IOS_LIBS_DIR/lib/libboost_wserialization.a"
verbose_copy "$POLYSEED_DIR/libpolyseed.a" "$IOS_LIBS_DIR/lib/libpolyseed.a"
verbose_copy "$IOS_PREFIX/lib/libssl.a" "$IOS_LIBS_DIR/lib/libssl.a"
verbose_copy "$IOS_PREFIX/lib/libcrypto.a" "$IOS_LIBS_DIR/lib/libcrypto.a"
verbose_copy "$IOS_PREFIX/lib/libsodium.a" "$IOS_LIBS_DIR/lib/libsodium.a"
verbose_copy "$IOS_PREFIX/lib/libprotobuf.a" "$IOS_LIBS_DIR/lib/libprotobuf.a"

# Step 4: Install missing headers
echo ""
echo "=== Installing missing headers ==="
pushd "$WDIR/external/ios"
    ./install_missing_headers.sh
popd

# Step 5: CMake + Make for Monero
echo ""
echo "=== Building Monero (with Trezor) ==="
NATIVE_PREFIX="$IOS_PREFIX/native"
rm -rf "$WDIR/monero/build/host-apple-ios" 2>/dev/null || true
mkdir -p "$WDIR/monero/build/host-apple-ios"
pushd "$WDIR/monero/build/host-apple-ios"
    PREFIX="$IOS_PREFIX"
    env \
        CMAKE_INCLUDE_PATH="$PREFIX/include" \
        CMAKE_LIBRARY_PATH="$PREFIX/lib" \
        CC="$IOS_CC" CXX="$IOS_CXX" \
        cmake \
            -DCMAKE_POLICY_VERSION_MINIMUM=3.5 \
            -DHIDAPI_DUMMY=ON \
            -DIOS=ON \
            -DARCH=arm64 \
            -DCMAKE_BUILD_TYPE=Debug \
            -DSTATIC=ON \
            -DBUILD_GUI_DEPS=1 \
            -DUNBOUND_INCLUDE_DIR="$PREFIX/lib" \
            -DUSE_DEVICE_TREZOR=ON \
            -DUSE_DEVICE_TREZOR_LIBUSB=OFF \
            -DProtobuf_PROTOC_EXECUTABLE="$NATIVE_PREFIX/bin/protoc" \
            -DProtobuf_LIBRARY="$PREFIX/lib/libprotobuf.a" \
            -DProtobuf_INCLUDE_DIR="$PREFIX/include" \
            ../..
    CC=gcc CXX=g++ make wallet_api -j10
popd

echo ""
echo "=== Monero build complete ==="
echo "Now run: cd monero_libwallet2_api_c && ./build_ios.sh (or equivalent)"
