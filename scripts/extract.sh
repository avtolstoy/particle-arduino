#!/bin/bash

set -x

function exit_err {
    echo "$1"
    exit 1
}

DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
FIRMWARE_DIR="${1}"
DEST_DIR="${2}"
VERSION="${3}"

export GCC_PREFIX

if [ -z "${DEST_DIR}" ] || [ ! -d "${FIRMWARE_DIR}" ]; then
    echo "Usage: $0 <firmware directory> <destination directory> (version tag)"
    exit 1
fi

cd "${FIRMWARE_DIR}"

git reset --hard HEAD || exit_err "git reset"
git fetch --prune || exit_err "git fetch"

if [ ! -z "${VERSION}" ]; then
    git checkout "tags/v${VERSION}" || exit_err "git checkout"
fi

HEADERS=$(find . -type f -iname "*.h" -o -iname "*.hh" -o -iname "*.ld" -o -iname "*.inc")

mkdir -p "${DEST_DIR}" || exit_err "Failed to create destination directory"
mkdir -p "${DEST_DIR}/cores/particle/firmware" || exit_err "Failed to create cores directory"
mkdir -p "${DEST_DIR}/variants" || exit_err "Failed to create variants"
rm -rf "${DEST_DIR}/cores/particle/firmware/*"
rm -rf "${DEST_DIR}/variants/*"

for f in ${HEADERS}; do
   rsync -q -R "$f" "${DEST_DIR}/cores/particle/firmware/"
done

# Photon/P1
cd "${FIRMWARE_DIR}/modules/photon/user-part"
PHOTON_SOURCES=$(find . -type f -iname "*.c" -o -iname "*.cpp")
mkdir -p "${DEST_DIR}/variants/photon"
mkdir -p "${DEST_DIR}/variants/p1"

for f in ${PHOTON_SOURCES}; do
   rsync -q -R "$f" "${DEST_DIR}/variants/photon"
   rsync -q -R "$f" "${DEST_DIR}/variants/p1"
done

# Electron
cd "${FIRMWARE_DIR}/modules/electron/user-part"
ELECTRON_SOURCES=$(find . -type f -iname "*.c" -o -iname "*.cpp")
mkdir -p "${DEST_DIR}/variants/electron"

for f in ${ELECTRON_SOURCES}; do
   rsync -q -R "$f" "${DEST_DIR}/variants/electron"
done

# Core
cd "${FIRMWARE_DIR}"
CORE_SOURCES=("./build/arm/startup/startup_stm32f10x_md.S" "./main/src/module_info.c")
mkdir -p "${DEST_DIR}/variants/core/src"

for f in ${CORE_SOURCES[@]}; do
   cp "$f" "${DEST_DIR}/variants/core/src"
done

# Shared
cd "${FIRMWARE_DIR}"
mkdir -p "${DEST_DIR}/variants/shared/stm32f2xx/inc"
mkdir -p "${DEST_DIR}/variants/shared/startup"
cp "./modules/shared/stm32f2xx/inc/user_part_export.c" "${DEST_DIR}/variants/shared/stm32f2xx/inc"
cp "./build/arm/startup/spark_init.S" "${DEST_DIR}/variants/shared/startup"

# Build libs
cd "${FIRMWARE_DIR}/modules"
make COMPILE_LTO=n PLATFORM=photon TEST=app/blank clean all || exit_err "Failed to build PLATFORM=photon"
make COMPILE_LTO=n PLATFORM=P1 TEST=app/blank clean all || exit_err "Failed to build PLATFORM=P1"
make COMPILE_LTO=n DEBUG_BUILD=y PLATFORM=electron TEST=app/blank clean all || exit_err "Failed to build PLATFORM=electron"
cd "${FIRMWARE_DIR}/main"
make COMPILE_LTO=y PLATFORM=core TEST=app/blank clean all || exit_err "Failed to build PLATFORM=core"

cd "${FIRMWARE_DIR}"

PHOTON_LIBS=(
    "./build/target/system-dynalib/platform-6-m/libsystem-dynalib.a"
    "./build/target/rt-dynalib/platform-6-m/librt-dynalib.a"
    "./build/target/wiring_globals/platform-6-m/libwiring_globals.a"
    "./build/target/wiring/platform-6-m/libwiring.a"
    "./hal/src/photon/lib/STM32F2xx_Peripheral_Libraries.a"
    "./build/target/hal-dynalib/platform-6-m/libhal-dynalib.a"
    "./build/target/communication-dynalib/platform-6-m/libcommunication-dynalib.a"
    "./build/target/services-dynalib/arm/libservices-dynalib.a"
    "./build/target/platform/platform-6-m/libplatform.a"
)
P1_LIBS=(
    "./build/target/system-dynalib/platform-8-m/libsystem-dynalib.a"
    "./build/target/rt-dynalib/platform-8-m/librt-dynalib.a"
    "./build/target/wiring_globals/platform-8-m/libwiring_globals.a"
    "./build/target/wiring/platform-8-m/libwiring.a"
    "./hal/src/photon/lib/STM32F2xx_Peripheral_Libraries.a"
    "./build/target/hal-dynalib/platform-8-m/libhal-dynalib.a"
    "./build/target/communication-dynalib/platform-8-m/libcommunication-dynalib.a"
    "./build/target/services-dynalib/arm/libservices-dynalib.a"
    "./build/target/platform/platform-8-m/libplatform.a"
)
ELECTRON_LIBS=(
    "./build/target/system-dynalib/platform-10-m/libsystem-dynalib.a"
    "./build/target/rt-dynalib/platform-10-m/librt-dynalib.a"
    "./build/target/wiring_globals/platform-10-m/libwiring_globals.a"
    "./build/target/wiring/platform-10-m/libwiring.a"
    "./build/target/hal-dynalib/platform-10-m/libhal-dynalib.a"
    "./build/target/communication-dynalib/platform-10-m/libcommunication-dynalib.a"
    "./build/target/services-dynalib/arm/libservices-dynalib.a"
    "./build/target/platform/platform-10-m/libplatform.a"
)
CORE_LIBS=(
    "./build/target/services/platform-0-lto/libservices.a"
    "./build/target/newlib_nano/platform-0-lto/libnewlib_nano.a"
    "./build/target/wiring_globals/platform-0-lto/libwiring_globals.a"
    "./build/target/hal/platform-0-lto/libhal.a"
    "./build/target/wiring/platform-0-lto/libwiring.a"   
    "./build/target/platform/platform-0-lto/libplatform.a"
    "./build/target/communication/platform-0-lto-prod-0/libcommunication.a"
    "./build/target/system/platform-0-lto/libsystem.a"
)

mkdir -p "${DEST_DIR}/variants/photon/lib"
mkdir -p "${DEST_DIR}/variants/p1/lib"
mkdir -p "${DEST_DIR}/variants/electron/lib"
mkdir -p "${DEST_DIR}/variants/core/lib"

for f in ${PHOTON_LIBS[@]}; do
   cp "$f" "${DEST_DIR}/variants/photon/lib"
done

for f in ${P1_LIBS[@]}; do
   cp "$f" "${DEST_DIR}/variants/p1/lib"
done

for f in ${ELECTRON_LIBS[@]}; do
   cp "$f" "${DEST_DIR}/variants/electron/lib"
done

for f in ${CORE_LIBS[@]}; do
   cp "$f" "${DEST_DIR}/variants/core/lib"
done

#
SYSTEM_VERSION_STRING=$(sed -n 's/^VERSION_STRING\s*=\s*\(.*\)$/\1/p' build/version.mk)
SYSTEM_PART2_MODULE_VERSION=$(sed -n 's/^SYSTEM_PART2_MODULE_VERSION\s*?=\s*\(.*\)$/\1/p' modules/shared/system_module_version.mk)
USER_PART_MODULE_VERSION=$(sed -n 's/^USER_PART_MODULE_VERSION\s*?=\s*\(.*\)$/\1/p' modules/shared/system_module_version.mk)

mkdir -p "${DEST_DIR}/firmwares"
rm -rf "${DEST_DIR}/firmwares/*"
FWS=(
    "system-part1-${VERSION}-photon.bin"
    "system-part2-${VERSION}-photon.bin"
    "system-part1-${VERSION}-p1.bin"
    "system-part2-${VERSION}-p1.bin"
    "system-part1-${VERSION}-electron.bin"
    "system-part2-${VERSION}-electron.bin"
    "tinker-${VERSION}-core.bin"
)

cd "${DEST_DIR}/firmwares"
for f in ${FWS[@]}; do
    wget "https://github.com/spark/firmware/releases/download/v${VERSION}/$f" -O "$f"
done

cd "${DEST_DIR}/"
cp -rf "${DIR}"/../arduino/* "./"

# Replace vars
sed -i "s/%SYSTEM_VERSION_STRING%/${SYSTEM_VERSION_STRING}/g" boards.txt
sed -i "s/%SYSTEM_PART2_MODULE_VERSION%/${SYSTEM_PART2_MODULE_VERSION}/g" boards.txt
sed -i "s/%USER_PART_MODULE_VERSION%/${USER_PART_MODULE_VERSION}/g" boards.txt

exit 0
