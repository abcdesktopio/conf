#!/bin/sh

#
# This file is from Istio https://raw.githubusercontent.com/istio/istio/master/release/downloadIstioCandidate.sh
# Copyright Istio Authors
#
# Change for abcdesktopio
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
# This file will be fetched as: curl -L https://git.io/getLatestIstio | sh -
# so it should be pure bourne shell, not bash (and not reference other scripts)
#
# The script fetches the latest Istio release candidate and untars it.
# You can pass variables on the command line to download a specific version
# or to override the processor architecture. For example, to download
# Istio 1.6.8 for the x86_64 architecture,
# run curl -L https://istio.io/downloadIstio | ISTIO_VERSION=1.6.8 TARGET_ARCH=x86_64 sh -.


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
    OIO_ARCH=amd64
    ;;
  armv8*)
    OIO_ARCH=arm64
    ;;
  aarch64*)
    OIO_ARCH=arm64
    ;;
  armv*)
    OIO_ARCH=armv7
    ;;
  amd64|arm64)
    OIO_ARCH=${LOCAL_ARCH}
    ;;
  *)
    echo "This system's architecture, ${LOCAL_ARCH}, isn't supported"
    exit 1
    ;;
esac

echo "This system's architecture is ${OIO_ARCH}"

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


# Check if wget command is supported
# run command  version
WGET_VERSION=$(wget --version)
EXIT_CODE=$?
if [ $EXIT_CODE -eq 0 ]
then
        echo "'wget --version' command was successful"
else
        echo "'wget --version' failed"
        echo "Please install wget command first"
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


wget https://raw.githubusercontent.com/abcdesktopio/conf/main/reference/docker-compose.yml
docker-composer up

