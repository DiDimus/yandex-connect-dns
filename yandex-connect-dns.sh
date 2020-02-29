#!/usr/bin/env bash
# ############
# This scripts changes A-records default
# To change MX, AAAA, SRV etc. write this at first arg.
# ############

PATH=/sbin:/bin:/usr/sbin:/usr/bin:/usr/local/sbin:/usr/local/bin; export PATH
IFS=$'\n'
############ Functions ############

get_domain_records() {
    response=$( curl -s -H "PddToken: ${DOMAIN_TOKEN}" "https://pddimp.yandex.ru/api2/admin/dns/list?domain=${DOMAIN_NAME}" )
    records_id=( $(jq -r '.records[].record_id' <<< ${response}) )
    fqdns=( $(jq -r '.records[].fqdn' <<< ${response}) )
    types=( $(jq -r '.records[].type' <<< ${response}) )
    contents=( $(jq -r '.records[].content' <<< ${response}) )
    subdomains=( $(jq -r '.records[].subdomain' <<< ${response}) )
}

get_content() { #first arg is a subdomain
    for i in ${!records_id[@]}; do
      if [[ ${subdomains[$i]} == $1 && ${types[$i]} == ${defType}  ]]; then
        echo "${contents[$i]}"
      fi
   done
}
get_settings() { #first arg is a key string
    for line in $(cat settings.ini)
        do
            if [[ $(echo $line | cut -d: -f1) == $1 ]]; then
            echo $line | cut -d: -f2
            fi
        done
}

select_record_id() { # first arg is a subdomain
    for i in ${!records_id[@]}; do
      if [[ ${subdomains[$i]} == $1 && ${types[$i]} == ${defType}  ]]; then
        echo "${records_id[$i]}"
      fi
   done
}

update_domain_record() { # first arg is a subdomain
    record_id=$(select_record_id $1)
    edit=$( curl -s -H "PddToken: ${DOMAIN_TOKEN}" -d "domain=${DOMAIN_NAME}&record_id=${record_id}&subdomain=${1}&ttl=${ttl}&content=${MYIP}" "https://pddimp.yandex.ru/api2/admin/dns/edit")
}

############ END FUNCTIONS ######
############ Scripts       ############
# File log
LOG=/var/log/ip.log
# Domain name
DOMAIN_NAME=$(get_settings DOMAIN_NAME)
# Get token here - https://pddimp.yandex.ru/api2/admin/get_token
DOMAIN_TOKEN=$(get_settings DOMAIN_TOKEN)
# Show your real IP
MYIP=`curl -s 'http://checkip.dyndns.org' | sed 's/.*Current IP Address: \([0-9\.]*\).*/\1/g'`
# Get IP in DNS
#NSIP=`host kurazhov.ru dns1.yandex.ru | grep "has address" | awk '{print $4}' 2>>$LOG`
#NSIP="8.8.8.8"
ttl="3600"
defType="A"
get_domain_records
NSIP=$(get_content "@")
if [[ $MYIP != $NSIP ]]; then
    if [ -f ./settings.ini ]; then
       update_domain_record "@"
       update_domain_record "www"
    else
        echo "settings.ini doesn't exist. Create them."
    fi
else
    echo "IP not changed"
fi
exit 0
