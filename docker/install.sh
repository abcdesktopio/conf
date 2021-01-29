#!/bin/sh

#
#
# Install docker (non-cluster) for abcdesktopio
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#    http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

#
# This file will be fetched as: curl -L https://raw.githubusercontent.com/abcdesktopio/conf/main/docker/install.sh | sh -
# so it should be pure bourne shell
#
# run curl -L https://raw.githubusercontent.com/abcdesktopio/conf/main/docker/install.sh | sh -
#


# Determines the operating system.
OS="$(uname)"
if [ "x${OS}" = "xDarwin" ] ; then
  OSEXT="osx"
else
  OSEXT="linux"
fi

LOCAL_ARCH=$(uname -m)
if [ "${TARGET_ARCH}" ]; then
    LOCAL_ARCH=${TARGET_ARCH}
fi

case "${LOCAL_ARCH}" in 
  x86_64)
    ABCDESKTOPIO_ARCH=amd64
    ;;
  # armv8*)
  #  ABCDESKTOPIO_ARCH=arm64
  #  ;;
  # aarch64*)
  #  ABCDESKTOPIO_ARCH=arm64
  #  ;;
  # armv*)
  #  ABCDESKTOPIO_ARCH=armv7
  #  ;;
  amd64|arm64)
    ABCDESKTOPIO_ARCH=${LOCAL_ARCH}
    ;;
  *)
    echo "This system's architecture, ${LOCAL_ARCH}, isn't supported"
    exit 1
    ;;
esac

echo "This system's architecture is ${ABCDESKTOPIO_ARCH}"

# Check if docker command is supported
# run command docker --version
DOCKER_VERSION=$(docker --version)
EXIT_CODE=$?
if [ $EXIT_CODE -eq 0 ] 
then 
	echo "'docker --version' command was successful"
else
	echo "'docker --version' failed"
	echo "Please install docker command first"
	exit $?
fi

# Check if docker-compose command is supported
# run command docker-compose --version
COMPOSE_VERSION=$(docker-compose --version)
EXIT_CODE=$?
if [ $EXIT_CODE -eq 0 ] 
then
        echo "'docker-compose --version' command was successful"
else
        echo "'docker-compose --version' failed"
        echo "Please install docker-compose command first"
        exit $?
fi


# Check if CURL command is supported
# run command  version
CURL_VERSION=$(curl --version)
EXIT_CODE=$?
if [ $EXIT_CODE -eq 0 ]
then
        echo "'curl --version' command was successful"
else
        echo "'curl --version' failed"
        echo "Please install curl command first"
        exit $?
fi

# docker pull image core images
REGISTRY_DOCKERHUB="abcdesktopio"
docker pull $REGISTRY_DOCKERHUB/oc.user.18.04

# docker pull applications
docker pull $REGISTRY_DOCKERHUB/writer.d
docker pull $REGISTRY_DOCKERHUB/calc.d
docker pull $REGISTRY_DOCKERHUB/impress.d
docker pull $REGISTRY_DOCKERHUB/firefox-esr.d
docker pull $REGISTRY_DOCKERHUB/gimp.d


curl -o docker-compose.yml  https://raw.githubusercontent.com/abcdesktopio/conf/main/reference/docker-compose.yml

echo "Starting abcdesktop services"
echo "running 'docker-compose -p abcdesktop up'"
docker-compose -p abcdesktop up


