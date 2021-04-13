#!/usr/bin/env bash
## CUSTOM_SHELL_FILE for https://gitee.com/lxk0301/jd_docker/tree/master/docker
### 编辑docker-compose.yml文件添加 - CUSTOM_SHELL_FILE=https://raw.githubusercontent.com/mixool/jd_sku/main/jd_diy.sh

function monkcoder(){
    # https://share.r2ray.com/dust/
    apk add --no-cache --upgrade grep
    default_root_id="$(curl -s https://share.r2ray.com/dust/ | grep -oE "default_root_id[^,]*" | cut -d\' -f2)"
    folders="$(curl -sX POST "https://share.r2ray.com/dust/?rootId=${default_root_id}" | grep -oP "name.*?\.folder" | cut -d, -f1 | cut -d\" -f3 | grep -v "backup" | tr "\n" " ")"
    test -z "$folders" && return 0 || rm -rf /scripts/dust_*
    for folder in $folders; do
        jsnames="$(curl -sX POST "https://share.r2ray.com/dust/${folder}/?rootId=${default_root_id}" | grep -oP "name.*?\.js\"" | grep -oE "[^\"]*\.js\"" | cut -d\" -f1 | tr "\n" " ")"
        for jsname in $jsnames; do 
            curl -s --remote-name "https://share.r2ray.com/dust/${folder}/${jsname}" && mv $jsname /scripts/dust_$jsname
            jsnamecron="$(cat /scripts/dust_$jsname | grep -oE "/?/?cron \".*\"" | cut -d\" -f2)"
            test -z "$jsnamecron" || echo "$jsnamecron node /scripts/dust_$jsname >> /scripts/logs/dust_$jsname.log 2>&1" >> /scripts/docker/merged_list_file.sh
        done
    done
}

function whyour(){
    # https://github.com/whyour/hundun/tree/master/quanx
    rm -rf /whyour /scripts/whyour_*
    git clone https://github.com/whyour/hundun.git /whyour
    # 拷贝新文件
    for jsname in jdzz.js jx_nc.js jx_factory.js jx_factory_component.js ddxw.js dd_factory.js jd_zjd_tuan.js; do cp -rf /whyour/quanx/$jsname /scripts/whyour_$jsname; done
    for jsname in jdzz.js jx_nc.js jx_factory.js jx_factory_component.js ddxw.js dd_factory.js jd_zjd_tuan.js; do
        jsnamecron="$(cat /whyour/quanx/$jsname | grep -oE "/?/?cron \".*\"" | cut -d\" -f2)"
        test -z "$jsnamecron" || echo "$jsnamecron node /scripts/whyour_$jsname >> /scripts/logs/whyour_$jsname.log 2>&1" >> /scripts/docker/merged_list_file.sh
    done
}

function diycron(){
    # 启用京价保
    echo "23 8 * * * node /scripts/jd_price.js >> /scripts/logs/jd_price.log 2>&1" >> /scripts/docker/merged_list_file.sh
    # 修改docker_entrypoint.sh执行频率
    #ln -sf /usr/local/bin/docker_entrypoint.sh /usr/local/bin/docker_entrypoint_mix.sh
    #echo "35 */3 * * * docker_entrypoint_mix.sh >> /scripts/logs/default_task.log 2>&1" >> /scripts/docker/merged_list_file.sh
}

function main(){
    # 首次运行时拷贝docker目录下文件
    [[ ! -d /jd_sku ]] && mkdir /jd_sku && cp -rf /scripts/docker/* /jd_sku
    # DIY脚本
    a_jsnum=$(ls -l /scripts | grep -oE "^-.*js$" | wc -l)
    a_jsname=$(ls -l /scripts | grep -oE "^-.*js$" | grep -oE "[^ ]*js$")
    monkcoder
    whyour
    b_jsnum=$(ls -l /scripts | grep -oE "^-.*js$" | wc -l)
    b_jsname=$(ls -l /scripts | grep -oE "^-.*js$" | grep -oE "[^ ]*js$")
    # DIY任务
    diycron
    # LXK脚本更新TG通知
    lxktext="$(diff /jd_sku/crontab_list.sh /scripts/docker/crontab_list.sh | grep -E "^[+-]{1}[^+-]+" | grep -oE "node.*\.js" | cut -d/ -f3 | tr "\n" " ")"
    test -z "$lxktext" || curl -sX POST "https://api.telegram.org/bot$TG_BOT_TOKEN/sendMessage" -d "chat_id=$TG_USER_ID&text=LXK脚本更新完成：$(cat /jd_sku/crontab_list.sh | grep -vE "^#" | wc -l) $(cat /scripts/docker/crontab_list.sh | grep -vE "^#" | wc -l) $lxktext" >/dev/null
    # DIY脚本更新TG通知
    info_more=$(echo $a_jsname  $b_jsname | tr " " "\n" | sort | uniq -c | grep -oE "1 .*$" | grep -oE "[^ ]*js$" | tr "\n" " ")
    [[ "$a_jsnum" == "0" || "$a_jsnum" == "$b_jsnum" ]] || curl -sX POST "https://api.telegram.org/bot$TG_BOT_TOKEN/sendMessage" -d "chat_id=$TG_USER_ID&text=DIY脚本更新完成：$a_jsnum $b_jsnum $info_more" >/dev/null
    # 拷贝docker目录下文件供下次更新时对比
    cp -rf /scripts/docker/* /jd_sku
}

main
