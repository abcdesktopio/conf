#!/bin/bash

corefiles=( "oc.pyos" "oc.nginx" "oc.mongo" "oc.user.18.04" "oc.pulseaudio.18.04" "oc.cupsd.18.04" )

for i in "${corefiles[@]}"
do
	echo "-> docker pull abcdesktopio/$i:dev"
	docker pull abcdesktopio/$i:dev
	echo "-> docker tag abcdesktopio/$i:dev abcdesktopio/$i"
 	docker tag abcdesktopio/$i:dev abcdesktopio/$i
	echo "-> docker push abcdesktopio/$i"
	docker push abcdesktopio/$i
done

wget -O images-list.txt https://raw.githubusercontent.com/abcdesktopio/conf/main/images-list.txt
while read i; do
  	docker pull abcdesktopio/$i:dev
        docker tag abcdesktopio/$i:dev abcdesktopio/$i
        docker push abcdesktopio/$i
done < images-list.txt

