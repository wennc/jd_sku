#!/usr/bin/env bash
## 编辑docker-compose.yml文件添加 - CUSTOM_SHELL_FILE=https://raw.githubusercontent.com/mixool/jd_sku/main/jd_diy.sh
### CUSTOM_SHELL_FILE for https://gitee.com/lxk0301/jd_docker/tree/master/docker
#### 由于更新可能引入未知BUG,建议复制脚本内容至GIST使用

function monkcoder(){
    # https://share.r2ray.com/dust/
    apk add --no-cache --upgrade grep
    i=1
    while [ "$i" -le 5 ]; do
        folders="$(curl -sX POST "https://share.r2ray.com/dust/" | grep -oP "name.*?\.folder" | cut -d, -f1 | cut -d\" -f3 | grep -vE "backup|pics|rewrite" | tr "\n" " ")"
        test -n "$folders" && { for jsname in $(ls -l /scripts | grep -oE "^-.*js$" | awk '{print $NF}' | grep -oE "^dust_.*\.js$"); do mv -f /scripts/$jsname /scripts/temp_$jsname; done; break; }
        test -z "$folders" && { echo 第 $i/5 次目录列表获取失败; sleep 5; i=$(( i + 1 )); }
    done
    for folder in $folders; do
        i=1
        while [ "$i" -le 5 ]; do
            jsnames="$(curl -sX POST "https://share.r2ray.com/dust/${folder}/" | grep -oP "name.*?\.js\"" | grep -oE "[^\"]*\.js\"" | cut -d\" -f1 | tr "\n" " ")"
            test -n "$jsnames" && break || { echo 第 $i/5 次 $folder 目录下文件列表获取失败; sleep 5; i=$(( i + 1 )); }
        done
        for jsname in $jsnames; do 
            i=1
            while [ "$i" -le 5 ]; do
                [ "$i" -lt 5 ] && curl -so /scripts/dust_${jsname} "https://share.r2ray.com/dust/${folder}/${jsname}"
                cat /scripts/dust_${jsname} | grep -qE "^function" && break || { echo 第 $i/5 次 $folder 目录下 $jsname 文件下载失败; sleep 5; i=$(( i + 1 )); }
                [ "$i" -eq 5 ] && [ -f "/scripts/temp_dust_${jsname}" ] && mv -f /scripts/temp_dust_${jsname} /scripts/dust_${jsname}
            done
        done
    done
    rm -rf /scripts/temp_dust_*.js
}

function whyour(){
    # https://github.com/whyour/hundun/tree/master/quanx
    rm -rf /whyour /scripts/whyour_*
    git clone https://github.com/whyour/hundun.git /whyour
    for jsname in jdzz.js jx_nc.js jx_factory.js jx_factory_component.js ddxw.js dd_factory.js jd_zjd_tuan.js; do cp -rf /whyour/quanx/$jsname /scripts/whyour_$jsname; done
}

function zcy01(){
    # https://raw.githubusercontent.com/ZCY01/daily_scripts/main/jd/jd_try.js
    wget -qO /scripts/zcy01_jd_try.js https://raw.githubusercontent.com/ZCY01/daily_scripts/main/jd/jd_try.js
    echo "30 10 * * * node /scripts/zcy01_jd_try.js >> /scripts/logs/zcy01_jd_try.js.log 2>&1" >> /scripts/docker/merged_list_file.sh
}

function diycron(){
    # monkcoder whyour 定时任务
    for jsname in /scripts/dust_*.js /scripts/whyour_*.js; do
        jsnamecron="$(cat $jsname | grep -oE "/?/?cron \".*\"" | cut -d\" -f2)"
        test -z "$jsnamecron" || echo "$jsnamecron node $jsname >> /scripts/logs/$(echo $jsname | cut -d/ -f3).log 2>&1" >> /scripts/docker/merged_list_file.sh
    done
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
    zcy01
    b_jsnum=$(ls -l /scripts | grep -oE "^-.*js$" | wc -l)
    b_jsname=$(ls -l /scripts | grep -oE "^-.*js$" | grep -oE "[^ ]*js$")
    # DIY任务
    diycron
    # DIY脚本更新TG通知
    info_more=$(echo $a_jsname  $b_jsname | tr " " "\n" | sort | uniq -c | grep -oE "1 .*$" | grep -oE "[^ ]*js$" | tr "\n" " ")
    [[ "$a_jsnum" == "0" || "$a_jsnum" == "$b_jsnum" ]] || curl -sX POST "https://api.telegram.org/bot$TG_BOT_TOKEN/sendMessage" -d "chat_id=$TG_USER_ID&text=DIY脚本更新完成：$a_jsnum $b_jsnum $info_more" >/dev/null
    # LXK脚本更新TG通知
    lxktext="$(diff /jd_sku/crontab_list.sh /scripts/docker/crontab_list.sh | grep -E "^[+-]{1}[^+-]+" | grep -oE "node.*\.js" | cut -d/ -f3 | tr "\n" " ")"
    test -z "$lxktext" || curl -sX POST "https://api.telegram.org/bot$TG_BOT_TOKEN/sendMessage" -d "chat_id=$TG_USER_ID&text=LXK脚本更新完成：$(cat /jd_sku/crontab_list.sh | grep -vE "^#" | wc -l) $(cat /scripts/docker/crontab_list.sh | grep -vE "^#" | wc -l) $lxktext" >/dev/null
    # 拷贝docker目录下文件供下次更新时对比
    cp -rf /scripts/docker/* /jd_sku
}

main
