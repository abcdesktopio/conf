#!/bin/bash

# need
# wget
# kubectl
# docker
# touch

# set default tcp port dockerd value
DOCKERD_PORT=2375
TAG="${TAG:-latest}"


if [ ! -f images-list.txt ]; then
	wget -O images-list.txt https://raw.githubusercontent.com/abcdesktopio/conf/main/images-list.txt
fi

if [ ! -f images-deny.txt ]; then
	touch images-deny.txt
fi

# list abcdesktop compute nodes
KUBE_NODE=$(kubectl get nodes -l abcdesktoptype=worker  --no-headers -o custom-columns=":metadata.name")
SERVERS=($(echo "$KUBE_NODE" | tr ' ' '\n'))


# some var dump
echo "Default tag image tag=$TAG"
echo "Dump compute node list:"
# run clean up
for server in "${SERVERS[@]}";
do
 echo "$server"
done

# run clean up
for server in "${SERVERS[@]}";
do
  echo "Cleaning $server:$DOCKERD_PORT" 
  docker -H $server:$DOCKERD_PORT rmi `docker -H $server:$DOCKERD_PORT images -q --filter "dangling=true"`
done

while read i; do
	if grep -q "$i" images-deny.txt; then
    		echo "skiping $i, matches in deny file"
	else
		for server in "${SERVERS[@]}";
		do
			echo "docker -H $server:$DOCKERD_PORT  pull abcdesktopio/$i:$TAG"
        		docker -H $server:$DOCKERD_PORT pull abcdesktopio/$i:$TAG
		done
	fi
done < images-list.txt

for server in "${SERVERS[@]}";
do
 while read i; do
	echo "docker -H $server:$DOCKERD_PORT rmi abcdesktopio/$i:$TAG"
	docker -H $server:$DOCKERD_PORT  rmi abcdesktopio/$i
 done < images-deny.txt
done

for server in "${SERVERS[@]}";
do
	echo "Cleaning $server:$DOCKERD_PORT"
        docker -H $server:$DOCKERD_PORT  rmi `docker -H $server:$DOCKERD_PORT  images -q --filter "dangling=true"`
done
