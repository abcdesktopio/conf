

ABCDESKTOP_URL=http://localhost:30443

# do login
json_login=$(curl -X POST $ABCDESKTOP_URL/API/auth/auth  -H 'Content-Type: application/json' -d '{ "manager": null, "provider": "anonymous"}')
jwt_user_token=$(echo $json_login|jq -r .result.jwt_user_token)
abcauthorization="Bearer $jwt_user_token"
#echo "HEADER=$abcauthorization"
echo "json_login=$json_login"
# launch a pod 
desktop_pod=$(curl -X POST $ABCDESKTOP_URL/API/composer/launchdesktop -H 'Content-Type: application/json' -H "Abcauthorization: $abcauthorization"  -d '{}')
echo "desktop_pod=$desktop_pod"

# logout
logout=$(curl -X POST $ABCDESKTOP_URL/API/auth/logout -H 'Content-Type: application/json' -H "Abcauthorization: $abcauthorization"  -d '{}')
# echo "logout=$logout"
echo "logout=$logout"



