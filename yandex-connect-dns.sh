#!/usr/bin/env bash
# ############
# This script change A-record as default
# First argument is a action, second - is a domain name, third argument may be another DNS type.
# For example, to update AAAA record write this at second arg: "bash yandex-connect-dns.sh update domain.com AAAA"
# ############
# This is version 2
PATH=/sbin:/bin:/usr/sbin:/usr/bin:/usr/local/sbin:/usr/local/bin; export PATH
IFS=$'\n'
############ Functions ############

get_domain_records() { # first arg is a domain name, second - domain token
    response=$( curl -s -H "PddToken: ${2}" "https://pddimp.yandex.ru/api2/admin/dns/list?domain=${1}" )
    if [[ $(jq -r '.success' <<< ${response}) == "ok" ]]; then
        records_id=( $(jq -r '.records[].record_id' <<< ${response}) )
        fqdns=( $(jq -r '.records[].fqdn' <<< ${response}) )
        types=( $(jq -r '.records[].type' <<< ${response}) )
        contents=( $(jq -r '.records[].content' <<< ${response}) )
        subdomains=( $(jq -r '.records[].subdomain' <<< ${response}) )
    elif [[ $(jq -r '.success' <<< ${response}) == "error" ]]; then
        CODE=$(jq -r '.error' <<< ${response})
        case $CODE in
            unknown) echo "Произошел временный сбой или ошибка работы API (повторите запрос позже).";;
            no_token | no_domain | no_ip) echo "Не передан обязательный параметр.";;
            bad_domain) echo "Имя домена не указано или не соответствует RFC1035.";;
            prohibited) echo "Запрещенное имя домена.";;
            bad_token | bad_login | bad_passwd) echo "Передан неверный ПДД-токен (логин, пароль).";;
            no_auth) echo "Не передан заголовок PddToken.";;
            not_allowed) echo "Пользователю недоступна данная операция (он не является администратором этого домена).";;
            blocked) echo "Домен заблокирован (например, за спам и т.п.).";;
            occupied) echo "Имя домена используется другим пользователем.";;
            domain_limit_reached) echo "Превышено допустимое количество подключенных доменов (50).";;
            no_reply) echo "Яндекс.Почта для домена не может установить соединение с сервером-источником для импорта.";;
           *);;
        esac
        exit 1
    fi
}

get_domain_token() { # first arg is a domain
    for settings in $(cat $SCRIPT_DIR/settings.ini)
        do
            if [[ $(echo $settings | cut -d: -f1) == $1 ]]; then
            echo $settings | cut -d: -f2
            break
            fi
        done
}
get_my_IP() { # first arg is a type
if [[ $1 == "A" ]]; then
    echo $(curl -s 'http://checkip.dyndns.org' | sed 's/.*Current IP Address: \([0-9\.]*\).*/\1/g')
elif [[ $1 == "AAAA" ]]; then
    echo $(curl -s 'http://ip6only.me/api/' | cut -d, -f2)
fi
}

add_domain_record() { # first arg is a subdomain
    if [[ $1 != "" ]]; then
        edit=$( curl -s -H "PddToken: ${DOMAIN_TOKEN}" -d "domain=${DOMAIN_NAME}&type=${defType}&subdomain=${1}&ttl=${ttl}&content=${MYIP}" "https://pddimp.yandex.ru/api2/admin/dns/add" )
    else
        echo -e "Error: Subdomain $1 in $defType doesn't exist."
        break
    fi

}

update_domain_record() { # first arg is a record_id, second - subdomain
    if [[ $1 != "" ]]; then
        edit=$( curl -s -H "PddToken: ${DOMAIN_TOKEN}" -d "domain=${DOMAIN_NAME}&record_id=${1}&subdomain=${2}&ttl=${ttl}&content=${MYIP}" "https://pddimp.yandex.ru/api2/admin/dns/edit")
    else
        echo -e "Error: Subdomain $1 in $defType doesn't exist."
        break
    fi
}

usage() {
echo -e "###############\n"
echo -e "To update current records in your own domain"
echo -e "\"$0 update example.com [A|AAAA]\"\n"
echo -e "To update current records in your own domain exclude some subdomains"
echo -e "\"$0 update example.com [A|AAAA] --exclude=subdomain1,subdomain2...,subdomainN\"\n"
echo -e "This script update change A-record as default"
echo -e "To add subdomain to your own domain"
echo -e "\"$0 add example.com <A|AAAA|MX|SRV|TXT|NS|CNAME> <new_subdomain>\"\n"
echo -e "###############"
exit 0
}


############ END FUNCTIONS ######
############ Scripts       ############
# File log
LOG=/var/log/ip.log
SCRIPT_DIR=$( dirname "$0" )
if [[ ! -f $SCRIPT_DIR/settings.ini ]]; then
    echo "settings.ini doesn't exist. Create them."
    exit 1
fi
if [[ $# == 0 ]]; then
    usage
fi
ttl="3600"
defType="A"

case $1 in
    "add")
        if [[ $# != 4 ]]; then
            echo -e "Error: You must specify a domain, type and new subdomain.\nFor help enter \"$0 --help\" "
            exit 1
        else
            DOMAIN_NAME=$2
            DOMAIN_TOKEN=$(get_domain_token $DOMAIN_NAME)
            defType=$3
                if [[ $DOMAIN_TOKEN == "" ]]; then echo "domain $DOMAIN_NAME not found"; exit 1; fi
            get_domain_records $DOMAIN_NAME $DOMAIN_TOKEN
            MYIP=$(get_my_IP $defType)
            add_domain_record $4 # add subdomain
        fi
    ;;
    "edit")
    ;;
    "update")
        MYIP=$(get_my_IP $defType)
        if [[ $# -eq 1 ]]; then echo -e "Error: You must specify a domain.\nFor help enter \"$0 --help\""; exit 1; fi
        # Get token here - https://pddimp.yandex.ru/api2/admin/get_token
        DOMAIN_NAME=$2
        DOMAIN_TOKEN=$(get_domain_token $DOMAIN_NAME)
            if [[ $DOMAIN_TOKEN == "" ]]; then echo "domain $DOMAIN_NAME not found"; exit 1; fi
        get_domain_records $DOMAIN_NAME $DOMAIN_TOKEN
        if [[ -z "$3" ]]; then
            for i in ${!types[@]}; do
                if [[ (${types[$i]} == "A" || ${types[$i]} == "AAAA" ) ]]; then
                    if [[ $defType == ${types[$i]}  ]]; then
                        if [[ ${contents[$i]} != $MYIP ]]; then
                            update_domain_record ${records_id[$i]} ${subdomains[$i]}
                            echo -e "`date \"+%Y%m%d %H:%M\"` IP ${contents[$i]} changed to $MYIP for subdomain ${subdomains[$i]} in domain $DOMAIN_NAME" | tee -a $LOG
                        fi # end IP check
                    else
                        defType=${types[$i]}
                        MYIP=$(get_my_IP $defType)
                        if [[ ${contents[$i]} != $MYIP ]]; then
                            update_domain_record ${records_id[$i]} ${subdomains[$i]}
                            echo -e "`date \"+%Y%m%d %H:%M\"` IP ${contents[$i]} changed to $MYIP for subdomain ${subdomains[$i]} in domain $DOMAIN_NAME" | tee -a $LOG
                        fi # end IP check
                   fi # end types check
                fi #end check types A or AAAA
            done
        # for three arguments
        elif [[ $3 == "A" || $3 == "AAAA" ]]; then
            defType=$3
            MYIP=$(get_my_IP $defType)
            for i in ${!types[@]}; do
                if [[ ${types[$i]} == $defType && ${contents[$i]} != $MYIP ]]; then
                update_domain_record ${records_id[$i]} ${subdomains[$i]}
                echo -e "`date \"+%Y%m%d %H:%M\"` IP ${contents[$i]} changed to $MYIP for subdomain ${subdomains[$i]} in domain $DOMAIN_NAME" | tee -a $LOG
                fi
            done
        fi
    ;;
    "--help" | "-help" | "-h") usage ;;
    *) usage ;;
esac
exit 0
