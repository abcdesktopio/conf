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



# install for release 3.0
#
# This file will be fetched as: curl -L https://raw.githubusercontent.com/abcdesktopio/conf/main/kubernetes/install-3.0.sh | sh -
# so it should be pure bourne shell
#
# run curl -L https://raw.githubusercontent.com/abcdesktopio/conf/main/kubernetes/install-3.0.sh | sh -
#

# define YAML path
ABCDESKTOP_YAML=abcdesktop.yaml
PODUSER_YAML=poduser.yaml

# current release
ABCDESKTOP_RELEASE=3.0

# docker hub prefix
REGISTRY_DOCKERHUB="docker.io/abcdesktopio"

# list of pod container image to prefetch
# ABCDESKTOP_POD_IMAGES="
# $REGISTRY_DOCKERHUB/oc.user.ubuntu:$ABCDESKTOP_RELEASE 
# $REGISTRY_DOCKERHUB/oc.pulseaudio:$ABCDESKTOP_RELEASE 
# $REGISTRY_DOCKERHUB/oc.cupsd:$ABCDESKTOP_RELEASE 
# docker.io/library/busybox:latest
# k8s.gcr.io/pause:3.8"


# Check if kubectl command is supported
# run command kubectl version
KUBE_VERSION=$(kubectl version --output=yaml)
EXIT_CODE=$?
if [ $EXIT_CODE -ne 0 ]; then
	echo "command 'kubectl version' failed"
	echo "Please install kubectl command first"
	exit $?
fi

# Check if kubectl command is supported
# run command kubectl version
OPENSSL_VERSION=$(openssl version)
EXIT_CODE=$?
if [ $EXIT_CODE -ne 0 ]; then
        echo "command 'openssl version' failed"
        echo "Please install openssl command first"
        exit $?
fi

# First create the abcdesktop namespace
kubectl create namespace abcdesktop
EXIT_CODE=$?
if [ $EXIT_CODE -eq 0 ]; then
        echo "abcdesktop namespace created"
fi


# RSA keys
# build rsa kay pairs for jwt payload 
# 1024 bits is a smallest value, change here if need but use more than 1024
if [ ! -f abcdesktop_jwt_desktop_payload_private_key.pem ]; then
	openssl genrsa -out abcdesktop_jwt_desktop_payload_private_key.pem 1024
	openssl rsa    -in  abcdesktop_jwt_desktop_payload_private_key.pem -outform PEM -pubout -out  _abcdesktop_jwt_desktop_payload_public_key.pem
	openssl rsa    -pubin -in _abcdesktop_jwt_desktop_payload_public_key.pem -RSAPublicKey_out -out abcdesktop_jwt_desktop_payload_public_key.pem
fi

# build rsa kay pairs for the desktop jwt signing
if [ ! -f abcdesktop_jwt_desktop_signing_private_key.pem ]; then
	openssl genrsa -out abcdesktop_jwt_desktop_signing_private_key.pem 1024
	openssl rsa    -in  abcdesktop_jwt_desktop_signing_private_key.pem -outform PEM -pubout -out abcdesktop_jwt_desktop_signing_public_key.pem
fi

# build rsa kay pairs for the user jwt signing 
if [ ! -f abcdesktop_jwt_user_signing_private_key.pem ]; then
	openssl genrsa -out abcdesktop_jwt_user_signing_private_key.pem 1024
	openssl rsa    -in  abcdesktop_jwt_user_signing_private_key.pem -outform PEM -pubout -out abcdesktop_jwt_user_signing_public_key.pem
fi

# Import RSA Keys as Kubernetes secrets 
kubectl create secret generic abcdesktopjwtdesktoppayload --from-file=abcdesktop_jwt_desktop_payload_private_key.pem --from-file=abcdesktop_jwt_desktop_payload_public_key.pem --namespace=abcdesktop
kubectl create secret generic abcdesktopjwtdesktopsigning --from-file=abcdesktop_jwt_desktop_signing_private_key.pem --from-file=abcdesktop_jwt_desktop_signing_public_key.pem --namespace=abcdesktop
kubectl create secret generic abcdesktopjwtusersigning    --from-file=abcdesktop_jwt_user_signing_private_key.pem    --from-file=abcdesktop_jwt_user_signing_public_key.pem    --namespace=abcdesktop
kubectl label  secret abcdesktopjwtdesktoppayload abcdesktop/role=desktop.payloadkeys -n abcdesktop
kubectl label  secret abcdesktopjwtdesktopsigning abcdesktop/role=desktop.signingkeys -n abcdesktop
kubectl label  secret abcdesktopjwtusersigning    abcdesktop/role=user.signingkeys    -n abcdesktop
 
echo "Downloading file abcdesktop.yaml if need" 
# create abcdesktop.yaml file
if [ -f abcdesktop.yaml ]; then
   echo "kubernetes use local directory abcdesktop.yaml file"
   ABCDESKTOP_YAML=abcdesktop.yaml
else
   curl https://raw.githubusercontent.com/abcdesktopio/conf/main/kubernetes/abcdesktop-3.0.yaml --output abcdesktop.yaml
fi

echo "Downloading file od.config if need" 
# create od.config file
if [ -f od.config ]; then
   echo "abcdesktop use local directory od.config file"
else
   curl https://raw.githubusercontent.com/abcdesktopio/conf/main/reference/od.config.3.0 --output od.config
fi


echo "Downloading file poduser.yaml if need"
# create poduser.yaml file
if [ -f poduser.yaml ]; then
   echo "kubernetes use local directory poduser.yaml file"
   PODUSER_YAML=poduser.yaml
else
   curl https://raw.githubusercontent.com/abcdesktopio/conf/main/kubernetes/poduser.yaml --output poduser.yaml
fi

echo "kubectl create configmap abcdesktop-config --from-file=od.config -n abcdesktop"
kubectl create configmap abcdesktop-config --from-file=od.config -n abcdesktop

EXIT_CODE=$?
if [ $EXIT_CODE -eq 0 ]
then
	kubectl label configmap abcdesktop-config abcdesktop/role=pyos.config -n abcdesktop
        echo "kubectl create configmap abcdesktop-config command was successful"
else
        echo "kubectl create configmap abcdesktop-config failed"
fi

echo "create a sample pod user for images pulling"
kubectl create -f $PODUSER_YAML
EXIT_CODE=$?
if [ $EXIT_CODE -eq 0 ]
then
  	echo "kubectl create -f $PODUSER_YAML command was successful"
else
        echo "kubectl create -f $PODUSER_YAML failed"
        exit $?
fi
echo "waiting for pod/anonymous-74bea267-8197-4b1d-acff-019b24e778c5 Ready"
kubectl wait --for=condition=Ready pod/anonymous-74bea267-8197-4b1d-acff-019b24e778c5  -n abcdesktop --timeout=-1s
kubectl delete -f $PODUSER_YAML

echo "kubectl create -f $ABCDESKTOP_YAML"
kubectl create -f $ABCDESKTOP_YAML
EXIT_CODE=$?
if [ $EXIT_CODE -eq 0 ]; then
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
ABCDESKTOP_SERVICES=$(kubectl get pods --selector=name=nginx-od -o jsonpath={.items..status.hostIP} -n abcdesktop)
echo "and replace [your-ip-hostname] by your default server ip address"
echo "The abcdesktop url should be:"
for srv in $ABCDESKTOP_SERVICES
do
   URL=http://$srv:30443/
   echo "$URL"
done

