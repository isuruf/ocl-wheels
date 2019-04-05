#!/bin/bash
set -e -x

mkdir -p /deps
cd /deps
mkdir -p licenses/pocl
mkdir -p licenses/oclgrind

yum install -y git yum xz

# Need ruby for ocl-icd
curl -L -O http://cache.ruby-lang.org/pub/ruby/2.1/ruby-2.1.2.tar.gz
tar -xf ruby-2.1.2.tar.gz
pushd ruby-2.1.2
./configure
make -j16
make install
popd

# OCL ICD loader
git clone --branch v2.2.12 https://github.com/OCL-dev/ocl-icd
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

# newer cmake for LLVM
/opt/python/cp37-cp37m/bin/pip install cmake
export PATH="/opt/python/cp37-cp37m/lib/python3.7/site-packages/cmake/data/bin/:${PATH}"

LLVM_VERSION=7.0.1
# LLVM for pocl
curl -L -O http://releases.llvm.org/${LLVM_VERSION}/llvm-${LLVM_VERSION}.src.tar.xz
unxz llvm-${LLVM_VERSION}.src.tar.xz
tar -xf llvm-${LLVM_VERSION}.src.tar
pushd llvm-${LLVM_VERSION}.src
mkdir -p build
pushd build
cmake -DPYTHON_EXECUTABLE=/opt/python/cp37-cp37m/bin/python \
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

git clone --branch v1.3 https://github.com/pocl/pocl
pushd pocl
git apply /io/patches/pocl-gh708.patch
sed -i 's/add_subdirectory("matrix1")//g' examples/CMakeLists.txt
mkdir -p build
pushd build

LDFLAGS="-Wl,--exclude-libs,ALL" cmake \
    -DCMAKE_BUILD_TYPE=Release \
    -DINSTALL_OPENCL_HEADERS="off" \
    -DKERNELLIB_HOST_CPU_VARIANTS=distro \
    -DENABLE_ICD=on \
    -DCMAKE_INSTALL_LIBDIR=lib \
    -DCMAKE_INSTALL_PREFIX=/usr/local \
    -DPOCL_INSTALL_ICD_VENDORDIR=/etc/OpenCL/vendors \
    -DENABLE_POCL_RELOCATION=yes \
    -DPOCL_INSTALL_PRIVATE_DATADIR=/usr/pocl_binary_distribution/.libs/share/pocl \
    ..

make -j16
make install
popd
cp COPYING /deps/licenses/pocl/POCL.COPYING
popd

git clone --branch v18.3 https://github.com/jrprice/Oclgrind
pushd Oclgrind
git cherry-pick fa307108de205e76fffbcd8424f3811187cb121d --no-commit
git cherry-pick 3bc49030703f5dc943a9ceaa01cebe1edb96df11 --no-commit
git apply /io/patches/oclgrind-18.3-paths.diff
mkdir build
pushd build
cmake .. -DCMAKE_BUILD_TYPE=Release -DLIBDIR_SUFFIX="" -DCMAKE_INSTALL_PREFIX=/usr/local
make -j16
make install
popd
cp LICENSE /deps/licenses/oclgrind/OCLGRIND_LICENSE.txt
popd

# Compile wheels
PYBIN="/opt/python/cp37-cp37m/bin"
"${PYBIN}/pip" wheel /io/pocl -w wheelhouse/ --no-deps
"${PYBIN}/pip" wheel /io/oclgrind -w wheelhouse/ --no-deps

# Bundle shared libraries
/opt/_internal/cpython-3.6.*/bin/python /io/scripts/fix-wheel.py

