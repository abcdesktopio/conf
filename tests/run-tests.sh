#!/bin/bash
VERSION="3.3"
ABCDESKTOP_YAML_SOURCE="https://raw.githubusercontent.com/abcdesktopio/conf/main/kubernetes/abcdesktop-$VERSION.yaml"

#downloading abcdesktop.yaml file
curl --progress-bar "$ABCDESKTOP_YAML_SOURCE" --output abcdesktop.yaml

#create a temporary file to store the output
temp_file=$(mktemp)

echo "installing abcdesktop"

#install deploy abcdesktop locally on the container
curl -sL https://raw.githubusercontent.com/abcdesktopio/conf/main/kubernetes/install-$VERSION.sh | bash > "$temp_file" 2>&1

#print abcdesktop install output
cat "$temp_file"

if [ $? -ne 0 ]; then
    echo "abcdesktop install script failed to execute."
    exit 1
fi

#extract the abcdesktop URL
url=$(grep -oP 'http://[0-9.]+:[0-9]+/' "$temp_file" | tail -n 1)

#clean up the temporary file
rm "$temp_file"

#check if the URL was successfully extracted
if [ -z "$url" ]; then
    echo "Failed to retrieve the abcdesktop URL"
    exit 1
fi

cd tests

#run the acutal test
npm run test -- --url="$url"