#!/bin/bash
# install abcdesktop
echo install abcdesktop
sudo conf/docker/install.sh
#
echo sleeping for 30 s
sleep 30
#
echo start newman runs
#
newman run conf/postman-collections/login.anonymous.json
