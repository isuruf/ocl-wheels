import sys
import os.path
import shutil
from glob import glob

from auditwheel import wheeltools
from auditwheel.repair import copylib
from subprocess import check_output, check_call

WHEELS_PATH='wheelhouse/*.whl'
POCL_DATA="/usr/local/share/pocl/"
CLANG_HEADER="/usr/local/lib/clang/6.0.1/include/opencl-c.h"
POCL_DATA_DEST="pyopencl/.libs/share/pocl"
POCL_LICENSES_DEST="pyopencl/.libs/share/pocl/licenses"
OCLGRIND_LICENSES_DEST="pyopencl/.libs/share/oclgrind/licenses"
OCL_DATA_DEST="pyopencl/.libs/include/oclgrind"

def fix_pocl():
    wheel_fnames = glob(WHEELS_PATH)
    for fname in wheel_fnames:
        if not fname.startswith("pocl"):
            continue
        print('Processing', fname)
        with wheeltools.InWheel(fname, fname):
            if not os.path.exists("pyopencl/.libs"):
                os.makedirs("pyopencl/.libs")
            soname_map = {}
            # copy pocl, to this directory
            for lib in ["pocl"]:
                libpath = "/usr/local/lib/lib{}.so".format(lib)
                soname = check_output(['patchelf', '--print-soname', libpath]).decode().split()[0]
                new_soname, new_path = copylib(libpath, "pyopencl/.libs")
                soname_map[lib] = (soname, new_soname, new_path)
            # set rpath of pocl
            check_call(['patchelf', '--force-rpath', '--set-rpath', "$ORIGIN", soname_map["pocl"][2]])
            # Add an icd file
            with open("pyopencl/.libs/pocl.icd", "w") as f:
                f.write(soname_map["pocl"][1])
            # Copy headers and bytecode files needed by pocl
            if not os.path.exists("pyopencl/.libs/share"):
                os.makedirs("pyopencl/.libs/share")
            if os.path.exists(POCL_DATA_DEST):
                shutil.rmtree(POCL_DATA_DEST)
            shutil.copytree(POCL_DATA, POCL_DATA_DEST)
            shutil.copy2(CLANG_HEADER, POCL_DATA_DEST)
            # copy the linker
            shutil.copy2("/usr/local/bin/lld", "pyopencl/.libs/ld.lld")
            # copy licenses
            if not os.path.exists(POCL_LICENSES_DEST):
                os.makedirs(POCL_LICENSES_DEST)
            for lib_path in glob("/deps/licenses/pocl/*"):
                shutil.copy2(lib_path, POCL_LICENSES_DEST)

def fix_oclgrind():
    wheel_fnames = glob(WHEELS_PATH)
    for fname in wheel_fnames:
        if not fname.startswith("oclgrind"):
            continue
        print('Processing', fname)
        with wheeltools.InWheel(fname, fname):
            if not os.path.exists("pyopencl/.libs"):
                os.makedirs("pyopencl/.libs")
            soname_map = {}
            # copy oclgrind, to this directory
            for lib in ["oclgrind", "oclgrind-rt-icd"]:
                libpath = "/usr/local/lib/lib{}.so".format(lib)
                soname = check_output(['patchelf', '--print-soname', libpath]).decode().split()[0]
                new_soname, new_path = copylib(libpath, "pyopencl/.libs")
                soname_map[lib] = (soname, new_soname, new_path)
            # set rpath of oclgrind
            check_call(['patchelf', '--force-rpath', '--set-rpath', "$ORIGIN", soname_map["oclgrind-rt-icd"][2]])
            # Add an icd file
            with open("pyopencl/.libs/oclgrind.icd", "w") as f:
                f.write(soname_map["oclgrind-rt-icd"][1])
            # Copy headers needed by oclgrind
            if not os.path.exists(OCL_DATA_DEST):
                os.makedirs(OCL_DATA_DEST)
            for pch_file in glob("/usr/local/include/oclgrind/*.pch"):
                shutil.copy2(lib_path, OCL_DATA_DEST)
            # copy licenses
            if not os.path.exists(OCLGRIND_LICENSES_DEST):
                os.makedirs(OCLGRIND_LICENSES_DEST)
            for lib_path in glob("/deps/licenses/oclgrind/*"):
                shutil.copy2(lib_path, OCLGRIND_LICENSES_DEST)

def main():
    fix_pocl()
    fix_oclgrind()

if __name__ == '__main__':
    main()
