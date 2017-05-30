#!/bin/bash -e
# set -v
# set -x
while getopts ":cun:m:sih" opt; do
  case $opt in
    c)
      create="true"
      ;;
    u)
      update="true"
      ;;
    n)
      origin_name=$OPTARG
      ;;
    m)
      saml_metadata_file=$OPTARG
      ;;
    s)
      skip_tidy="true"
      ;;
    i)
      skip_ssl="true"
      ;;

    h )
      echo "Usage:"
      echo -e "     -h   Display this help message.\n"
      echo "     -c   create."
      echo "     -u   update."
      echo "     -n   SAML SP name ."
      echo "     -m   SAML metadata from SP."
      exit 0
      ;;
    \?)
      echo "Invalid option: -$OPTARG" >&2
      exit 1
      ;;
    :)
      echo "Option -$OPTARG requires an argument." >&2
      exit 1
      ;;
    *)
      if [ "$OPTERR" != 1 ] || [ "${OPTSPEC:0:1}" = ":" ]; then
          echo "Non-option argument: '-${OPTARG}'" >&2
      fi
      ;;
    esac
done

if [[ -z "$origin_name" ]]; then
    echo "You must specify the origin name with option -n."
    exit 1
fi

set +e
echo $origin_name | grep ^.*[\]\^\:\ \?\/\@\#\[\{\}\!\$\&\'\(\)\*\+\,\;\=\~\`\%\|\<\>\"].*$
#A status code of 0 means that there was a special character in the origin name.
if [ $? == 0 ]; then
    echo "Origin name $origin_name contains special characters. Remove the special characters and retry."
    exit 1
fi
set -e

if [[ -z "$saml_metadata_file" ]]; then
    echo "You must specify the idp config file with option -m."
    exit 1
fi


config_left='{"metaDataLocation" : "'
# right='","emailDomain":'"$config_email_domain_file"',"idpEntityAlias":"'"$origin_name"'","nameID":"'"$nameid_format"'","assertionConsumerIndex":0,"metadataTrustCheck":false,"showSamlLink":true,"socketFactoryClassName":"org.apache.commons.httpclient.protocol.DefaultProtocolSocketFactory","linkText":"'"$link_text"'","iconUrl":null,"groupMappingMode":"'"$group_mapping_mode"'","addShadowUserOnLogin":"'"$add_shadow_user_on_login"'","externalGroupsWhitelist":'"$groups_list"',"attributeMappings":'"$config_mapping"'}'
config_right='","metadataTrustCheck" : true}'

esc_left=$(echo ${config_left} | sed 's/"/\\"/g')
esc_right=$(echo ${config_right} | sed 's/"/\\"/g')

# dos2unix for stupid OSX that doesn't have dos2unix
config_middle=$(<$saml_metadata_file)

# formats the xml
# if [[ -z $skip_tidy ]]; then
#   echo "Tidy XML"
#   esc_middle_1=$(echo "$esc_middle_0" | tidy -xml -i - | col -b)
#   ${LINES[@]}
# else
#   echo "DO NOT Tidy XML"
#   esc_middle_1=$esc_middle_0
# fi

# Replaces all \ with \\\\
esc_middle_1=$(echo "$config_middle" | sed 's/\\/\\\\\\\\/g')
# Replaces all quotes with \\\"
esc_middle_2=$(echo "$esc_middle_1" | sed 's/"/\\\\\\"/g')
# Replaces all newlines with \\n
# esc_middle_3=$(echo "$esc_middle_2" | awk '$1=$1' ORS='\\\\n')
#remove \n at the end of each line
esc_middle_3=$(echo "$esc_middle_2" | tr -d '\n' | tr -d '\r')

esc_middle=$esc_middle_3

config="$esc_left$esc_middle$esc_right"

# data='{"originKey":"'"$origin_name"'","name":"'"$origin_name"'","type":"saml","config":"'"$config"'","active":true}'
data='{"name":"'"$origin_name"'","active":true,"config":"'"$config"'"}'

# echo "$data"
echo "Create: $create, Update: $update"
if [[ $create ]]; then
  echo -e "\n################\nCREATING NEW\n"
  uaac curl /saml/service-providers -t -X POST -H "Content-Type:application/json;charset=UTF-8" -d "$data"
elif [[ $update ]]; then
  echo -e "\n################\nUPDATING\n"
  uaac curl /saml/service-providers/da19d61a-46a6-4950-b3b0-648868a6303f -t -X PUT -H "Content-Type:application/json;charset=UTF-8" -d "$data"
fi
