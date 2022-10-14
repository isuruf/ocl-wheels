export DOCKER_IMAGE=${DOCKER_IMAGE:-quay.io/pypa/manylinux2014_x86_64}
echo $DOCKER_IMAGE
docker run -v `pwd`:/io $DOCKER_IMAGE /io/scripts/build-wheels.sh
