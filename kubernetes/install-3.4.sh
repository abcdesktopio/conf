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

VERSION="3.4"

ABCDESKTOP_YAML_SOURCE="https://raw.githubusercontent.com/abcdesktopio/conf/main/kubernetes/abcdesktop-$VERSION.yaml"
OD_CONFIG_SOURCE="https://raw.githubusercontent.com/abcdesktopio/conf/main/reference/od.config.$VERSION"

# define YAML path
ABCDESKTOP_YAML=abcdesktop.yaml
# default namespace
NAMESPACE=abcdesktop
# force continue when an error occurs
# No force by default
FORCE=0 
# TIMEOUT DEFAULT VALUE 
TIMEOUT=600s
# update ImagePolicy
# IMAGEPULLPOLICY unset value by default

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
    printf "\033[0;1;4m%s\033[0;0m\n" "$1"
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
    printf "[$COLOR%s\033[0;0m] %s\n" "$2" "$1"
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


# $1 service account
ensure_service_account_created() {
  # The default account is known to take a while to appear; see
  #  https://github.com/kubernetes/kubernetes/issues/66689
  i="0"
  SERVICE_ACCOUNT="${1}"
  while [ $i -lt 20 ]
  do
    kubectl -n "${NAMESPACE}" get serviceaccount "${SERVICE_ACCOUNT}" -o name > /dev/null
    lastcommand=$?
    if [ "$lastcommand" -eq 0 ];
    then
        display_message "$SERVICE_ACCOUNT account is created" "OK"
        break
    else
	i=$((i+1))
        display_message " retry $i/10 $SERVICE_ACCOUNT account is not yet created, sleeping for 5s" "INFO"
        sleep 5
    fi
  done  
}


function help() {
        cat <<-EOF
abcdesktop setup tool

Usage: abcdesktop-install [OPTION] [--namespace abcdesktop]...

Options (exclusives):
 --help                     Display this help and exit
 --version                  Display version information and exit
 --clean 		    Remove *.pem od.config abcdesktop.yaml files only
 --force                    Continue if an error occurs

Parameters:
 --namespace                Define the abcdesktop namespace default value is abcdesktop
 --timeout                  Continue if an error occurs
 --imagepullpolicy          Update image pull policy on all pods
 
Examples:
    abcdesktop-install
    Install an abcdesktop service on a kubernetes cluster.

    abcdesktop-install --namespace=superdesktop
    Install an abcdesktop service in the superdesktop namespace on a kubernetes cluster

    abcdesktop-install --force
    Continue if a system or a kubernetes error occurs

  
Exit status:
 0      if OK,
 1      if any problem

Report bugs to https://github.com/abcdesktopio/conf/issues
EOF
}


function clean() {
  rm -f od.config abcdesktop.yaml
  rm -f *.pem
  display_message_result "remove files"
}



function version() {
    cat <<-EOF
abcdesktop install script - $VERSION
This is free software; see the source for copying conditions.
Written by Alexandre DEVELY
Written by J.F. Vincent
EOF
}

opts=$(getopt \
    --longoptions "help,version,clean,force,timeout:,namespace:,imagepullpolicy:" \
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
	--timeout) TIMEOUT="$2";shift;;
        --namespace) NAMESPACE="$2";shift;;
	--imagepullpolicy) IMAGEPULLPOLICY="$2";shift;;
	--force) FORCE=1;shift;;
    esac
    shift
done

display_message  "abcdesktop install script namespace=${NAMESPACE}" "INFO"
if [ ! -z "$IMAGEPULLPOLICY" ];
then
     display_message "imagePullPolcy is set to $IMAGEPULLPOLICY" "INFO"
fi


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
 

# create abcdesktop.yaml file
if [ -f abcdesktop.yaml ]; then
   display_message "use local file abcdesktop.yaml" "OK"
   ABCDESKTOP_YAML=abcdesktop.yaml
else
   curl --progress-bar "$ABCDESKTOP_YAML_SOURCE" --output abcdesktop.yaml
   display_message_result "downloaded source $ABCDESKTOP_YAML_SOURCE"
   if [ ! -z "$IMAGEPULLPOLICY" ];
   then
     sed -i "s/IfNotPresent/$IMAGEPULLPOLICY/g" abcdesktop.yaml
     display_message_result "update imagePullPolcy to $IMAGEPULLPOLICY"
   fi
fi

# create od.config file
if [ -f od.config ]; then
   display_message "use local file od.config" "OK"
else
   curl --progress-bar "$OD_CONFIG_SOURCE" --output od.config
   display_message_result "downloaded source $OD_CONFIG_SOURCE"
   if [ ! -z "$IMAGEPULLPOLICY" ];
   then
     sed -i "s/IfNotPresent/$IMAGEPULLPOLICY/g" od.config
     display_message_result "update imagePullPolcy to $IMAGEPULLPOLICY"
   fi
fi

# Patching file is namespace has changed
if [ "$NAMESPACE" != "abcdesktop" ]; then
   # abcdesktop.yaml
   # replace namespace: abcdesktop -> namespace: $NAMESPACE 
   sed -i'' -e "s|namespace: abcdesktop|namespace: $NAMESPACE|g" abcdesktop.yaml
   display_message_result "updated abcdesktop.yaml file with new namespace $NAMESPACE"
   # replace .abcdesktop.svc.cluster.local -> .$NAMESPACE.svc.cluster.local
   sed -i'' -e "s|abcdesktop.svc.cluster.local|$NAMESPACE.svc.cluster.local|g" abcdesktop.yaml
   display_message_result "updated abcdesktop.yaml file with new fqdn $NAMESPACE.svc.cluster.local"
   # od.config
   # replace namespace: 'abcdesktop' -> namespace: '$NAMESPACE'
   sed -i'' -e "s|namespace: 'abcdesktop'|namespace: '$NAMESPACE'|g" od.config
   display_message_result "updated od.config file with new namespace $NAMESPACE"
   sed -i'' -e "s|abcdesktop.svc.cluster.local|$NAMESPACE.svc.cluster.local|g" od.config
   display_message_result "updated od.config file with new fqdn $NAMESPACE.svc.cluster.local"
fi

#
# create configmap from od.config file
kubectl create configmap abcdesktop-config --from-file=od.config -n "$NAMESPACE" > /dev/null
display_message_result "kubectl create configmap abcdesktop-config --from-file=od.config -n $NAMESPACE"
# tag abcdesktop-config cm
kubectl label configmap abcdesktop-config abcdesktop/role=pyos.config -n "$NAMESPACE" > /dev/null
display_message_result "label configmap abcdesktop-config abcdesktop/role=pyos.config"


#
# ensure_service_account_created 
ensure_service_account_created default

#clean endpoints desktop 
# if a previous abcdesktop has been done
kubectl get endpoints desktop >/dev/null  2>/dev/null
EXIT_CODE=$?
if [ $EXIT_CODE -eq 0 ]; then
        display_message "previous endpoint desktop has been found" "INFO"
	delete_message=$(kubectl delete endpoints desktop)
        display_message_result "$delete_message"
fi


# main yaml file 
create_message=$(kubectl create -f $ABCDESKTOP_YAML)
display_message_result "$create_message"

# ensure service account pyos-serviceaccount
ensure_service_account_created pyos-serviceaccount

deployments=$(kubectl -n "$NAMESPACE" get deployment --template '{{range .items}}{{.metadata.name}}{{"\n"}}{{end}}')
for d in $deployments;  
do 
	display_message  "waiting for deployment/$d available" "INFO"
	wait_message=$(kubectl -n "$NAMESPACE" wait "deployment/$d" --for=condition=available --timeout=-1s)
        display_message_result "$wait_message"	
done

pods=$(kubectl -n "$NAMESPACE" get pods --template '{{range .items}}{{.metadata.name}}{{"\n"}}{{end}}')
for p in $pods; 
do
 	display_message "waiting for pod/$p Ready" "INFO" 
	wait_message=$(kubectl -n "$NAMESPACE" wait "pod/$p" --for=condition=Ready --timeout="$TIMEOUT")
	display_message_result "$wait_message"
done

# list all pods 
display_message "list all pods in namespace $NAMESPACE" "INFO"
kubectl get pods -n "$NAMESPACE"
display_message "Setup done" "INFO"

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
display_message "Checking the service url on http://localhost:30443" "INFO"
# GET the abcdesktop logo
curl --max-time 3 http://localhost:30443/img/abcdesktop.svg 2>/dev/null 1>/dev/null 
CURL_EXIT_CODE=$?
if [ "$CURL_EXIT_CODE" -eq 0 ]; then
  echo -e
  display_message "Please open your web browser and connect to http://localhost:30443/" "OK"
  echo -e
  exit 0
else
  display_message "service status is down" "INFO"
fi 



#
# give me a free tcp port starting from 30443
BASE_PORT=30443
INCREMENT=1
port=$BASE_PORT
display_message "Looking for a free tcp port from $port" "INFO"
if ! [ -x "$(command -v netstat)" ]; then
  display_message "netstat command is not found. I'm using port=$port" "INFO"
else
  isfree=$(netstat -taln |grep $port)
  while [[ -n "$isfree" ]]; do
    port=$((port+INCREMENT))
    isfree=$(netstat -taln |grep "$port")
  done
fi
display_message "get a free tcp port from $port" "OK"
echo -e

display_message "If you're using a cloud provider" "INFO"
display_message "Forwarding abcdesktop service for you on port=$port" "INFO"
ROUTER_POD_NAME=$(kubectl get pods -l run=router-od -o jsonpath={.items..metadata.name} -n "$NAMESPACE")
display_message "For you setup is running the command 'kubectl port-forward $ROUTER_POD_NAME --address 0.0.0.0 $port:80 -n $NAMESPACE'" "INFO"
kubectl port-forward "$ROUTER_POD_NAME" --address 0.0.0.0 "$port:80" -n "$NAMESPACE" &

MY_IP='localhost'
HOST=$(hostname -I 2>/dev/null)
HOSTNAME_EXIT_CODE=$?
if [ "$HOSTNAME_EXIT_CODE" -eq 0 ]; then
	MY_IP=$(echo "$HOST"|awk '{print $1}')
fi

display_message "Please open your web browser and connect to" "OK"
echo -e
display_message  "http://$MY_IP:$port/" "INFO"
echo -e
