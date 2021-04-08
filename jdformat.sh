#!/usr/bin/env bash
PATH=/bin:/sbin:/usr/bin:/usr/sbin:/usr/local/bin:/usr/local/sbin:~/bin && export PATH
# Usage:
## wget --no-check-certificate https://raw.githubusercontent.com/mixool/jd_sku/main/jdformat.sh && chmod +x jdformat.sh && bash jdformat.sh

# 传入参数中含有fromfile就从文件读取配置：fromfile@/etc/.jd_sku 
echo $@ | grep -qE "fromfile@[^ ]+" && all_parameter=($(cat $(echo $@ | grep -oE "fromfile@[^ ]+" | cut -f2 -d@))) || all_parameter=($(echo $@))

# 文件路径： jd_scripts diy 脚本和log等的保存路径
workdir="/jd_sku/jd_scripts"
logfile="$workdir/logs"
cookiefile="$workdir/cookie.file"
composefile="$workdir/docker-compose.yml"

function jd_sku_base(){
    [[ ! -d "$workdir" ]] && git clone https://github.com/mixool/jd_sku.git $workdir
}

function jd_sku_var(){
    # 网络地址下载docker-compose.yml配置 jd_sku_var@https://gist.github.com 
    compose_file_url=$(echo ${all_parameter[*]} | grep -oE "jd_sku_var@http[^ ]+" | cut -f2 -d@ | head -n1)
    [[ $compose_file_url != "" ]] && wget -O $composefile $compose_file_url && return 0
    # 传入参数获取docker-compose.yml配置 jd_sku_var@ENABLE_AUTO_HELP@true jd_sku_var@TG_BOT_TOKEN@123456:AABB jd_sku_var@TG_USER_ID@-123456 
    varlist=($(echo ${all_parameter[*]} | grep -oE "jd_sku_var@[^@]+@[^ ]+" | tr "\n" " "))
    for ((i = 0; i < ${#varlist[*]}; i++)); do
        varname="$(echo ${varlist[i]} | cut -f2 -d@)"
        varvalue="$(echo ${varlist[i]} | cut -f3 -d@)"
        [[ $i == 0 ]] && echo >>$composefile
        [[ $varname == "" || $varvalue == "" ]] && continue
        sed -i "/$varname.*/d" $composefile
        echo "                - $varname=$varvalue" >>$composefile
    done
}

function jd_sku_initck() {
    # 传入参数格式为 jd_sku_initck@https://gist.github.com 时从网络地址获取cookie,无参数时从目录下的cookie.file获取cookie，再配置docker-compose.yml
    cookie_file_url=$(echo ${all_parameter[*]} | grep -oE "jd_sku_initck@http[^ ]+" | cut -f2 -d@ | head -n1)
    [[ $cookie_file_url != "" ]] && wget -O $cookiefile $cookie_file_url && cookies="$(cat $cookiefile | grep -vE "^#" | tr "\n" "&" | sed "s/&$//")"
    [[ $cookie_file_url == "" ]] && cookies="$(cat $cookiefile | grep -vE "^#" | tr "\n" "&" | sed "s/&$//")"
    sed -i "/JD_COOKIE.*/d" $composefile
    echo "                - JD_COOKIE=$cookies" >>$composefile
    # 替换logs目录下的cookies.list文件供spnode使用
    cp -rf $cookiefile $logfile/cookies.list
    return 0
}

function main() {
    jd_sku_base
    jd_sku_var
    jd_sku_initck
    cat $composefile
}

main