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

$VERSION="3.5"

$ABCDESKTOP_YAML_SOURCE="https://raw.githubusercontent.com/abcdesktopio/conf/main/kubernetes/abcdesktop-$VERSION.yaml"
$OD_CONFIG_SOURCE="https://raw.githubusercontent.com/abcdesktopio/conf/main/reference/od.config.$VERSION"


# define YAML path
$ABCDESKTOP_YAML="abcdesktop.yaml"
# define config path
$OD_CONFIG="od.config"
# default namespace
$NAMESPACE="abcdesktop"
# force continue when an error occurs
# No force by default
$FORCE=0 
# TIMEOUT DEFAULT VALUE 
$TIMEOUT="600s"
# update ImagePolicy
# IMAGEPULLPOLICY unset value by default

# list of pod container image to prefetch
# ABCDESKTOP_POD_IMAGES="
# $REGISTRY_DOCKERHUB/oc.user.ubuntu:$ABCDESKTOP_RELEASE 
# $REGISTRY_DOCKERHUB/oc.pulseaudio:$ABCDESKTOP_RELEASE 
# $REGISTRY_DOCKERHUB/oc.cupsd:$ABCDESKTOP_RELEASE 
# docker.io/library/busybox:latest
# k8s.gcr.io/pause:3.8"

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

function clean_files {
    rm od.config 
    display_message_result "remove od.config"
    rm abcdesktop.yaml 
    display_message_result "remove abcdesktop.yaml"
    rm *.pem
    display_message_result "remove *.pem"
}


function help {
@"
    abcdesktop setup tool

    Usage: abcdesktop-install [OPTION] [--namespace abcdesktop]...
    
    Options (exclusives):
     --help                     Display this help and exit
     --version                  Display version information and exit
     --clean 		        Remove *.pem od.config abcdesktop.yaml files only
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
"@
}

function version {
@"
    abcdesktop install script - $VERSION
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
        "--timeout" { $TIMEOUT = $args[1]; $args = $args[1..$args.length]; break }
        "--namespace" { $NAMESPACE = $args[1]; $args = $args[1..$args.length]; break }
        "--imagepullpolicy" { $IMAGEPULLPOLICY = $args[1]; $args = $args[1..$args.length]; break }
        "--force" { $FORCE = 1; break }
    }
    $args = $args[1..$args.length]
}

display_message  "abcdesktop install script namespace=${NAMESPACE}" "INFO"

#Check if kubectl command is supported
# run command kubectl version
check_command "kubectl"
$KUBE_VERSION=$(kubectl version)
display_message_result "kubectl version"

# Check if openssl command is supported
# run command openssl version
check_command "openssl"
$OPENSSL_VERSION=$(openssl version)
display_message_result "openssl version"

# First create the abcdesktop namespace
$KUBE_CREATE_NAMESPACE=$(kubectl create namespace "$NAMESPACE")
display_message_result "kubectl create namespace $NAMESPACE"

# Secure abcdesktop JWT exchange

# RSA keys
# build rsa key pairs for jwt payload
# 1024 bits is the smallest value, change here if needed but use more than 1024
$privateKeyPath = "abcdesktop_jwt_desktop_payload_private_key.pem"
$publicKeyPath = "abcdesktop_jwt_desktop_payload_public_key.pem"

if (-not (Test-Path $privateKeyPath)) {
    openssl genrsa -out $privateKeyPath 1024
    openssl rsa -in $privateKeyPath -outform PEM -pubout -out _$publicKeyPath
    openssl rsa    -pubin -in _$publicKeyPath -RSAPublicKey_out -out $publicKeyPath

    display_message_result "abcdesktop_jwt_desktop_payload keys created"
}

# build rsa kay pairs for the desktop jwt signing
$privateKeyPath = "abcdesktop_jwt_desktop_signing_private_key.pem"
$publicKeyPath = "abcdesktop_jwt_desktop_signing_public_key.pem"

if (-not (Test-Path $privateKeyPath)) {
    openssl genrsa -out $privateKeyPath 1024
    openssl rsa -in $privateKeyPath -outform PEM -pubout -out $publicKeyPath

    display_message_result "abcdesktop_jwt_desktop_signing keys create"
}

# build rsa kay pairs for the user jwt signing 
$privateKeyPath = "abcdesktop_jwt_user_signing_private_key.pem"
$publicKeyPath = "abcdesktop_jwt_user_signing_public_key.pem"

if (-not (Test-Path $privateKeyPath)) {
    openssl genrsa -out $privateKeyPath 1024
    openssl rsa -in $privateKeyPath -outform PEM -pubout -out $publicKeyPath

    display_message_result "abcdesktop_jwt_user_signing keys create"
}

# import RSA Keys as Kubernetes secrets 
kubectl create secret generic abcdesktopjwtdesktoppayload --from-file=abcdesktop_jwt_desktop_payload_private_key.pem --from-file=abcdesktop_jwt_desktop_payload_public_key.pem --namespace=$NAMESPACE > $null
display_message_result "create secret generic abcdesktopjwtdesktoppayload"

kubectl create secret generic abcdesktopjwtdesktopsigning --from-file=abcdesktop_jwt_desktop_signing_private_key.pem --from-file=abcdesktop_jwt_desktop_signing_public_key.pem --namespace=$NAMESPACE > $null
display_message_result "create secret generic abcdesktopjwtdesktopsigning"

kubectl create secret generic abcdesktopjwtusersigning --from-file=abcdesktop_jwt_user_signing_private_key.pem --from-file=abcdesktop_jwt_user_signing_public_key.pem --namespace=$NAMESPACE > $null
display_message_result "create secret generic abcdesktopjwtusersigning"

# create label for secret 
kubectl label  secret abcdesktopjwtdesktoppayload abcdesktop/role=desktop.payloadkeys --namespace=$NAMESPACE > $null
display_message_result "label secret abcdesktopjwtdesktoppayload"

kubectl label  secret abcdesktopjwtdesktopsigning abcdesktop/role=desktop.signingkeys --namespace=$NAMESPACE > $null
display_message_result "label secret abcdesktopjwtdesktopsigning"

kubectl label  secret abcdesktopjwtusersigning abcdesktop/role=user.signingkeys --namespace=$NAMESPACE > $null
display_message_result "label secret abcdesktopjwtusersigning"

# create abcdesktop.yaml file
if (Test-Path $ABCDESKTOP_YAML){
    display_message "use local file abcdesktop.yaml" "OK"
    $ABCDESKTOP_YAML="abcdesktop.yaml"
}
else{
    curl $ABCDESKTOP_YAML_SOURCE -OutFile abcdesktop.yaml
    display_message_result "downloaded source $ABCDESKTOP_YAML_SOURCE"

    if (-not [string]::IsNullOrWhiteSpace($IMAGEPULLPOLICY)) {
        (Get-Content $ABCDESKTOP_YAML) -replace 'IfNotPresent', $IMAGEPULLPOLICY | Set-Content $ABCDESKTOP_YAML
        display_message_result "update imagePullPolcy to $IMAGEPULLPOLICY"
    }
}

# create od.config file
if (Test-Path $OD_CONFIG){
    display_message "use local file od.config" "OK"
    $OD_CONFIG="od.config"
}
else{
    curl $OD_CONFIG_SOURCE -OutFile od.config
    display_message_result "downloaded source $OD_CONFIG_SOURCE"

    if (-not [string]::IsNullOrWhiteSpace($IMAGEPULLPOLICY)) {
        (Get-Content $OD_CONFIG) -replace 'IfNotPresent', $IMAGEPULLPOLICY | Set-Content $OD_CONFIG
        display_message_result "update imagePullPolcy to $IMAGEPULLPOLICY"
    }
}

# Patching file is namespace has changed
if ("$NAMESPACE" -ne "abcdesktop"){
   # abcdesktop.yaml
   $path=".\abcdesktop.yaml"
   $content = Get-Content -Path $path
   # replace namespace: abcdesktop -> namespace: $NAMESPACE 
   $content = $content -replace 'namespace: abcdesktop', "namespace: $NAMESPACE"
   display_message_result "updated abcdesktop.yaml file with new namespace $NAMESPACE"
   # replace .abcdesktop.svc.cluster.local -> .$NAMESPACE.svc.cluster.local
   $content = $content -replace 'abcdesktop.svc.cluster.local', "$NAMESPACE.svc.cluster.local"
   display_message_result "updated abcdesktop.yaml file with new fqdn $NAMESPACE.svc.cluster.local"
   Set-Content -Path $path -Value $content
   # od.config
   $path=".\od.config"
   $content = Get-Content -Path $path
   # replace namespace: 'abcdesktop' -> namespace: '$NAMESPACE'
   $content = $content -replace "namespace: `'abcdesktop`'", "namespace: `'$NAMESPACE`'"
   display_message_result "updated od.config file with new namespace $NAMESPACE"
   $content = $content -replace 'abcdesktop.svc.cluster.local', "$NAMESPACE.svc.cluster.local"
   display_message_result "updated od.config file with new fqdn $NAMESPACE.svc.cluster.local"
   Set-Content -Path $path -Value $content
}

# create configmap from od.config file
kubectl create configmap abcdesktop-config --from-file=od.config -n $NAMESPACE > $null
display_message_result "kubectl create configmap abcdesktop-config --from-file=od.config -n $NAMESPACE"
# tag abcdesktop-config cm
kubectl label configmap abcdesktop-config abcdesktop/role=pyos.config -n $NAMESPACE > $null
display_message_result "label configmap abcdesktop-config abcdesktop/role=pyos.config"

#clean endpoints desktop 
# if a previous abcdesktop has been done
#kubectl get endpoints desktop > $null 2> $null
#$EXIT_CODE=$?
#if ( $EXIT_CODE -eq 0 ){
#    display_message "previous endpoint desktop has been found" "INFO"
#	$delete_message=$(kubectl delete endpoints desktop)
#    display_message_result "$delete_message"
#}

# main yaml file 
kubectl create -f $ABCDESKTOP_YAML

$deployments=$(kubectl -n $NAMESPACE get deployment --template '{{range .items}}{{.metadata.name}}`n{{end}}')
foreach ($d in $deployments -split '`n'){ 
    if($d -ne ''){
        display_message  "waiting for deployment/$d available" "INFO"
        $wait_message=$(kubectl -n $NAMESPACE wait "deployment/$d" --for=condition=available --timeout=-1s)
        display_message_result "$wait_message"	
    }
}

$pods=$(kubectl -n $NAMESPACE get pods --template '{{range .items}}{{.metadata.name}}`n{{end}}')
foreach ($p in $pods -split '`n'){
    if($d -ne ''){
        display_message "waiting for pod/$p Ready" "INFO" 
        $wait_message=$(kubectl -n $NAMESPACE wait "pod/$p" --for=condition=Ready --timeout=-1s)
        display_message_result "$wait_message"
    }
}

# list all pods 
display_message "list all pods in namespace $NAMESPACE" "INFO"
kubectl get pods -n $NAMESPACE
display_message "Setup done" "INFO"

display_message "Checking the service url on http://localhost:30443" "INFO"
# GET the abcdesktop logo
$CURL_EXIT_CODE = (curl "http://localhost:30443/img/abcdesktop.svg" 2>$null).ExitCode
if ($CURL_EXIT_CODE -eq 0 ){
    Write-Host ""
    display_message "Please open your web browser and connect to http://localhost:30443/" "OK"
    Write-Host ""
    exit 0
}
else{
    display_message "service status is down" "INFO"
}

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

display_message "Get a free TCP port from $port" "OK"
Write-Host ""

display_message "If you're using a cloud provider" "INFO"
display_message "Forwarding abcdesktop service for you on port=$port" "INFO"
$NGINX_POD_NAME=$(kubectl get pods -l run=nginx-od -o jsonpath="{.items..metadata.name}" -n $NAMESPACE)
display_message "For you setup is running the command 'kubectl port-forward $NGINX_POD_NAME --address 0.0.0.0 ${port}:80 -n $NAMESPACE'" "INFO"
$command = "kubectl port-forward $NGINX_POD_NAME --address 0.0.0.0 ${port}:80 -n $NAMESPACE"
$job = Start-Job -ScriptBlock {
    Invoke-Expression $using:command
}
Start-Sleep -Seconds 1
if ($job.State -eq "Running") {
    display_message "Port-Forward successful" "OK"
} else {
    display_message "Port-Forward unsuccessful" "KO"
}

$MY_IP='localhost'
$HOSTNAME_EXIT_CODE=$(hostname -I 2>$null).ExitCode
if ( "$HOSTNAME_EXIT_CODE" -eq 0 ){
	MY_IP=$(Write-Host "$HOST"|awk '{print $1}')
}

display_message "Please open your web browser and connect to" "OK"
Write-Host ""
display_message  "http://${MY_IP}:$port/" "INFO"
Write-Host ""
