CLANG=/workspace/tc/sdclang/bin
GCC32=/workspace/tc/gcc/gcc/bin
GCC64=/workspace/tc/gcc/gcc64/bin

PATH=$CLANG:$GCC64:$GCC32:$PATH

export PATH
export ARCH=arm64

export CLANG_TRIPLE
export CROSS_COMPILE
export CROSS_COMPILE_ARM32

sudo apt update && sudo apt upgrade
sudo apt install -y cpio \
                    flex \
                    python-is-python3 \
                    libncurses5 \
                    libncurses5-dev \
                    ccache \
                    gcc-aarch64-linux-gnu \
                    bc

export KBUILD_BUILD_USER=forest
export KBUILD_BUILD_HOST=Disconnect0
export KBUILD_BUILD_VERSION="1"

CLANG_TRIPLE="aarch64-linux-gnu-"
CROSS_COMPILE="aarch64-linux-gnu-"
CROSS_COMPILE_ARM32="arm-linux-gnueabi-"

output_dir=out
make O="$output_dir" \
            alioth_defconfig

make -j $(nproc) \
            O="$output_dir" \
            CC="ccache clang" \
            HOSTCC=gcc \
            LD=ld.lld \
            AS=llvm-as \
            AR=llvm-ar \
            NM=llvm-nm \
            OBJCOPY=llvm-objcopy \
            OBJDUMP=llvm-objdump \
            STRIP=llvm-strip \
            LLVM=1 \
            LLVM_IAS=1 \
            Image.gz-dtb \
            dtbo.img
