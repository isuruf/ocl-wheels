#!/bin/bash
set -e -x

mkdir -p /deps
cd /deps
mkdir -p licenses/pocl
mkdir -p licenses/oclgrind

yum install -y git yum xz ruby

# OCL ICD loader
git clone --branch v2.3.1 https://github.com/OCL-dev/ocl-icd
pushd ocl-icd
autoreconf -i
chmod +x configure
./configure --prefix=/usr
make -j16
make install
# this is in pyopencl
# cp COPYING /deps/licenses/OCL_ICD.COPYING
popd

# libhwloc for pocl
curl -L -O https://download.open-mpi.org/release/hwloc/v2.0/hwloc-2.0.3.tar.gz
tar -xf hwloc-2.0.3.tar.gz
pushd hwloc-2.0.3
./configure --disable-cairo --disable-opencl --disable-cuda --disable-nvml  --disable-gl --disable-libudev --disable-libxml2
make -j16
make install
cp COPYING /deps/licenses/pocl/HWLOC.COPYING
popd

PYTHON_PREFIX=/opt/python/cp310-cp310
PYTHON_VER=3.10

# newer cmake for LLVM
$PYTHON_PREFIX/bin/pip install "cmake==3.24.1.1"
export PATH="$PYTHON_PREFIX/lib/$PYTHON_VER/site-packages/cmake/data/bin/:${PATH}"

LLVM_VERSION=7.0.1
# LLVM for pocl
curl -L -O http://releases.llvm.org/${LLVM_VERSION}/llvm-${LLVM_VERSION}.src.tar.xz
unxz llvm-${LLVM_VERSION}.src.tar.xz
tar -xf llvm-${LLVM_VERSION}.src.tar
pushd llvm-${LLVM_VERSION}.src
mkdir -p build
pushd build
cmake -DPYTHON_EXECUTABLE=$PYTHON_PREFIX/bin/python \
      -DCMAKE_INSTALL_PREFIX=/usr/local \
      -DLLVM_TARGETS_TO_BUILD=host \
      -DCMAKE_BUILD_TYPE=Release \
      -DLLVM_ENABLE_RTTI=ON \
      -DLLVM_INCLUDE_TESTS=OFF \
      -DLLVM_INCLUDE_GO_TESTS=OFF \
      -DLLVM_INCLUDE_UTILS=ON \
      -DLLVM_INCLUDE_DOCS=OFF \
      -DLLVM_INCLUDE_EXAMPLES=OFF \
      -DLLVM_ENABLE_TERMINFO=OFF \
      -DLLVM_ENABLE_LIBXML2=OFF \
      -DLLVM_ENABLE_ZLIB=OFF \
      ..

make -j16
make install
popd
cp LICENSE.TXT /deps/licenses/pocl/LLVM_LICENSE.txt
cp LICENSE.TXT /deps/licenses/oclgrind/LLVM_LICENSE.txt
popd

# clang for pocl
curl -L -O http://releases.llvm.org/${LLVM_VERSION}/cfe-${LLVM_VERSION}.src.tar.xz
unxz cfe-${LLVM_VERSION}.src.tar.xz
tar -xf cfe-${LLVM_VERSION}.src.tar
pushd cfe-${LLVM_VERSION}.src
mkdir -p build
pushd build
cmake \
  -DCMAKE_INSTALL_PREFIX=/usr/local \
  -DCMAKE_PREFIX_PATH=/usr/local \
  -DCMAKE_BUILD_TYPE=Release \
  -DLLVM_ENABLE_RTTI=ON \
  -DCLANG_INCLUDE_TESTS=OFF \
  -DCLANG_INCLUDE_DOCS=OFF \
  -DLLVM_INCLUDE_TESTS=OFF \
  -DLLVM_INCLUDE_DOCS=OFF \
  -DLLVM_ENABLE_LIBXML2=OFF \
  -DLLVM_ENABLE_ZLIB=OFF \
  ..
make -j16
make install
popd
cp LICENSE.TXT /deps/licenses/pocl/clang_LICENSE.txt
cp LICENSE.TXT /deps/licenses/oclgrind/clang_LICENSE.txt
popd

# lld for pocl
curl -L -O http://releases.llvm.org/${LLVM_VERSION}/lld-${LLVM_VERSION}.src.tar.xz
unxz lld-${LLVM_VERSION}.src.tar.xz
tar -xf lld-${LLVM_VERSION}.src.tar
pushd lld-${LLVM_VERSION}.src
mkdir -p build
pushd build
cmake \
  -DCMAKE_INSTALL_PREFIX=/usr/local \
  -DCMAKE_PREFIX_PATH=/usr/local \
  -DCMAKE_BUILD_TYPE=Release \
..
make -j16
make install
popd
cp LICENSE.TXT /deps/licenses/pocl/lld_LICENSE.txt
popd

git clone --branch v3.0 https://github.com/pocl/pocl
pushd pocl
sed -i.bak 's/"-lm",//g' lib/CL/devices/common.c
sed -i.bak 's/-dynamiclib -w -lm/-dynamiclib -w/g' CMakeLists.txt
git apply /io/patches/pocl-gh708.patch
sed -i 's/add_subdirectory("matrix1")//g' examples/CMakeLists.txt
mkdir -p build
pushd build

export EXTRA_HOST_LD_FLAGS="$EXTRA_HOST_LD_FLAGS -nodefaultlibs"

LDFLAGS="-Wl,--exclude-libs,ALL" CFLAGS="-g" cmake \
    -DCMAKE_BUILD_TYPE=Release \
    -DINSTALL_OPENCL_HEADERS="off" \
    -DKERNELLIB_HOST_CPU_VARIANTS=distro \
    -DENABLE_ICD=on \
    -DCMAKE_INSTALL_LIBDIR=lib \
    -DCMAKE_INSTALL_PREFIX="/usr/local" \
    -DENABLE_LOADABLE_DRIVERS=no \
    -DPOCL_INSTALL_ICD_VENDORDIR=/etc/OpenCL/vendors \
    -DPOCL_INSTALL_PRIVATE_DATADIR=/usr/pocl_binary_distribution/.libs/share/pocl \
    ..

make -j16
make install
popd
cp COPYING /deps/licenses/pocl/POCL.COPYING
popd

git clone --branch v21.10 https://github.com/jrprice/Oclgrind
pushd Oclgrind
git apply /io/patches/oclgrind-21.10-paths.diff
mkdir build
pushd build
cmake .. -DCMAKE_BUILD_TYPE=Release -DLIBDIR_SUFFIX="" -DCMAKE_INSTALL_PREFIX=/usr/local
make -j16
make install
popd
cp LICENSE /deps/licenses/oclgrind/OCLGRIND_LICENSE.txt
popd

# Compile wheels
PYBIN="$PYTHON_PREFIX/bin"
"${PYBIN}/pip" wheel /io/pocl -w wheelhouse/ --no-deps
"${PYBIN}/pip" wheel /io/oclgrind -w wheelhouse/ --no-deps

# Bundle shared libraries
"${PYBIN}/python" -m pip install auditwheel
"${PYBIN}/python" /io/scripts/fix-wheel.py
