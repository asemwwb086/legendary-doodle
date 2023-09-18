#!/bin/bash

url="$1"

#prompt for url if not provided
until [ ! -z "$url" ] ; do
  read -p "url=" url
done

id=$(sed 's|.*gofile.io/d/||g' <<< "$url")
echo "Downloading $id"

#get guest account token for url and cookie
token=$(curl -s 'https://api.gofile.io/createAccount' | jq -r '.data.token' 2>/dev/null)
[ "$?" -ne 0 ] && echo "Creating guest account failed, please try again later"

#get website token for url
websiteToken=$(curl -s 'https://gofile.io/dist/js/alljs.js' | grep websiteToken | awk '{ print $3 }' | jq -r)
[ "$?" -ne 0 ] && echo "Getting website token failed, please try again later"

#get content info from api
resp=$(curl 'https://api.gofile.io/getContent?contentId='"$id"'&token='"$token"'&websiteToken='"$websiteToken"'&cache=true' 2>/dev/null)
code="$?"

#prompt for password if required
if [[ $(jq -r '.status' <<< "$resp" 2>/dev/null) ==  "error-passwordRequired" ]] ; then
  until [ ! -z "$password" ] ; do
    read -p "password=" password
    password=$(printf "$password" | sha256sum | cut -d' ' -f1)

    resp=$(curl 'https://api.gofile.io/getContent?contentId='"$id"'&token='"$token"'&websiteToken='"$websiteToken"'&cache=true&password='"$password" 2>/dev/null)
    code="$?"
  done
fi

#verify content info was retrieved successfully
[ "$code" -ne 0 ] && echo "URL unreachable, check provided link" && exit 1

#create download folder
#mkdir "$id" 2>/dev/null
#cd "$id"

#load the page once so download links don't get redirected
curl -H 'Cookie: accountToken='"$token" "$url" -o /dev/null 2>/dev/null
[ "$?" -ne 0 ] && echo "Loading page failed, check provided link"

for i in $(jq '.data.contents | keys | .[]' <<< "$resp"); do
  name=$(jq -r '.data.contents['"$i"'].name' <<< "$resp")
  url=$(jq -r '.data.contents['"$i"'].link' <<< "$resp")
  
  #download file if not already downloaded
  if [ ! -f "$name" ] ; then
    echo
    echo "Downloading $name"
    aria2c -x 10 --header='Cookie: accountToken='"$token" "$url"
#    curl -H 'Cookie: accountToken='"$token" "$url" -o "$name"
    [ "$?" -ne 0 ] && echo "Downloading ""$filename"" failed, please try again later" && rm "$filename"
  fi
done

echo
echo
echo "Note: gofile.io is entirely free with no ads,"
echo "you can support it at https://gofile.io/donate"
