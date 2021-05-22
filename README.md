# ocl-wheels
OpenCL binary distributions for python/pyopencl

PyOpenCL builds an OpenCL ICD loader
[here](https://github.com/inducer/pyopencl/blob/main/scripts/build-wheels.sh)
for its manylinux binary wheels. This loader will see ICDs from the system
installed at `/etc/OpenCL/vendors` and also at a special directory
`<site-packages>/pyopencl/.libs`. While a user can install pocl or oclgrind
to `/etc/OpenCL/vendors`, but that requires root permissions which is not ideal.

The special directory `<site-packages>/pyopencl/.libs` is used by the two
packages `pocl-binary-distribution` and `oclgrind-binary-distribution` PyPI
packages to install binaries of `pocl` and `oclgrind` there.

To build the wheels, run

   scripts/run_docker_build.sh

To update the version of pocl, there are several places to update

   1. version number [here](pocl/pocl_binary_distribution/__init__.py),
      and [here](pocl/setup.py)
   2. pocl source version [here](scripts/build-wheels.sh)

Similar for oclgrind
