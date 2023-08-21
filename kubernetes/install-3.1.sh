#!/bin/bash
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
# This file will be fetched as: curl -L https://raw.githubusercontent.com/abcdesktopio/conf/main/kubernetes/install-3.0.sh | sh -
# so it should be pure bourne shell
#
# run curl -L https://raw.githubusercontent.com/abcdesktopio/conf/main/kubernetes/install.sh | sh -
#

VERSION="3.1.0"


ABCDESKTOP_YAML_SOURCE="https://raw.githubusercontent.com/abcdesktopio/conf/main/kubernetes/abcdesktop-3.0.yaml"
OD_CONFIG_SOURCE="https://raw.githubusercontent.com/abcdesktopio/conf/main/reference/od.config.3.0"
POD_USER_SOURCE="https://raw.githubusercontent.com/abcdesktopio/conf/main/kubernetes/poduser.yaml"


# define YAML path
ABCDESKTOP_YAML=abcdesktop.yaml
PODUSER_YAML=poduser.yaml
# default namespace
NAMESPACE=abcdesktop
# force continue when an error occurs
# No force by default
FORCE=0 

# list of pod container image to prefetch
# ABCDESKTOP_POD_IMAGES="
# $REGISTRY_DOCKERHUB/oc.user.ubuntu:$ABCDESKTOP_RELEASE 
# $REGISTRY_DOCKERHUB/oc.pulseaudio:$ABCDESKTOP_RELEASE 
# $REGISTRY_DOCKERHUB/oc.cupsd:$ABCDESKTOP_RELEASE 
# docker.io/library/busybox:latest
# k8s.gcr.io/pause:3.8"


if [ -z "${LOG_FILE}" ];
then
    LOG_FILE="/var/log/kube.log"
fi

# $1 message
display_section() {
    printf "\033[0;1;4m$1\033[0;0m\n"
}

# $1 message
# $2 status
display_message() {
    # ${2^^}: bad substitution, use "${2}" 
    # use printf instead of echo for better compatibility sh zsh bash
    case "${2}" in
        "OK") COLOR="\033[0;32m";;
        "KO") COLOR="\033[0;31m";;
        "ERROR") COLOR="\033[0;31m";;
        "WARN") COLOR="\033[0;33m";;
        "INFO") COLOR="\033[1;34m";;
    esac
    printf "[$COLOR${2}\033[0;0m] $1\n"
}

# $1 message
display_message_result() {
    exit_code="$?"
    if [ "$exit_code" -eq 0 ];
    then
        display_message "$1" "OK"

    else
        display_message "$1 error $exit_code" "KO"
	# by default force=0, exit
	if [ "$FORCE" -eq 0 ];
	then
        	exit 1
	fi
    fi
}


# $1 command
check_command() {
    if ! command -v "$1" &> /dev/null
    then
        display_message "$1 could not be found" "KO"
    exit 1
fi
}



function help() {
        cat <<-EOF
abcdesktop setup tool

Usage: abcdesktop-install [OPTION] [--namespace abcdesktop]...

Options (exclusives):
 --help                     Display this help and exit
 --version                  Display version information and exit
 --clean 		    Remove *.pem od.config abcdesktop.yaml poduser.yaml files only

Parameters:
 --namespace                Define the abcdesktop namespace default value is abcdesktop
 --force                    Continue if an error occurs
 
Examples:
    abcdesktop-install
    Install an abcdesktop service on a kubernetes cluster.

    abcdesktop-install --namespace=superdesktop
    Install an abcdesktop service in the superdesktop namespace on a kubernetes cluster

    abcdesktop-install --force=1
    Continue if a system or a kubernetes error occurs

  
Exit status:
 0      if OK,
 1      if any problem

Report bugs to https://github.com/abcdesktopio/conf/issues
EOF
}


function clean() {
  rm ./*.pem od.config abcdesktop.yaml poduser.yaml
  display_message_result "remove files"
}



function version() {
    cat <<-EOF
abcdesktop install script - $VERSION
This is free software; see the source for copying conditions.
Written by Alexandre DEVELY
EOF
}

opts=$(getopt \
    --longoptions "help,version,clean,force:,namespace:," \
    --name "$(basename "$0")" \
    --options "" \
    -- "$@"
)
eval set "--$opts"

while [ $# -gt 0 ]
do
    case "$1" in
        # commands
        --help) help; exit;;
        --version) version; exit;;
	--clean) clean; exit;;
        --namespace) NAMESPACE="$2";shift;;
	--force) FORCE="$2";shift;;
    esac
    shift
done

echo "abcdesktop install script namespace=${NAMESPACE}"

# Check if kubectl command is supported
# run command kubectl version
check_command kubectl
KUBE_VERSION=$(kubectl version --output=yaml)
display_message_result "kubectl version"

# Check if kubectl command is supported
# run command kubectl version
check_command openssl
OPENSSL_VERSION=$(openssl version)
display_message_result "openssl version"

# First create the abcdesktop namespace
KUBE_CREATE_NAMESPACE=$(kubectl create namespace "$NAMESPACE")
display_message_result "kubectl create namespace $NAMESPACE"


if [ -n "$DEBUG" ]; then
  echo "params namespace=${NAMESPACE} force=${FORCE}"
  echo "OPENSSL_VERSION=$OPENSSL_VERSION"
  echo "KUBE_VERSION=$KUBE_VERSION"
  echo "KUBE_CREATE_NAMESPACE=$KUBE_CREATE_NAMESPACE"
fi

# RSA keys
# build rsa kay pairs for jwt payload 
# 1024 bits is a smallest value, change here if need but use more than 1024
if [ ! -f abcdesktop_jwt_desktop_payload_private_key.pem ]; then
	openssl genrsa -out abcdesktop_jwt_desktop_payload_private_key.pem 1024 
	openssl rsa    -in  abcdesktop_jwt_desktop_payload_private_key.pem -outform PEM -pubout -out  _abcdesktop_jwt_desktop_payload_public_key.pem 
	openssl rsa    -pubin -in _abcdesktop_jwt_desktop_payload_public_key.pem -RSAPublicKey_out -out abcdesktop_jwt_desktop_payload_public_key.pem 
	display_message_result "abcdesktop_jwt_desktop_payload keys create"
fi

# build rsa kay pairs for the desktop jwt signing
if [ ! -f abcdesktop_jwt_desktop_signing_private_key.pem ]; then
	openssl genrsa -out abcdesktop_jwt_desktop_signing_private_key.pem 1024 
	openssl rsa    -in  abcdesktop_jwt_desktop_signing_private_key.pem -outform PEM -pubout -out abcdesktop_jwt_desktop_signing_public_key.pem 
	display_message_result "abcdesktop_jwt_desktop_signing keys create"
fi

# build rsa kay pairs for the user jwt signing 
if [ ! -f abcdesktop_jwt_user_signing_private_key.pem ]; then
	openssl genrsa -out abcdesktop_jwt_user_signing_private_key.pem 1024
	openssl rsa    -in  abcdesktop_jwt_user_signing_private_key.pem -outform PEM -pubout -out abcdesktop_jwt_user_signing_public_key.pem 
	display_message_result "abcdesktop_jwt_user_signing keys create"
fi

# import RSA Keys as Kubernetes secrets 
kubectl create secret generic abcdesktopjwtdesktoppayload \
	--from-file=abcdesktop_jwt_desktop_payload_private_key.pem \
	--from-file=abcdesktop_jwt_desktop_payload_public_key.pem \
	--namespace="$NAMESPACE" > /dev/null 
display_message_result "create secret generic abcdesktopjwtdesktoppayload"

kubectl create secret generic abcdesktopjwtdesktopsigning \
	--from-file=abcdesktop_jwt_desktop_signing_private_key.pem \
	--from-file=abcdesktop_jwt_desktop_signing_public_key.pem \
	--namespace="$NAMESPACE" > /dev/null
display_message_result "create secret generic abcdesktopjwtdesktopsigning"

kubectl create secret generic abcdesktopjwtusersigning \
	--from-file=abcdesktop_jwt_user_signing_private_key.pem \
	--from-file=abcdesktop_jwt_user_signing_public_key.pem \
	--namespace="$NAMESPACE" > /dev/null
display_message_result "create secret generic abcdesktopjwtusersigning"

# create label for secret 
kubectl label  secret abcdesktopjwtdesktoppayload abcdesktop/role=desktop.payloadkeys \
	--namespace="$NAMESPACE" > /dev/null
display_message_result "label secret abcdesktopjwtdesktoppayload"
kubectl label  secret abcdesktopjwtdesktopsigning abcdesktop/role=desktop.signingkeys \
	--namespace="$NAMESPACE" > /dev/null
display_message_result "label secret abcdesktopjwtdesktopsigning"
kubectl label  secret abcdesktopjwtusersigning    abcdesktop/role=user.signingkeys \
	--namespace="$NAMESPACE" > /dev/null
display_message_result "label secret abcdesktopjwtusersigning"
 

echo "Downloading file abcdesktop.yaml if need" 
# create abcdesktop.yaml file
if [ -f abcdesktop.yaml ]; then
   display_message "use local file abcdesktop.yaml file" "OK"
   ABCDESKTOP_YAML=abcdesktop.yaml
else
   curl "$ABCDESKTOP_YAML_SOURCE" --output abcdesktop.yaml
   display_message_result "downloaded source $ABCDESKTOP_YAML_SOURCE"
fi

echo "Downloading file od.config if need" 
# create od.config file
if [ -f od.config ]; then
   display_message "use local file od.config file" "OK"
else
   curl "$OD_CONFIG_SOURCE" --output od.config
   display_message_result "downloaded source $OD_CONFIG_SOURCE"
fi


echo "Downloading file poduser.yaml if need"
# create poduser.yaml file
if [ -f poduser.yaml ]; then
   display_message "use local file poduser.yaml" "OK"
   PODUSER_YAML=poduser.yaml
else
   curl "$POD_USER_SOURCE" --output poduser.yaml
   display_message_result "downloaded source $POD_USER_SOURCE"
fi


# Patching file is namespace has changed
if [ "$NAMESPACE" != "abcdesktop" ]; then
   # abcdesktop.yaml
   # replace namespace: abcdesktop -> namespace: $NAMESPACE 
   sed -i "s\namespace: abcdesktop\namespace: $NAMESPACE\g" abcdesktop.yaml
   display_message_result "updated abcdesktop.yaml file with new namespace $NAMESPACE"
   # replace .abcdesktop.svc.cluster.local -> .$NAMESPACE.svc.cluster.local
   sed -i "s\abcdesktop.svc.cluster.local\\$NAMESPACE.svc.cluster.local\g" abcdesktop.yaml
   display_message_result "updated abcdesktop.yaml file with new fqdn $NAMESPACE.svc.cluster.local"
   # od.config
   # replace namespace: 'abcdesktop' -> namespace: '$NAMESPACE'
   sed -i "s\namespace: 'abcdesktop'\namespace: '$NAMESPACE'\g" od.config
   display_message_result "updated od.config file with new namespace $NAMESPACE"
   # poduser.yaml
   # 
   sed -i "s\ \"abcdesktop\"\ \"$NAMESPACE\"\g" poduser.yaml
   display_message_result "updated poduser.yaml file with new $NAMESPACE"
fi



kubectl create configmap abcdesktop-config --from-file=od.config -n "$NAMESPACE" > /dev/null
display_message_result "kubectl create configmap abcdesktop-config --from-file=od.config -n $NAMESPACE"

kubectl label configmap abcdesktop-config abcdesktop/role=pyos.config -n "$NAMESPACE" > /dev/null
display_message_result "label configmap abcdesktop-config abcdesktop/role=pyos.config"


# create a dummy pod user
kubectl create -f $PODUSER_YAML > /dev/null
display_message_result "kubectl create -f $PODUSER_YAML"

echo "waiting for pod/anonymous-74bea267-8197-4b1d-acff-019b24e778c5 Ready"
kubectl wait --for=condition=Ready pod/anonymous-74bea267-8197-4b1d-acff-019b24e778c5  -n "$NAMESPACE" --timeout=-1s
kubectl delete -f $PODUSER_YAML


kubectl create -f $ABCDESKTOP_YAML
display_message_result "kubectl create -f $ABCDESKTOP_YAML"


deployments=$(kubectl -n "$NAMESPACE" get deployment --template '{{range .items}}{{.metadata.name}}{{"\n"}}{{end}}')
for d in $deployments;  
do 
	echo "waiting for deployment/$d available"; 
	kubectl -n "$NAMESPACE" wait "deployment/$d" --for=condition=available --timeout=-1s; 
done

pods=$(kubectl -n "$NAMESPACE" get pods --template '{{range .items}}{{.metadata.name}}{{"\n"}}{{end}}')
for p in $pods; 
do
	echo "waiting for pod/$p Ready"
	kubectl -n "$NAMESPACE" wait "pod/$p" --for=condition=Ready --timeout=-1s
done

# list all pods 
kubectl get pods -n "$NAMESPACE"
echo ""
echo "Setup done !"
echo ""
# echo "Open your navigator to http://[your-ip-hostname]:30443/"
# ABCDESKTOP_SERVICES=$(kubectl get pods --selector=name=nginx-od -o jsonpath={.items..status.hostIP} -n abcdesktop)
# echo "and replace [your-ip-hostname] by your default server ip address"
# echo "The abcdesktop url should be:"
# for srv in $ABCDESKTOP_SERVICES
# do
#    URL=http://$srv:30443/
#    echo "$URL"
# done


#
echo "Checking the service url on http://localhost:30443" 
# GET the abcdesktop logo
curl --max-time 3 http://localhost:30443/img/abcdesktop.svg 2>/dev/null 1>/dev/null 
CURL_EXIT_CODE=$?
if [ "$CURL_EXIT_CODE" -eq 0 ]; then
  display_message "service status is up" "OK"
  echo ""
  echo "Open your navigator to http://localhost:30443/"
  echo ""
  exit 0
else
  echo "service status is down"
fi 



#
# give me a free tcp port starting from 30443
BASE_PORT=30443
INCREMENT=1
port=$BASE_PORT
if ! [ -x "$(command -v netstat)" ]; then
  echo "netstat is not installed. I'm using port=$port" >&2
else
  isfree=$(netstat -taln |grep $port)
  while [[ -n "$isfree" ]]; do
    port=$((port+INCREMENT))
    isfree=$(netstat -taln |grep "$port")
  done
fi


echo "If you're using a cloud provider"
echo "Forwarding abcdesktop service for you on port=$port"
NGINX_POD_NAME=$(kubectl get pods -l run=nginx-od -o jsonpath={.items..metadata.name} -n "$NAMESPACE")
echo "Setup is running the command 'kubectl port-forward $NGINX_POD_NAME --address 0.0.0.0 $port:80 -n $NAMESPACE'"
kubectl port-forward "$NGINX_POD_NAME" --address 0.0.0.0 "$port:80" -n "$NAMESPACE" &


MY_IP='localhost'
HOST=$(hostname -I 2>/dev/null)
HOSTNAME_EXIT_CODE=$?
if [ "$HOSTNAME_EXIT_CODE" -eq 0 ]; then
	MY_IP=$(echo "$HOST"|awk '{print $1}')
fi

echo "Please open your web browser and connect to"
echo ""
echo "http://$MY_IP:$port/"
echo ""
