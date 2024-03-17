#!/usr/bin/env bash
# shellcheck disable=SC2199
# shellcheck source=/dev/null
#
# Copyright (C) 2020-22 UtsavBalar1231 <utsavbalar1231@gmail.com>
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#    http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

if ! [ -d "/workspace/tc/a3-clang" ]; then
echo "A3 clang not found! Cloning..."
if ! git clone -q -b 17.x https://gitlab.com/a3-Prjkt/a3-clang --depth=1 /workspace/tc/a3-clang; then
echo "Cloning failed! Aborting..."
exit 1
fi
fi

sudo apt update && sudo apt -y upgrade
sudo apt install -y cpio \
                    flex \
                    python-is-python3 \
                    libncurses5 \
                    libncurses5-dev \
                    ccache \
                    gcc-aarch64-linux-gnu \
                    bc

KBUILD_COMPILER_STRING=$(/workspace/tc/a3-clang/bin/clang --version | head -n 1 | perl -pe 's/\(http.*?\)//gs' | sed -e 's/  */ /g' -e 's/[[:space:]]*$//')
KBUILD_LINKER_STRING=$(/workspace/tc/a3-clang/bin/ld.lld --version | head -n 1 | perl -pe 's/\(http.*?\)//gs' | sed -e 's/  */ /g' -e 's/[[:space:]]*$//' | sed 's/(compatible with [^)]*)//')
export KBUILD_COMPILER_STRING
export KBUILD_LINKER_STRING
export KBUILD_BUILD_USER=forest
export KBUILD_BUILD_HOST=Disconnect0
export KBUILD_BUILD_VERSION="1"

DEVICE=$1

if [ "${DEVICE}" = "alioth" ]; then
DEFCONFIG=vendor/alioth_defconfig
elif [ "${DEVICE}" = "apollo" ]; then
DEFCONFIG=vendor/apollo_defconfig
elif [ "${DEVICE}" = "lmi" ]; then
DEFCONFIG=vendor/lmi_defconfig
elif [ "${DEVICE}" = "munch" ]; then
DEFCONFIG=vendor/munch_defconfig
elif [ "${DEVICE}" = "psyche" ]; then
DEFCONFIG=vendor/psyche_defconfig
fi

#
# Enviromental Variables
#

DATE=$(date '+%Y%m%d-%H%M')
SECONDS=0 # use bash builtin timer 

# Set our directory
OUT_DIR=out/

VERSION="UviteDC0-${DEVICE}-${DATE}"

# Export Zip name
export ZIPNAME="${VERSION}.zip"

# How much kebabs we need? Kanged from @raphielscape :)
if [[ -z "${KEBABS}" ]]; then
    COUNT="$(grep -c '^processor' /proc/cpuinfo)"
    export KEBABS="$((COUNT + 2))"
fi

echo "Jobs: ${KEBABS}"

ARGS="ARCH=arm64 \
O=${OUT_DIR} \
LLVM=1 \
CLANG_TRIPLE=aarch64-linux-gnu- \
CROSS_COMPILE=aarch64-linux-gnu- \
CROSS_COMPILE_COMPAT=arm-linux-gnueabi- \
-j${KEBABS}"

dts_source=arch/arm64/boot/dts/vendor/qcom

START=$(date +"%s")

# Set compiler Path
export PATH="/workspace/tc/a3-clang/bin:$PATH"
export LD_LIBRARY_PATH=/workspace/tc/a3-clang/lib64:$LD_LIBRARY_PATH

echo "------ Starting Compilation ------"

# Make defconfig
make -j${KEBABS} ${ARGS} ${DEFCONFIG}

# Make olddefconfig
cd ${OUT_DIR} || exit
make -j${KEBABS} ${ARGS} CC="ccache clang" HOSTCC="ccache gcc" HOSTCXX="cache g++" olddefconfig
cd ../ || exit

make -j${KEBABS} ${ARGS} CC="ccache clang" HOSTCC="ccache gcc" HOSTCXX="ccache g++" 2>&1 | tee build.log

find ${OUT_DIR}/$dts_source -name '*.dtb' -exec cat {} + >${OUT_DIR}/arch/arm64/boot/dtb

git checkout arch/arm64/boot/dts/vendor &>/dev/null

echo "------ Finishing Build ------"

END=$(date +"%s")
DIFF=$((END - START))
zipname="$VERSION.zip"
if [ -f "out/arch/arm64/boot/Image" ] && [ -f "out/arch/arm64/boot/dtbo.img" ] && [ -f "out/arch/arm64/boot/dtb" ]; then
        if [ "${DEVICE}" = "alioth" ]; then
          git clone -q https://github.com/madmax7896/AnyKernel3.git -b alioth
        elif [ "${DEVICE}" = "apollo" ]; then
          git clone -q https://github.com/madmax7896/AnyKernel3.git -b apollo
        elif [ "${DEVICE}" = "lmi" ]; then
          git clone -q https://github.com/madmax7896/AnyKernel3.git -b lmi
        elif [ "${DEVICE}" = "munch" ]; then
          git clone -q https://github.com/madmax7896/AnyKernel3.git -b munch-uvite
        else
          git clone -q https://github.com/madmax7896/AnyKernel3.git -b psyche
	fi
	cp out/arch/arm64/boot/Image AnyKernel3
	cp out/arch/arm64/boot/dtb AnyKernel3
	cp out/arch/arm64/boot/dtbo.img AnyKernel3
	rm -f *zip
	cd AnyKernel3
	zip -r9 "../${zipname}" * -x '*.git*' README.md *placeholder >> /dev/null
	cd ..
	rm -rf AnyKernel3
	echo -e "\nCompleted in $((SECONDS / 60)) minute(s) and $((SECONDS % 60)) second(s) !"
	echo ""
	echo -e ${zipname} " is ready!"
	echo ""
        curl --upload-file ${zipname} https://transfer.sh/$zipname
        curl -T ${zipname} oshi.at # incase the 1st attempt fails
else
	echo -e "\n Compilation Failed!"
fi
