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
WHEELS_DEST="/io/wheelhouse"

def fix_pocl():
    wheel_fnames = glob(WHEELS_PATH)
    for fname in wheel_fnames:
        if not "pocl" in fname:
            continue
        print('Processing', fname)
        with wheeltools.InWheel(fname, fname):
            if not os.path.exists("pyopencl/.libs"):
                os.makedirs("pyopencl/.libs")
            if not os.path.exists("pocl_binary_distribution/.libs"):
                os.makedirs("pocl_binary_distribution/.libs")
            soname_map = {}
            # copy pocl, to this directory
            for lib in ["pocl"]:
                libpath = "/usr/local/lib/lib{}.so".format(lib)
                soname = check_output(['patchelf', '--print-soname', libpath]).decode().split()[0]
                new_soname, new_path = copylib(libpath, "pocl_binary_distribution/.libs")
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
            shutil.copy2("/usr/local/bin/lld", "pocl_binary_distribution/.libs/ld.lld")
            # copy licenses
            if not os.path.exists(POCL_LICENSES_DEST):
                os.makedirs(POCL_LICENSES_DEST)
            for lib_path in glob("/deps/licenses/pocl/*"):
                shutil.copy2(lib_path, POCL_LICENSES_DEST)
        check_call(["auditwheel", "repair", fname, "-w", "wheelhouse_repaired"])
        for fname in glob("wheelhouse_repaired/*.whl"):
            print('Processing', fname)
            with wheeltools.InWheel(fname, fname):
                for lib_path in glob("pocl_binary_distribution/.libs/libpocl*"):
                    check_call(['patchelf', '--force-rpath', '--set-rpath', "$ORIGIN/../../pocl_binary_distribution/.libs:$ORIGIN", lib_path])
                    shutil.move(lib_path, "pyopencl/.libs")
                shutil.move("pocl_binary_distribution/.libs/ld.lld", "pyopencl/.libs")
                check_call(['patchelf', '--force-rpath', '--set-rpath', "$ORIGIN/../../pocl_binary_distribution/.libs:$ORIGIN", "pyopencl/.libs/ld.lld"])
            shutil.move(fname, WHEELS_DEST)

def fix_oclgrind():
    wheel_fnames = glob(WHEELS_PATH)
    for fname in wheel_fnames:
        if not "oclgrind" in fname:
            continue
        print('Processing', fname)
        with wheeltools.InWheel(fname, fname):
            if not os.path.exists("pyopencl/.libs"):
                os.makedirs("pyopencl/.libs")
            if not os.path.exists("oclgrind_binary_distribution/.libs"):
                os.makedirs("oclgrind_binary_distribution/.libs")
            soname_map = {}
            # copy oclgrind, to this directory
            for lib in ["oclgrind", "oclgrind-rt-icd"]:
                libpath = "/usr/local/lib/lib{}.so".format(lib)
                soname = check_output(['patchelf', '--print-soname', libpath]).decode().split()[0]
                new_soname, new_path = copylib(libpath, "oclgrind_binary_distribution/.libs")
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
                shutil.copy2(pch_file, OCL_DATA_DEST)
            # copy licenses
            if not os.path.exists(OCLGRIND_LICENSES_DEST):
                os.makedirs(OCLGRIND_LICENSES_DEST)
            for lib_path in glob("/deps/licenses/oclgrind/*"):
                shutil.copy2(lib_path, OCLGRIND_LICENSES_DEST)
        check_call(["auditwheel", "repair", fname, "-w", "wheelhouse_repaired"])
        for fname in glob("wheelhouse_repaired/*.whl"):
            print('Processing', fname)
            with wheeltools.InWheel(fname, fname):
                for lib_path in glob("oclgrind_binary_distribution/.libs/liboclgrind*"):
                    check_call(['patchelf', '--force-rpath', '--set-rpath', "$ORIGIN/../../oclgrind_binary_distribution/.libs:$ORIGIN", lib_path])
                    shutil.move(lib_path, "pyopencl/.libs")
            shutil.move(fname, WHEELS_DEST)

def main():
    if os.path.exists(WHEELS_DEST):
        shutil.rmtree(WHEELS_DEST)
    os.makedirs(WHEELS_DEST)
    fix_pocl()
    fix_oclgrind()

if __name__ == '__main__':
    main()
