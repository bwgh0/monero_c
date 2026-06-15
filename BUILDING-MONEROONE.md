# Building libMoneroCombined.a (MoneroOne / iOS, Trezor-enabled)

This is a fork of [mrcyjanek/monero_c](https://github.com/mrcyjanek/monero_c)
(LGPL-3.0). It produces the `libMoneroCombined.a` static library shipped inside
`Monero.xcframework` in
[MoneroKit.Swift](https://github.com/bwgh0/MoneroKit.Swift), the dependency used
by the MoneroOne iOS app.

This file documents the corresponding source and the scripts used to control
compilation, as required by the LGPL-3.0.

## What was changed relative to upstream monero_c

All changes are MoneroOne-specific: enabling Trezor hardware-wallet support in an
iOS cross-compile, plus a light-wallet (LWS) bug fix.

### monero_c (this repo)
- `build_ios_trezor.sh` — new. Builds the combined iOS arm64 static library with
  Trezor support enabled.
- `external/ios/build_protobuf.sh` — new. Builds protobuf for iOS (Trezor dep).
- `patches/monero/0022-hidapi-dummy-trumps-host-hidapi.patch` — new.
- `patches/monero/0023-moneroone-ios-trezor-lws-fixes.patch` — new. Captures the
  changes to the `monero` submodule (see below).
- Modified `build_single.sh`, `monero_libwallet2_api_c/CMakeLists.txt`, and the
  `external/ios/build_*.sh` dependency scripts.

### monero submodule
Baseline commit: `78117c44af743187f61f6553c15a61281c4acfa5`
(monero_c's patched monero tree). MoneroOne's delta on top is in
`patches/monero/0023-moneroone-ios-trezor-lws-fixes.patch`:
- `cmake/CheckTrezor.cmake` — skip the protoc compile test (hangs on macOS 26
  under Gatekeeper; protobuf messages are pre-generated). Drop the LibUSB path
  (not available / not needed on the iOS sysroot).
- `CMakeLists.txt` — `HIDAPI_DUMMY` trumps a host (homebrew) hidapi during iOS
  cross-compile; bump `cmake_minimum_required` for the link test.
- `src/cryptonote_basic/cryptonote_basic_impl.h` — replace deprecated
  `std::unary_function` (removed in C++17).
- `src/wallet/wallet2.cpp` — fix inverted `validate_hex` checks in the
  `light_wallet_*` paths (the original threw on *valid* hex).

## Reproducing the binary

```bash
git clone https://github.com/bwgh0/monero_c
cd monero_c
git submodule update --init --recursive
git -C monero checkout 78117c44af743187f61f6553c15a61281c4acfa5
git -C monero apply ../patches/monero/0023-moneroone-ios-trezor-lws-fixes.patch
./build_single.sh monero aarch64-apple-ios -j$(sysctl -n hw.ncpu)   # builds deps
./build_ios_trezor.sh                                                # links libMoneroCombined.a
```

## License

LGPL-3.0, inherited from monero_c. See `LICENSE`. The bundled monero core code is
BSD-3-Clause (monero-project/monero).
