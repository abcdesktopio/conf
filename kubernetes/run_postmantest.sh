#!/bin/bash
# get the nginx pod name
NGINX_POD=$(kubectl get pods -l run=nginx-od  --template '{{range .items}}{{.metadata.name}}{{"\n"}}{{end}}' -n abcdesktop)
echo "nginx pod name is $NGINX_POD"
# run test
kubectl debug -it -n abcdesktop $NGINX_POD --image=abcdesktopio/oc.postmantest:main -- /docker-entrypoint.sh
