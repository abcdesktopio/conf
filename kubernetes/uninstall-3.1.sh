#!/bin/bash
#
#
# Uninstall script kubernetes for abcdesktopio
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
# run curl -L https://raw.githubusercontent.com/abcdesktopio/conf/main/kubernetes/uninstall-3.1.sh | sh -
#

VERSION="3.1"

ABCDESKTOP_YAML_SOURCE="https://raw.githubusercontent.com/abcdesktopio/conf/main/kubernetes/abcdesktop-$VERSION.yaml"


# default namespace
NAMESPACE=abcdesktop
# force continue when an error occurs
# force by default
FORCE=1


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



function help() {
        cat <<-EOF
abcdesktop uninstall

Usage: abcdesktop-uninstall [OPTION] [--namespace abcdesktop]...

Options (exclusives):
 --help                     Display this help and exit
 --version                  Display version information and exit
 --clean                    Remove *.pem od.config abcdesktop.yaml poduser.yaml files only

Parameters:
 --namespace                Define the abcdesktop namespace default value is abcdesktop
 --force                    Continue if an error occurs
 
Examples:
    abcdesktop-uninstall
    Uninstall abcdesktop service on a kubernetes cluster.

    abcdesktop-uninstall --namespace=superdesktop
    Uninstallnstall abcdesktop service in the superdesktop namespace on a kubernetes cluster

    abcdesktop-uninstall --force=1
    Continue if a system or a kubernetes error occurs

  
Exit status:
 0      if OK,
 1      if any problem

Report bugs to https://github.com/abcdesktopio/conf/issues
EOF
}


function clean() {
  rm -f od.config abcdesktop.yaml poduser.yaml
  display_message_result "remove od.config abcdesktop.yaml poduser.yaml"
  rm -f ./*.pem
  display_message_result "remove *.pem"
}



function version() {
    cat <<-EOF
abcdesktop uninstall script - $VERSION
This is free software; see the source for copying conditions.
Written by Alexandre DEVELY
Written by J.F. Vincent
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

echo "abcdesktop uninstall script namespace=${NAMESPACE}"

# Check if kubectl command is supported
# run command kubectl version
check_command kubectl
KUBE_VERSION=$(kubectl version --output=yaml)
display_message_result "kubectl version"


# First create the abcdesktop namespace
KUBE_GET_NAMESPACE=$(kubectl get namespace "$NAMESPACE")
display_message_result "kubectl get namespace $NAMESPACE"


if [ -n "$DEBUG" ]; then
  echo "params namespace=${NAMESPACE} force=${FORCE}"
  echo "KUBE_VERSION=$KUBE_VERSION"
  echo "KUBE_GET_NAMESPACE=$KUBE_GET_NAMESPACE"
fi


START=$EPOCHSECONDS
if [ ! -z "$START" ]; then
  if [ -n "$DEBUG" ]; then
      display_message "start at $START epoch seconds" "INFO"
  fi
fi

kubectl delete pods --selector="type=x11server" -n "$NAMESPACE" > /dev/null
display_message_result "delete pods --selector=\"type=x11server\" -n $NAMESPACE"

# create abcdesktop.yaml file
if [ -f abcdesktop.yaml ]; then
   display_message "use local file abcdesktop.yaml" "OK"
else
   curl "$ABCDESKTOP_YAML_SOURCE" --output abcdesktop.yaml
   display_message_result "downloaded source $ABCDESKTOP_YAML_SOURCE"
fi


# Patching file is namespace has changed
if [ "$NAMESPACE" != "abcdesktop" ]; then
   # abcdesktop.yaml
   # replace namespace: abcdesktop -> namespace: $NAMESPACE 
   sed -i'' -e "s|namespace: abcdesktop|namespace: $NAMESPACE|g" abcdesktop.yaml
   display_message_result "updated abcdesktop.yaml file with new namespace $NAMESPACE"
fi

kubectl delete -f abcdesktop.yaml
display_message_result "kubectl delete -f abcdesktop.yaml"
kubectl delete secrets --all -n "$NAMESPACE" > /dev/null
display_message_result "kubectl delete secrets --all -n $NAMESPACE"
kubectl delete cm --all -n "$NAMESPACE" > /dev/null
display_message_result "kubectl delete configmap --all -n $NAMESPACE"
kubectl delete pvc --all -n "$NAMESPACE" > /dev/null
display_message_result "kubectl delete pvc --all -n $NAMESPACE"
display_message "deleting namespace $NAMESPACE" "INFO"
delete_message=$(kubectl delete namespace "$NAMESPACE")
display_message_result "$delete_message"

# delete files
# clean()

if [ ! -z "$START" ]; then
  TIMEDIFF=$(expr "$EPOCHSECONDS" - "$START")
  if [ -n "$DEBUG" ]; then
      display_message  "the process takes $TIMEDIFF seconds to complete" "INFO"
  fi
fi
