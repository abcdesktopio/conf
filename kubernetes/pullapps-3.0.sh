#!/bin/bash
#
#
# pull images script kubernetes for abcdesktopio
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
# This file will be fetched as: curl -L https://raw.githubusercontent.com/abcdesktopio/conf/main/kubernetes/pullimages.sh | sh -
# so it should be pure bourne shell
#
# run curl -L https://raw.githubusercontent.com/abcdesktopio/conf/main/kubernetes/pullimages.sh | sh -
#

# define ABCDESKTOP_YAML path
ABCDESKTOP_YAML=abcdesktop.yaml 

# current release
ABCDESKTOP_RELEASE=3.0

# docker hub prefix
REGISTRY_DOCKERHUB="docker.io/abcdesktopio"

# list of default applications to prefetch
# and
# list of template application to download quickly
# ABCDESKTOP_APPLICATIONS="
# $REGISTRY_DOCKERHUB/oc.template:$ABCDESKTOP_RELEASE
# $REGISTRY_DOCKERHUB/oc.template.gtk:$ABCDESKTOP_RELEASE
# $REGISTRY_DOCKERHUB/2048.d:$ABCDESKTOP_RELEASE 
# $REGISTRY_DOCKERHUB/xterm.d:$ABCDESKTOP_RELEASE
# $REGISTRY_DOCKERHUB/writer.d:$ABCDESKTOP_RELEASE 
# $REGISTRY_DOCKERHUB/calc.d:$ABCDESKTOP_RELEASE 
# $REGISTRY_DOCKERHUB/impress.d:$ABCDESKTOP_RELEASE 
# $REGISTRY_DOCKERHUB/firefox.d:$ABCDESKTOP_RELEASE 
# $REGISTRY_DOCKERHUB/gimp.d:$ABCDESKTOP_RELEASE"

URL_APPLICATION_CONF_SOURCE="https://raw.githubusercontent.com/abcdesktopio/oc.apps/main"
# list of json default applications to prefetch
ABCDESKTOP_JSON_APPLICATIONS="
2048-alpine.d.$ABCDESKTOP_RELEASE.json
xterm.d.$ABCDESKTOP_RELEASE.json
writer.d.$ABCDESKTOP_RELEASE.json
firefox.d.$ABCDESKTOP_RELEASE.json
gimp.d.$ABCDESKTOP_RELEASE.json
nautilus.d.$ABCDESKTOP_RELEASE.json
geany.d.$ABCDESKTOP_RELEASE.json
"


# list of pod container image to prefetch
ABCDESKTOP_POD_IMAGES="
$REGISTRY_DOCKERHUB/oc.user.kubernetes.18.04:$ABCDESKTOP_RELEASE 
$REGISTRY_DOCKERHUB/oc.pulseaudio.18.04:$ABCDESKTOP_RELEASE 
$REGISTRY_DOCKERHUB/oc.cupsd.18.04:$ABCDESKTOP_RELEASE 
docker.io/library/busybox:latest
k8s.gcr.io/pause:3.8"

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
    ABCDESKTOP_ARCH=amd64
    ;;
  # armv8*)
  #  ABCDESKTOP_ARCH=arm64
  #  ;;
  # aarch64*)
  #  ABCDESKTOP_ARCH=arm64
  #  ;;
  # armv*)
  #  ABCDESKTOP_ARCH=armv7
  #  ;;
  amd64|arm64)
    ABCDESKTOP_ARCH=${LOCAL_ARCH}
    ;;
  *)
    echo "This system's architecture, ${LOCAL_ARCH}, isn't supported"
    exit 1
    ;;
esac

echo "This system's architecture is ${ABCDESKTOP_ARCH}"


# Check if kubectl command is supported
# run command kubectl version
KUBE_VERSION=$(kubectl version --output=yaml)
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


# pull images if ctr exist
# ctr pull image core images
# if which ctr >/dev/null; then
#	echo "pulling applications"
#        echo $ABCDESKTOP_APPLICATIONS
#	if [ -z ${NOPULLAPPS} ]; then
#		for value in $ABCDESKTOP_APPLICATIONS
#		do
#			ctr -n k8s.io images pull $value
#		done
#	fi
# else
#	echo 'ctr command line not found, skipping prefetch images'
# fi

echo "checking for applications"
PYOS_CLUSTERIP=$(kubectl get service pyos -n abcdesktop -o jsonpath='{.spec.clusterIP}')
echo "PYOS_CLUSTERIP=$PYOS_CLUSTERIP"

# define service URL
PYOS_MANAGEMENT_SERVICE_URL="http://$PYOS_CLUSTERIP:8000/API/manager/image"
PYOS_HEALTZ_SERVICE_URL="http://$PYOS_CLUSTERIP:8000/healtz"

# call HEALTZ
echo "query to curl $PYOS_HEALTZ_SERVICE_URL"
curl $PYOS_HEALTZ_SERVICE_URL
EXIT_CODE=$?
if [ $EXIT_CODE -eq 0 ]; then
  echo "pyos is ready"
  echo "adding some applications to pyos repo" 
  for app in $ABCDESKTOP_JSON_APPLICATIONS
  do
	echo "Downloading $URL_APPLICATION_CONF_SOURCE/$app"
	echo "to register it in $PYOS_SERVICE_URL"
	curl $URL_APPLICATION_CONF_SOURCE/$app | curl -X PUT -H 'Content-Type: text/javascript' $PYOS_MANAGEMENT_SERVICE_URL  -d @-
  done
  echo 'Please wait for pull-* pod ready'
  kubectl get pods -n abcdesktop
  pods=$(kubectl -n abcdesktop get pods --selector=type=pod_application_pull --template '{{range .items}}{{.metadata.name}}{{"\n"}}{{end}}')
  echo "list of created pods for pulling is: "
  echo "$pods"
  echo "waiting for all pods condition Ready. timeout=-1s (it will take a while)"
  kubectl wait --for=condition=Ready pods --selector=type=pod_application_pull --timeout=-1s -n abcdesktop
else
  echo "pyos is not ready"	
  echo "Something wrong with $PYOS_HEALTZ_SERVICE_URL"
  PYOS_POD_NAME=$(kubectl get pods --selector=name=daemonset-pyospods -o jsonpath={.items..metadata.name} -n abcdesktop)
  echo "Look at pod $PYOS_POD_NAME log"
  kubectl logs $PYOS_POD_NAME -n abcdesktop
fi
