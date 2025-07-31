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

# define default NAMESPACE
$NAMESPACE="abcdesktop"

# define force
$FORCE=0

# define ABCDESKTOP_YAML path
# ABCDESKTOP_YAML=abcdesktop.yaml 

# current release
$ABCDESKTOP_RELEASE=4.0

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

$URL_APPLICATION_CONF_SOURCE="https://raw.githubusercontent.com/abcdesktopio/images/main/artifact/$ABCDESKTOP_RELEASE"
# list of json default applications to prefetch
$ABCDESKTOP_JSON_APPLICATIONS="2048-alpine.d.$ABCDESKTOP_RELEASE.json,xterm.d.$ABCDESKTOP_RELEASE.json,writer.d.$ABCDESKTOP_RELEASE.json,firefox.d.$ABCDESKTOP_RELEASE.json,nautilus.d.$ABCDESKTOP_RELEASE.json,geany.d.$ABCDESKTOP_RELEASE.json,qterminalpod.d.$ABCDESKTOP_RELEASE.json,evince.d.$ABCDESKTOP_RELEASE.json"

function display_message {
    param (
        [string]$message,
        [string]$status
    )
    $color="White"
    switch ($status) {
        "OK" {$color="Green"; break}
        "KO" {$color="Red"; break}
        "ERROR" {$color="DarkRed"; break}
        "INFO" {$color="Blue"; break}
        "WARN" {$color="Yellow"; break}
    }
    Write-Host "[$status] $message" -ForegroundColor $color 
}

function display_message_result {
    param (
        [string]$message
    )

    $exitcode = $LASTEXITCODE
    if($exitcode -eq 0){
        display_message "$message" "OK"
    } else{
        display_message "$message error $exitcode" "KO"

        if($FORCE -eq 0){
            exit 1
        }
    }
}

function check_command {
    param (
        [string]$commandName
    )

    if (-not (Get-Command -Name $commandName -ErrorAction SilentlyContinue)) {
        Display-Message "$commandName could not be found" "KO"
        exit 1
    }
}

function help() {
@"
    abcdesktop pull application tool

    Usage: abcdesktop-pullapplications [OPTION] [--namespace abcdesktop]...

    Options (exclusives):
    --help                     Display this help and exit
    --version                  Display version information and exit
    --clean 		    Remove *.pem od.config abcdesktop.yaml poduser.yaml files only

    Parameters:
    --namespace                Define the abcdesktop namespace default value is abcdesktop
    --force                    Continue if an error occurs
    
    Examples:
        abcdesktop-pullapplications
        Install an abcdesktop service on a kubernetes cluster.

        abcdesktop-pullapplications --namespace=superdesktop
        Install an abcdesktop service in the superdesktop namespace on a kubernetes cluster

        abcdesktop-pullapplications --force=1
        Continue if a system or a kubernetes error occurs

    
    Exit status:
    0      if OK,
    1      if any problem

    Report bugs to https://github.com/abcdesktopio/conf/issues
"@
}


function clean() {
  foreach ($app in $ABCDESKTOP_JSON_APPLICATIONS){
        rm "$app"
        display_message_result "remove files $app"
  }
}

function version() {
@"
    abcdesktop pull images script - $VERSION
    This is free software; see the source for copying conditions.
    Written by Alexandre DEVELY
    Written by J.F. Vincent
    Written by Matteo BEGHELLI
"@
}

# Loop through remaining command line arguments
while ($args) {
    $arg = $args[0]
    switch ($arg) {
        "--help" {help ; exit }
        "--version" { version ; exit }
        "--clean" { clean_files ; exit }
        "--namespace" { $NAMESPACE = $args[1]; $args = $args[1..$args.length]; break }
        "--force" { $FORCE = $args[1]; $args = $args[1..$args.length]; break }
    }
    $args = $args[1..$args.length]
}

display_message "abcdesktop pull images script namespace=${NAMESPACE}" "INFO"


# give me a free tcp port starting from 30443
$BasePort = 30443
$Increment = 1
$port = $BasePort

display_message "Looking for a free TCP port from $port" "INFO"

if (-not (Get-Command Get-NetTCPConnection -ErrorAction SilentlyContinue)) {
    display_message "Get-NetTCPConnection command is not found. Using port=$port" "INFO"
}
else {
    $IsFree = Get-NetTCPConnection -LocalPort $port -ErrorAction SilentlyContinue
    while (-not ($IsFree)) {
        $Port += $Increment
        $IsFree = Get-NetTCPConnection -LocalPort $port -ErrorAction SilentlyContinue
    }
}

display_message "Forwarding abcdesktop service for you on port=$port" "OK"


# Check if kubectl command is supported
# run command kubectl version
check_command kubectl
kubectl version > $null
display_message_result "kubectl version"
$PYOS_POD_NAME=$(kubectl get pods -l run=pyos-od -o jsonpath="{.items..metadata.name}" -n "$NAMESPACE")
display_message_result "kubectl pods -l run=pyos-od -o jsonpath={.items..metadata.name} -n $NAMESPACE"
display_message "pyos pod name=$PYOS_POD_NAME" "OK"

# define service URL 
# inside pyos
$URL="http://localhost:$port/API/manager/image"

# call HEALTZ
foreach ($app in $ABCDESKTOP_JSON_APPLICATIONS -split ','){
        # download the json file description for this application $app
        curl "$URL_APPLICATION_CONF_SOURCE/$app" -OutFile "$app"
        display_message_result "curl $URL_APPLICATION_CONF_SOURCE/$app"
        # import the json file description for this application $app into abdesktop service
        kubectl cp -n "$NAMESPACE" "$app" "${PYOS_POD_NAME}:/tmp/$app"
        display_message_result "Copy $app to ${PYOS_POD_NAME}:/tmp/$app"
        # import the json file description for this application $app into abdesktop service
        kubectl exec -n "$NAMESPACE" -t "$PYOS_POD_NAME" -- curl -X PUT -H 'Content-Type: text/javascript' "$URL" -d "@/tmp/$app" 
        display_message_result "curl -X PUT -H 'Content-Type: text/javascript' $URL -d @$app"
        # abcdesktop will start a pod with label type=pod_application_pull
        # to prefetch container image
        $pods=$(kubectl -n "$NAMESPACE" get pods --selector=type=pod_application_pull --template '{{range .items}}{{.metadata.name}}{{end}}')
        Write-Host ""
        Write-Host "list of created pods for pulling is: "
        Write-Host "$pods"
        Write-Host "waiting for all pods condition Ready. timeout=-1s (it will take a while)"
        kubectl wait --for=condition=Ready pods --selector=type=pod_application_pull --timeout=-1s -n "$NAMESPACE"
        kubectl delete pod --selector=type=pod_application_pull -n "$NAMESPACE" > $null
        display_message_result "$app"
}
display_message "end of pull apps script" "INFO"