#!/usr/bin/env bash
# 从whyour 大佬的bot.sh 与E大的jup.sh 拼凑出来的
## 导入通用变量与函数
if [ ! -d "/ql" ];then
  dir_root=/jd
else
  dir_root=/ql
fi

dir_bot=$dir_root/jbot
dir_repo=$dir_root/repo
file_bot_setting_user=$dir_root/config/bot.json
url="https://github.com/chiupam/JD_Diy.git"
repo_path="${dir_repo}/diybot"

git_pull() {
    local dir_current=$(pwd)
    local dir_work="$1"
    local branch="$2"
    [[ $branch ]] && local cmd="origin/${branch}"
    cd $dir_work
    echo -e "开始更新仓库：$dir_work\n"
    git fetch --all
    exit_status=$?
    git reset --hard $cmd
    git pull
    cd $dir_current
}

git_clone() {
    local url=$1
    local dir=$2
    local branch=$3
    [[ $branch ]] && local cmd="-b $branch "
    echo -e "开始克隆仓库 $url 到 $dir\n"
    git clone $cmd $url $dir
    exit_status=$?
}

notify () {
    local message="$(echo -e $1)"
    local bot_token=$(cat $file_bot_setting_user | jq -r .bot_token)
    local user_id=$(cat $file_bot_setting_user | jq .user_id)
    local proxy=$(cat $file_bot_setting_user | jq .proxy)
    local proxy_type=$(cat $file_bot_setting_user | jq -r .proxy_type)
    local proxy_add=$(cat $file_bot_setting_user | jq -r .proxy_add)
    local proxy_port=$(cat $file_bot_setting_user | jq .proxy_port)
    local proxy_user=$(cat $file_bot_setting_user | jq -r .proxy_user)
    local proxy_password=$(cat $file_bot_setting_user | jq -r .proxy_password)
    local api_url="https://api.telegram.org/bot${bot_token}/sendMessage"
    local cmd_proxy_user cmd_proxy
    if [[ $proxy_user != *无则不用* ]] && [[ $proxy_password != *无则不用* ]]; then
        cmd_proxy_user="--proxy-user $proxy_user:$proxy_password"
    else
        cmd_proxy_user=""
    fi
    if [[ $proxy == true ]]; then
        cmd_proxy="--proxy $proxy_type://$proxy_add:$proxy_port $cmd_proxy_user"
    else
        cmd_proxy=""
    fi
    curl -Ss $cmd_proxy -H "Content-Type:application/x-www-form-urlencoded" -X POST -d "chat_id=${user_id}&text=${message}&disable_web_page_preview=true" "$api_url" &>/dev/null
}

env() {
  echo -e "\n1、安装bot依赖...\n"
  apk --no-cache add -f zlib-dev gcc jpeg-dev python3-dev musl-dev freetype-dev
  echo -e "\nbot依赖安装成功...\n"
}

bot() {
  echo -e "2、下载bot所需文件...\n"
  if [ -d ${repo_path}/.git ]; then
      jbot_md5sum_old=$(cd $dir_bot; find . -type f \( -name "*.py" -o -name "*.ttf" \) | xargs md5sum)
      git_pull ${repo_path}
      cp -rf "$repo_path/beta" $dir_root
      jbot_md5sum_new=$(cd $dir_bot; find . -type f \( -name "*.py" -o -name "*.ttf" \) | xargs md5sum)
      if [[ "$jbot_md5sum_new" != "$jbot_md5sum_old" ]]; then
          notify "检测到BOT程序有更新，BOT将重启。"
      fi
  else
    git_clone ${url} ${repo_path} "main"
    cp -rf "$repo_path/beta" $dir_root
  fi
  echo -e "\nbot文件下载成功...\n"
}

init() {
  if [[ ! -f "$dir_root/config/bot.json" ]]; then
    cp -f "$repo_path/config/bot.json" "$dir_root/config"
  fi
  if [[ ! -f "$dir_root/config/diybotset.json" ]]; then
    cp -f "$repo_path/config/diybotset.json" "$dir_root/config"
  fi
}

env_bot() {
  echo -e "3、安装python3依赖...\n"
  cd $dir_bot
  pip3 config set global.index-url https://mirrors.aliyun.com/pypi/simple/
  pip3 --default-timeout=100 install -r requirements.txt --no-cache-dir
  echo -e "\npython3依赖安装成功...\n"
}

start() {
  echo -e "4、启动bot程序...\n"
  cd $dir_root
  if [ ! -d "/ql/log/bot" ]; then
    mkdir $dir_root/log/bot
  fi
  if [[ -z $(grep -E "123456789" $dir_root/config/bot.json) ]]; then
    if [ -d "/ql" ]; then
      ps -ef | grep "python3 -m jbot" | grep -v grep | awk '{print $1}' | xargs kill -9 2>/dev/null
      nohup python3 -m jbot >$dir_root/log/bot/bot.log 2>&1 &
      echo -e "bot启动成功...\n"
    else
      cd $dir_bot
      pm2 start ecosystem.config.js
      cd $dir_root
      pm2 restart jbot
      echo -e "bot启动成功...\n"
    fi
  else
    echo -e  "配置 $dir_root/config/bot.json 后再次运行本程序即可启动机器人"
  fi
}

main() {
  env
  bot
  init
  env_bot
  start
}

main
exit 0