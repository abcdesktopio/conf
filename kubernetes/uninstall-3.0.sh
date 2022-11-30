echo "starting abcdesktop uninstall commands"
echo "stop and remove abcdesktop user pods"
kubectl delete pods --selector="type=x11server" -n abcdesktop
echo "remove all services, pods"
kubectl delete -f https://raw.githubusercontent.com/abcdesktopio/conf/main/kubernetes/abcdesktop.yaml
echo "remove all secrets"
kubectl delete secrets --all -n abcdesktop
echo "remove all configmaps"
kubectl delete cm --all -n abcdesktop
echo "remove all pvc"
kubectl delete pvc --all -n abcdesktop
echo "remove all pv"
kubectl delete pv --all -n abcdesktop
echo "remove namespace"
kubectl delete namespace abcdesktop
echo "abcdesktop is uninstalled"
