#!/bin/bash
#
#
# add image script kubernetes for abcdesktopio
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

# define default NAMESPACE
NAMESPACE=abcdesktop

# define force
FORCE=0

# define ABCDESKTOP_YAML path
# ABCDESKTOP_YAML=abcdesktop.yaml 

# current release
ABCDESKTOP_RELEASE=3.2

# docker hub prefix
# REGISTRY_DOCKERHUB="docker.io/abcdesktopio"

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


# gimp.d.$ABCDESKTOP_RELEASE.json

URL_APPLICATION_CONF_SOURCE="https://raw.githubusercontent.com/abcdesktopio/images/main/artifact/$ABCDESKTOP_RELEASE/"


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
abcdesktop remove application tool

Usage: abcdesktop-removeapplication [OPTION] --imageid IMAGE_SHA_ID [--namespace abcdesktop]...

Options (exclusives):
 --help                     Display this help and exit
 --version                  Display version information and exit

Parameters:
 --namespace                Define the abcdesktop namespace default value is abcdesktop
 --force                    Continue if an error occurs
 
Examples:
    abcdesktop-rmapplication --imageid 64a4fdf753047ddabbc5cb993dc39628b39ae3e251743e7e80fc879022b99c5f
    Remove abcdesktop application 64a4fdf753047ddabbc5cb993dc39628b39ae3e251743e7e80fc879022b99c5f  on a kubernetes cluster.

    abcdesktop-removeapplication  --imageid 64a4fdf753047ddabbc5cb993dc39628b39ae3e251743e7e80fc879022b99c5f --namespace=superdesktop
    Remove abcdesktop appliction 64a4fdf753047ddabbc5cb993dc39628b39ae3e251743e7e80fc879022b99c5f  in the superdesktop namespace on a kubernetes cluster

  
Exit status:
 0      if OK,
 1      if any problem

Report bugs to https://github.com/abcdesktopio/conf/issues
EOF
}

function version() {
    cat <<-EOF
abcdesktop list images script - $VERSION
This is free software; see the source for copying conditions.
Written by Alexandre DEVELY
Written by J.F. Vincent
EOF
}

opts=$(getopt \
    --longoptions "help,version,clean,force:,jsonfile:,namespace:," \
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
      --namespace) NAMESPACE="$2";shift;;
      --jsonfile) JSONFILE="$2"; shift;;
    esac
    shift
done


if [ -z ${JSONFILE+x} ]; then 
	echo "--jsonfile is unset";
	display_message "Usage: $(basename $0) --jsonfile  <json_file>] [--namespace <namespace>]" "ERROR";
	exit 1
fi


PYOS_POD_NAME=$(kubectl get pods -l run=pyos-od -o jsonpath={.items..metadata.name} -n "$NAMESPACE" | awk '{print $1}')

# define service URL 
# inside pyos
URL="http://localhost:8080/API/manager/image"
app=$JSONFILE

kubectl cp -n "$NAMESPACE" "$app" "$PYOS_POD_NAME:/tmp/$app"
display_message_result "Copy $app to $PYOS_POD_NAME:/tmp/$app"
# import the json file description for this application $app into abdesktop service
kubectl exec -n "$NAMESPACE" -t "$PYOS_POD_NAME" -- curl -X PUT -H 'Content-Type: text/javascript' "$URL" -d "@/tmp/$app"
display_message_result "curl -X PUT -H 'Content-Type: text/javascript' $URL -d @$app"
# abcdesktop will start a pod with label type=pod_application_pull
# to prefetch container image
pods=$(kubectl -n "$NAMESPACE" get pods --selector=type=pod_application_pull --template '{{range .items}}{{.metadata.name}}{{"\n"}}{{end}}')
echo ""
echo "list of created pods for pulling is: "
echo "$pods"
echo "waiting for all pods condition Ready. timeout=-1s (it will take a while)"
kubectl wait --for=condition=Ready pods --selector=type=pod_application_pull --timeout=-1s -n "$NAMESPACE"
kubectl delete pod --selector=type=pod_application_pull -n "$NAMESPACE" > /dev/null
display_message_result "$app"



