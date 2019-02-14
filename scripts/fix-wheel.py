import sys
import os.path
import shutil
from glob import glob

from auditwheel import wheeltools
from auditwheel.repair import copylib
from subprocess import check_output, check_call

LICENSES_PATH="/deps/licenses/*"
WHEELS_PATH='wheelhouse/*.whl'

def add_library():
    wheel_fnames = glob(WHEELS_PATH)
    for fname in wheel_fnames:
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
            # copy licenses
            for lib_path in glob(LICENSES_PATH):
                shutil.copy2(lib_path, os.path.join('pyopencl', '.libs'))

def main():
    add_library()

if __name__ == '__main__':
    main()
