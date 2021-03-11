#!/bin/bash
wget -O images-list.txt https://raw.githubusercontent.com/abcdesktopio/conf/main/images-list.txt
while read i; do
        docker pull abcdesktopio/$i
done < images-list.txt
