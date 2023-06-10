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


# gimp.d.$ABCDESKTOP_RELEASE.json

URL_APPLICATION_CONF_SOURCE="https://raw.githubusercontent.com/abcdesktopio/oc.apps/main"
# list of json default applications to prefetch
ABCDESKTOP_JSON_APPLICATIONS="
2048-alpine.d.$ABCDESKTOP_RELEASE.json
xterm.d.$ABCDESKTOP_RELEASE.json
writer.d.$ABCDESKTOP_RELEASE.json
firefox.d.$ABCDESKTOP_RELEASE.json
nautilus.d.$ABCDESKTOP_RELEASE.json
geany.d.$ABCDESKTOP_RELEASE.json
qterminalpod.d.$ABCDESKTOP_RELEASE.json
evince.d.$ABCDESKTOP_RELEASE.json
"

BASE_PORT=30443
INCREMENT=1
port=$BASE_PORT
if ! [ -x "$(command -v netstat)" ]; then
  echo "netstat is not installed. I'm using port=$port" >&2
else
  isfree=$(netstat -taln |grep $port)
  if [ ! -z "$isfree" ]; then
    while [[ -n "$isfree" ]]; do
      port=$[port+INCREMENT]
      isfree=$(netstat -taln |grep $port)
    done
  fi
fi
echo "Forwarding abcdesktop service for you on port=$port"



# Check if kubectl command is supported
# run command kubectl version
KUBE_VERSION=$(kubectl version --output=yaml)
EXIT_CODE=$?
if [ $EXIT_CODE -ne 0 ]; then
	echo "Command 'kubectl version' failed"
	echo "Please install kubectl command first"
	exit $?
fi

echo "get the nginx pod name"
NGINX_POD_NAME=$(kubectl get pods -l run=nginx-od -o jsonpath={.items..metadata.name} -n abcdesktop)
EXIT_CODE=$?
if [ $EXIT_CODE -ne 0 ]; then
 	echo "Command 'kubectl get pods -l run=nginx-od -o jsonpath={.items..metadata.name} -n abcdesktop' failed"
        echo "Check result"
        exit $?
fi

echo "nginx pod name=$NGINX_POD_NAME"
echo "starting port-forward on tcp port $port"
echo kubectl port-forward $NGINX_POD_NAME --address 0.0.0.0 $port:80 -n abcdesktop 
rm -f port_forward
kubectl port-forward $NGINX_POD_NAME --address 0.0.0.0 $port:80 -n abcdesktop > port_forward & 
PORT_FORWARD_PID=$! 
echo "kubectl port-forward $NGINX_POD_NAME get pid $PORT_FORWARD_PID"
echo "waiting for pid $PORT_FORWARD_PID" 
while [ ! -f port_forward ]
do 
  echo "." 
  sleep 1
done

# define service URL
URL="http://localhost:$port/API/manager/image"

# call HEALTZ
EXIT_CODE=$?
if [ $EXIT_CODE -eq 0 ]; then
  echo "## this process wil take several minutes to complete ##"
  for app in $ABCDESKTOP_JSON_APPLICATIONS
  do
      echo "Downloading $URL_APPLICATION_CONF_SOURCE/$app"
      curl -sL --output $app  $URL_APPLICATION_CONF_SOURCE/$app
      echo "Pushing $app to $URL" 
      curl -X PUT -H 'Content-Type: text/javascript' $URL -d @$app
      pods=$(kubectl -n abcdesktop get pods --selector=type=pod_application_pull --template '{{range .items}}{{.metadata.name}}{{"\n"}}{{end}}')
      echo ""
      echo "list of created pods for pulling is: "
      echo "$pods"
      echo "waiting for all pods condition Ready. timeout=-1s (it will take a while)"
      kubectl wait --for=condition=Ready pods --selector=type=pod_application_pull --timeout=-1s -n abcdesktop
      kubectl delete pod --selector=type=pod_application_pull -n abcdesktop
  done
  kill $PORT_FORWARD_PID
  echo "$ABCDESKTOP_JSON_APPLICATIONS"
  echo "all applications are ready to use"
else
  echo "abcdesktop is not ready"	
  PYOS_POD_NAME=$(kubectl get pods -l run=pyos-od -o jsonpath={.items..metadata.name} -n abcdesktop)
  echo "Somethings goes wrong with this pod $PYOS_POD_NAME or with $NGINX_POD_NAME"
  kubectl logs $PYOS_POD_NAME -n abcdesktop
fi
