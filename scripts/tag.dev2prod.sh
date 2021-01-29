#/bin/bash

corefiles=( "oc.pyos" "oc.nginx" "oc.mongo" "oc.user.18.04" "oc.pulseaudio.18.04" "oc.cupsd.18.04" )

for i in "${corefiles[@]}"
do
	docker pull abcdesktopio/$i:dev
 	docker tag abcdesktopio/$i:dev abcdesktopio/$i
	docker push abcdesktopio/$i
done


while read i; do
  	docker pull abcdesktopio/$i:dev
        docker tag abcdesktopio/$i:dev abcdesktopio/$i
        docker push abcdesktopio/$i
done < ../images-list.txt

