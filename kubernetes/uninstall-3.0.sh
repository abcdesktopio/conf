#!/bin/bash
START=$EPOCHSECONDS
echo "starting abcdesktop uninstall commands start at $START epoch seconds"
echo "stop and remove abcdesktop user pods"
kubectl delete pods --selector="type=x11server" -n abcdesktop
echo "remove all services, pods"
kubectl delete -f https://raw.githubusercontent.com/abcdesktopio/conf/main/kubernetes/abcdesktop-3.0.yaml 
echo "remove all secrets"
kubectl delete secrets --all -n abcdesktop
echo "remove all configmaps"
kubectl delete cm --all -n abcdesktop
echo "remove all pvc"
kubectl delete pvc --all -n abcdesktop 2>/dev/null
echo "remove all pv"
kubectl delete pv --all -n abcdesktop  2>/dev/null
echo "remove namespace"
kubectl delete namespace abcdesktop
TIMEDIFF=$(($EPOCHSECONDS - $START))
echo "abcdesktop is uninstalled, in $TIMEDIFF seconds"
