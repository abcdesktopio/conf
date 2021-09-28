#!/bin/sh
#
#
# Install script kubernetes for abcdesktopio
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
# This file will be fetched as: curl -L https://raw.githubusercontent.com/abcdesktopio/conf/main/kubernetes/install.sh | sh -
# so it should be pure bourne shell
#
# run curl -L https://raw.githubusercontent.com/abcdesktopio/conf/main/kubernetes/install.sh | sh -
#

# define ABCDESKTOP_YAML path
ABCDESKTOP_YAML=https://raw.githubusercontent.com/abcdesktopio/conf/main/kubernetes/abcdesktop.yaml 


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


# Check if kubectl command is supported
# run command kubectl version
KUBE_VERSION=$(kubectl version)
EXIT_CODE=$?
if [ $EXIT_CODE -eq 0 ] 
then 
	echo "'kubectl version' command was successful"
else
	echo "'kubectl version' failed"
	echo "Please install kubectl command first"
	exit $?
fi

# Check if kubectl command is supported
# run command kubectl version
OPENSSL_VERSION=$(openssl version)
EXIT_CODE=$?
if [ $EXIT_CODE -eq 0 ] 
then
        echo "'openssl version' command was successful"
else
        echo "'openssl version' failed"
        echo "Please install openssl command first"
        exit $?
fi

# First create the abcdesktop namespace
kubectl create namespace abcdesktop
EXIT_CODE=$?
if [ $EXIT_CODE -eq 0 ] 
then
        echo "'kubectl create namespace abcdesktop' command was successful"
fi


# RSA keys
# build rsa kay pairs for jwt payload 
# 1024 bits is a smallest value, change here if need but use more than 1024
if [ ! -f abcdesktop_jwt_desktop_payload_private_key.pem ]
then
	openssl genrsa -out abcdesktop_jwt_desktop_payload_private_key.pem 1024
	openssl rsa    -in  abcdesktop_jwt_desktop_payload_private_key.pem -outform PEM -pubout -out  _abcdesktop_jwt_desktop_payload_public_key.pem
	openssl rsa    -pubin -in _abcdesktop_jwt_desktop_payload_public_key.pem -RSAPublicKey_out -out abcdesktop_jwt_desktop_payload_public_key.pem
fi

# build rsa kay pairs for the desktop jwt signing
if [ ! -f abcdesktop_jwt_desktop_signing_private_key.pem ]
then
	openssl genrsa -out abcdesktop_jwt_desktop_signing_private_key.pem 1024
	openssl rsa    -in  abcdesktop_jwt_desktop_signing_private_key.pem -outform PEM -pubout -out abcdesktop_jwt_desktop_signing_public_key.pem
fi

# build rsa kay pairs for the user jwt signing 
if [ ! -f abcdesktop_jwt_user_signing_private_key.pem ]
then
	openssl genrsa -out abcdesktop_jwt_user_signing_private_key.pem 1024
	openssl rsa    -in  abcdesktop_jwt_user_signing_private_key.pem -outform PEM -pubout -out abcdesktop_jwt_user_signing_public_key.pem
fi

# Import RSA Keys as Kubernetes secrets 
kubectl create secret generic abcdesktopjwtdesktoppayload --from-file=abcdesktop_jwt_desktop_payload_private_key.pem --from-file=abcdesktop_jwt_desktop_payload_public_key.pem --namespace=abcdesktop
kubectl create secret generic abcdesktopjwtdesktopsigning --from-file=abcdesktop_jwt_desktop_signing_private_key.pem --from-file=abcdesktop_jwt_desktop_signing_public_key.pem --namespace=abcdesktop
kubectl create secret generic abcdesktopjwtusersigning    --from-file=abcdesktop_jwt_user_signing_private_key.pem    --from-file=abcdesktop_jwt_user_signing_public_key.pem    --namespace=abcdesktop


echo "####################################################################"
echo "#"
echo "# This script is pulling container images from docker registry"
echo "# It's a good time for a coffee break..."
echo "#"
echo "####################################################################"



# check if TAG env is set
if [ -z ${TAG} ]; then
        echo "pulling tagged image not set, use default latest"
        TAG=latest
else
        echo "pulling tagged image ${TAG}"
fi

# docker pull image core images
REGISTRY_DOCKERHUB="abcdesktopio"
docker pull $REGISTRY_DOCKERHUB/oc.user.18.04:${TAG}
docker pull $REGISTRY_DOCKERHUB/oc.cupsd.18.04:${TAG}
docker pull $REGISTRY_DOCKERHUB/oc.pulseaudio.18.04:${TAG}

if [ -z ${NOPULLAPPS} ]; then
	# docker pull sample applications images
	docker pull $REGISTRY_DOCKERHUB/writer.d:${TAG}
	docker pull $REGISTRY_DOCKERHUB/calc.d:${TAG}
	docker pull $REGISTRY_DOCKERHUB/impress.d:${TAG}
	docker pull $REGISTRY_DOCKERHUB/firefox.d:${TAG}
	docker pull $REGISTRY_DOCKERHUB/gimp.d:${TAG}
else
	echo "do not pull images option detected"
	echo "skipping image $REGISTRY_DOCKERHUB/writer.d:${TAG}"
	echo "skipping image $REGISTRY_DOCKERHUB/calc.d:${TAG}"
	echo "skipping image $REGISTRY_DOCKERHUB/impress.d:${TAG}"
	echo "skipping image $REGISTRY_DOCKERHUB/firefox.d:${TAG}"
	echo "skipping image $REGISTRY_DOCKERHUB/gimp.d:${TAG}"
fi

if [ "$TAG" = "dev" ]; then
	ABCDESKTOP_YAML=https://raw.githubusercontent.com/abcdesktopio/conf/main/kubernetes/abcdesktop-dev.yaml 
fi

# create abcdesktop
if [ -f abcdesktop.yaml ]; then
   echo "kubernetes use local directory abcdesktop.yaml file"
   ABCDESKTOP_YAML=abcdesktop.yaml
fi

kubectl create -f $ABCDESKTOP_YAML

EXIT_CODE=$?
if [ $EXIT_CODE -eq 0 ] 
then
        echo "kubectl create -f $ABCDESKTOP_YAML command was successful"
else
        echo "kubectl create -f $ABCDESKTOP_YAML failed"
        exit $?
fi

deployments=$(kubectl -n abcdesktop get deployment --template '{{range .items}}{{.metadata.name}}{{"\n"}}{{end}}')
for d in $deployments;  
do 
	echo "waiting for deployment/$d available"; 
	kubectl -n abcdesktop wait deployment/$d --for=condition=available --timeout=-1s; 
done

pods=$(kubectl -n abcdesktop get pods --template '{{range .items}}{{.metadata.name}}{{"\n"}}{{end}}')
for p in $pods; 
do
	echo "waiting for pod/$p Ready"
	kubectl -n abcdesktop wait pod/$p --for=condition=Ready --timeout=-1s
done

# list all pods 
kubectl get pods --namespace=abcdesktop

echo "Setup done"
echo "Open your navigator to http://[your-ip-hostname]:30443/"
echo "For example http://localhost:30443"
