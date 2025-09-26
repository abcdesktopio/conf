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
# This file will be fetched as: curl -L https://raw.githubusercontent.com/abcdesktopio/conf/main/kubernetes/install-3.2.sh | sh -
# so it should be pure bourne shell
#
# run curl -L https://raw.githubusercontent.com/abcdesktopio/conf/main/kubernetes/uninstall-3.2.sh | sh -
#

$VERSION="4.3"

$ABCDESKTOP_YAML_SOURCE="https://raw.githubusercontent.com/abcdesktopio/conf/main/kubernetes/abcdesktop-$VERSION.yaml"
$ABCDESKTOP_CLUSTER_ROLE="https://raw.githubusercontent.com/abcdesktopio/conf/main/kubernetes/rbac-cluster.yaml"
$ABCDESKTOP_DEFAULT_ROLE="https://raw.githubusercontent.com/abcdesktopio/conf/main/kubernetes/rbac-role.yaml"

# define yaml path
$ABCDESKTOP_YAML="abcdesktop.yaml"
# default namespace
$NAMESPACE="abcdesktop"
# force continue when an error occurs
# force by default
$FORCE=1


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
    rm abcdesktop.yaml 
    display_message_result "remove od.config abcdesktop.yaml poduser.yaml"
    rm *.pem
    display_message_result "remove *.pem"
}

function help {
@"
    abcdesktop uninstall

    Usage: abcdesktop-uninstall [OPTION] [--namespace abcdesktop]...

    Options (exclusives):
    --help                     Display this help and exit
    --version                  Display version information and exit
    --clean                    Remove *.pem od.config abcdesktop.yaml files only

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
"@
}

function version {
@"
    abcdesktop uninstall script - $VERSION
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

display_message  "abcdesktop uninstall script namespace=${NAMESPACE}" "INFO"

# Check if kubectl command is supported
# run command kubectl version
check_command kubectl
$KUBE_VERSION=$(kubectl version)
display_message_result "kubectl version"

# First check if there is an abcdesktop namespace
$KUBE_GET_NAMESPACE=$(kubectl get namespace $NAMESPACE)
display_message_result "kubectl get namespace $NAMESPACE"

kubectl delete pods --selector="type=x11server" -n $NAMESPACE > $null
display_message_result "delete pods --selector=\"type=x11server\" -n $NAMESPACE"

# create abcdesktop.yaml file
if (Test-Path $ABCDESKTOP_YAML){
   display_message "use local file abcdesktop.yaml" "OK"
   $ABCDESKTOP_YAML="abcdesktop.yaml"
}
else{
   curl $ABCDESKTOP_YAML_SOURCE -OutFile abcdesktop.yaml
   display_message_result "downloaded source $ABCDESKTOP_YAML_SOURCE"
}

# Patching file is namespace has changed
if ("$NAMESPACE" -ne "abcdesktop"){
   # abcdesktop.yaml
   $path=".\abcdesktop.yaml"
   $content = Get-Content -Path $path
   # replace namespace: abcdesktop -> namespace: $NAMESPACE 
   $content = $content -replace 'namespace: abcdesktop', "namespace: $NAMESPACE"
   display_message_result "updated abcdesktop.yaml file with new namespace $NAMESPACE"
   Set-Content -Path $path -Value $content
}

kubectl delete -f abcdesktop.yaml -n $NAMESPACE
display_message_result "kubectl delete -f abcdesktop.yaml"
# delete cluster roles if updated
kubectl delete -f $ABCDESKTOP_CLUSTER_ROLE > $null 2> $null
kubectl delete secrets --all -n $NAMESPACE > $null
display_message_result "kubectl delete secrets --all -n $NAMESPACE"
kubectl delete cm --all -n $NAMESPACE > $null
display_message_result "kubectl delete configmap --all -n $NAMESPACE"
kubectl delete pvc --all -n $NAMESPACE > $null
display_message_result "kubectl delete pvc --all -n $NAMESPACE"
display_message "deleting namespace $NAMESPACE" "INFO"
$delete_message=$(kubectl delete namespace $NAMESPACE)
display_message_result "$delete_message"

display_message "delete abcdesktop related files" "INFO"
clean_files 
display_message "abcdesktop was succesfully uninstalled" "INFO"
