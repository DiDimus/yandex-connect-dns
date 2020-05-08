#!/usr/bin/env bash
# ############
# This script change A-record as default
# First argument is a action, second - is a domain name, third argument may be another DNS type.
# For example, to update AAAA record write this at second arg: "bash yandex-connect-dns.sh update domain.com AAAA"
# ############

PATH=/sbin:/bin:/usr/sbin:/usr/bin:/usr/local/sbin:/usr/local/bin; export PATH
IFS=$'\n'
############ Functions ############

get_domain_records() { # first arg is a domain name, second - domain token
    response=$( curl -s -H "PddToken: ${2}" "https://pddimp.yandex.ru/api2/admin/dns/list?domain=${1}" )
    records_id=( $(jq -r '.records[].record_id' <<< ${response}) )
    fqdns=( $(jq -r '.records[].fqdn' <<< ${response}) )
    types=( $(jq -r '.records[].type' <<< ${response}) )
    contents=( $(jq -r '.records[].content' <<< ${response}) )
    subdomains=( $(jq -r '.records[].subdomain' <<< ${response}) )
}

get_domain_token() { # first arg is a domain
    for line in $(cat settings.ini)
        do
            if [[ $(echo $line | cut -d: -f1) == $1 ]]; then
            echo $line | cut -d: -f2
            break
            fi
        done
}

update_domain_record() { # first arg is a record_id, second - subdomain
    if [[ $1 != "" ]]; then
        edit=$( curl -s -H "PddToken: ${DOMAIN_TOKEN}" -d "domain=${DOMAIN_NAME}&record_id=${1}&subdomain=${2}&ttl=${ttl}&content=${MYIP}" "https://pddimp.yandex.ru/api2/admin/dns/edit")
    else
        echo -e "Error: Subdomain $1 in $defType doesn't exist."
        break
    fi
}
update_all() { # read all content settings.ini
    for line in $(cat settings.ini)
        do
            DOMAIN_NAME=`echo $line | cut -d: -f1`
            DOMAIN_TOKEN=`echo $line | cut -d: -f2`
            get_domain_records $DOMAIN_NAME $DOMAIN_TOKEN
            for i in ${!subdomains[@]}; do
                if [[ ${types[$i]} == $defType ]]; then
                    update_domain_record ${records_id[$i]} ${subdomains[$i]}
                fi
            done
        done
}

############ END FUNCTIONS ######
############ Scripts       ############
# File log
LOG=/var/log/ip.log
if [[ ! -f ./settings.ini ]]; then
    echo "settings.ini doesn't exist. Create them."
    exit 1
fi

# Get your real IPv4
MYIP=`curl -s 'http://checkip.dyndns.org' | sed 's/.*Current IP Address: \([0-9\.]*\).*/\1/g'`
ttl="3600"
defType="A"
case $# in
    0)
    #update_all
    ;;
    1)
        case $1 in
        update) update_all;;
        add) echo "Please, specify subdomain and domain.";;
        *);;
    2)
      case $1 in 
        
    # Get token here - https://pddimp.yandex.ru/api2/admin/get_token
    DOMAIN_TOKEN=$(get_domain_token $2)
    DOMAIN_NAME=$2
    get_domain_records $2 $DOMAIN_TOKEN
    for i in ${!types[@]}; do
        if [[ ${types[$i]} == $defType && ${contents[$i]} != $MYIP ]]; then
            update_domain_record ${records_id[$i]} ${subdomains[$i]}
            echo -e "IP ${contents[$i]} changed to $MYIP for subdomain ${subdomains[$i]}"
        fi
    done
    ;;
    3)
    defType=$3
    if [[ $3 == "AAAA" ]]; then MYIP=`curl -s 'http://ip6only.me/api/' | cut -d, -f2`; fi
    # Get token here - https://pddimp.yandex.ru/api2/admin/get_token
    DOMAIN_TOKEN=$(get_domain_token $2)
    DOMAIN_NAME=$2
    get_domain_records $2 $DOMAIN_TOKEN
    for i in ${!types[@]}; do
        if [[ ${types[$i]} == $2 && ${contents[$i]} != $MYIP  ]]; then
            update_domain_record ${records_id[$i]} ${subdomains[$i]}
            echo -e "`date \"+%Y%m%d %H:%M\"` IP ${contents[$i]} changed to $MYIP for subdomain ${subdomains[$i]} in domain $1" >> $LOG
        fi
    done
    ;;
    *) ;;
esac
exit 0
