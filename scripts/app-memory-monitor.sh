#/bin/bash
while true;
do
        tdata=$(date +%T)
        cdata=$(docker stats  --no-stream  --format  "{{ .MemUsage }};"  $1 | awk  '{print $1}')
        echo "$tdata;$cdata"
        sleep 1
done
