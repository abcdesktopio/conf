#!/bin/bash
#
#
# bash script user_counter.sh
# count for each running pod with the label type=x11server the user's connection
#  
# the return value is formated as
# user_counter: $user_counter
#

list_user_pod=$(kubectl get pods --selector=type=x11server --field-selector=status.phase=Running --output=jsonpath={.items..metadata.name}  -n abcdesktop )
user_counter=0
for user_pod in $list_user_pod;
do
	count=$(kubectl exec -n abcdesktop $user_pod -- /composer/connectcount.sh 2>/dev/null)
	echo "pod $user_pod has $count"
	user_counter=$(($user_counter + $count))
done
echo "user_counter: $user_counter"
