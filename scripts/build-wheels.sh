#!/bin/bash
set -e -x

mkdir -p /deps
cd /deps
mkdir -p licenses/pocl
mkdir -p licenses/oclgrind

yum install -y git yum libxml2-devel xz

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
./configure --disable-cairo --disable-opencl --disable-cuda --disable-nvml  --disable-gl --disable-libudev
make -j16
make install
cp COPYING /deps/licenses/pocl/HWLOC.COPYING
cp /usr/share/doc/libxml2-devel-*/Copyright /deps/licenses/pocl/libxml2.COPYING
popd

# newer cmake for LLVM
/opt/python/cp37-cp37m/bin/pip install cmake
export PATH="/opt/python/cp37-cp37m/lib/python3.7/site-packages/cmake/data/bin/:${PATH}"

# LLVM for pocl
curl -L -O http://releases.llvm.org/6.0.1/llvm-6.0.1.src.tar.xz
unxz llvm-6.0.1.src.tar.xz
tar -xf llvm-6.0.1.src.tar
pushd llvm-6.0.1.src
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
      ..

make -j16
make install
popd
cp LICENSE.TXT /deps/licenses/pocl/LLVM_LICENSE.txt
cp LICENSE.TXT /deps/licenses/oclgrind/LLVM_LICENSE.txt
popd

# clang for pocl
curl -L -O http://releases.llvm.org/6.0.1/cfe-6.0.1.src.tar.xz
unxz cfe-6.0.1.src.tar.xz
tar -xf cfe-6.0.1.src.tar
pushd cfe-6.0.1.src
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
..
make -j16
make install
popd
cp LICENSE.TXT /deps/licenses/pocl/clang_LICENSE.txt
cp LICENSE.TXT /deps/licenses/oclgrind/clang_LICENSE.txt
popd

# lld for pocl
curl -L -O http://releases.llvm.org/6.0.1/lld-6.0.1.src.tar.xz
unxz lld-6.0.1.src.tar.xz
tar -xf lld-6.0.1.src.tar
pushd lld-6.0.1.src
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

git clone --branch v1.2 https://github.com/pocl/pocl
pushd pocl
git apply /io/patches/pocl-1.2-paths.patch
sed -i 's/add_subdirectory("example2")//g' examples/CMakeLists.txt
sed -i 's/add_subdirectory("example2a")//g' examples/CMakeLists.txt
mkdir -p build
pushd build

EXTRA_FLAGS="-D_BSD_SOURCE -D_ISOC99_SOURCE -D'htole32(x)=(x)' -D'htole64(x)=(x)' -D'htole16(x)=(x)' -D'le16toh(x)=(x)' -D'le32toh(x)=(x)' -D'le64toh(x)=(x)'"

LDFLAGS="-Wl,--exclude-libs,ALL" cmake -DCMAKE_C_FLAGS="$EXTRA_FLAGS" \
    -DCMAKE_BUILD_TYPE=Release \
    -DCMAKE_CXX_FLAGS="$EXTRA_FLAGS" \
    -DINSTALL_OPENCL_HEADERS="off" \
    -DKERNELLIB_HOST_CPU_VARIANTS=distro \
    -DENABLE_ICD=on \
    -DCMAKE_INSTALL_LIBDIR=lib \
    -DCMAKE_INSTALL_PREFIX=/usr/local \
    -DPOCL_INSTALL_ICD_VENDORDIR=/etc/OpenCL/vendors \
    ..

make -j16
make install
popd
cp COPYING /deps/licenses/pocl/POCL.COPYING
popd

git clone --branch v18.3 https://github.com/jrprice/Oclgrind
pushd Oclgrind
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

# Bundle license files and pocl
/opt/_internal/cpython-3.6.*/bin/python /io/scripts/fix-wheel.py

# Repair for pocl dependencies
for whl in wheelhouse/*.whl; do
    auditwheel repair "$whl" -w /io/wheelhouse/
done
