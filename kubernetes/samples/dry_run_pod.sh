

ABCDESKTOP_URL=http://localhost:30443

# do login
json_login=$(curl -X POST $ABCDESKTOP_URL/API/auth/auth  -H 'Content-Type: application/json' -d '{ "manager": null, "provider": "anonymous"}')
jwt_user_token=$(echo $json_login|jq -r .result.jwt_user_token)
abcauthorization="Bearer $jwt_user_token"
#echo "HEADER=$abcauthorization"

# get a dry_run pod 
# sampledesktop is dry_run
json_pod=$(curl -X POST $ABCDESKTOP_URL/API/manager/dry_run_desktop -H 'Content-Type: application/json' -H "Abcauthorization: $abcauthorization"  -d '{}') 

# logout
logout=$(curl -X POST $ABCDESKTOP_URL/API/auth/logout -H 'Content-Type: application/json' -H "Abcauthorization: $abcauthorization"  -d '{}')
# echo "logout=$logout"

echo "$json_pod"


