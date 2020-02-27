#!/usr/bin/env python

from setuptools import find_packages, setup
from distutils.core import setup

setup(name='oclgrind_binary_distribution',
      version='18.3.post2',
      description='Oclgrind Binary Distribution to be used with PyOpenCL',
      author='Isuru Fernando',
      author_email='isuruf@gmail.com',
      url='https://github.com/isuruf/pocl-binary-distribution',
      packages=find_packages(),
     )
