#!/bin/bash
echo "starting abcdesktop uninstall commands"
START=$EPOCHSECONDS
if [ ! -z "$START" ]; then
  echo "at $START epoch seconds"
fi
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
# echo "remove all pv"
# kubectl delete pv --all -n abcdesktop  2>/dev/null
echo "remove namespace"
kubectl delete namespace abcdesktop
if [ ! -z "$START" ]; then
  TIMEDIFF=$(expr $EPOCHSECONDS - $START)
  echo "the process takes $TIMEDIFF seconds to complete"
fi
echo "abcdesktop is uninstalled"
