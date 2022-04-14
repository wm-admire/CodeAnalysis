#!/usr/bin/env bash

# Customizable environment variables:
# +---------------------+----------------------+----------------------------------------------+
# | Name                | Default Value        | Intro                                        |
# +---------------------+----------------------+----------------------------------------------+
# | SERVER_ENV          | none                 | 访问的后端地址，必填项                           |
# | INGRESS_PORT        | 80                   | ingress  配置的端口，默认 80                    |
# | INGRESS_SERVER_NAME | tca.tencent.com      | ingress 配置的服务名称，默认 tca.tencent.com     |
# | NGINX_CONF_PATH     | /etc/nginx/conf.d    | nginx配置地址，默认 /etc/nginx/conf.d           |
# | WEB_DEPLOY_PATH     | /usr/share/nginx/www | 前端资源部署地址，默认 /usr/share/nginx/www      |
# | IS_DOCKER           | none                 | 是否从DOCKER启动                               |
# +---------------------+----------------------+-----------------------------------------------+

###########################
### 部署/更新web服务
### 执行方式：
### 方式一：直接执行 bash deploy.sh init -d 或 bash init.sh -d 即可
### 方式二：查阅上述环境变量，先export对应环境变量，再 bash init.sh
###########################

# 获取工作目录路径，绝对路径
WORK_PATH=$(cd $(dirname $0) && pwd)
# 获取上层目录，即tca-deploy-source根目录
ROOT_PATH=$(cd $(dirname $0) && cd ../ && pwd)

source $WORK_PATH/_log.sh

# 默认使用config.sh内的环境变量配置
if [ "$1" == "default" -o "$1" == "-d" ]; then
  source $WORK_PATH/config.sh
fi

# 校验必传项
if [ ! -n "$SERVER_ENV" ]; then
  LOG_WARN "SERVER_ENV: 请指定前端访问后端的服务地址"
  exit 1
fi

# 前端nginx服务名称
INGRESS_SERVER_NAME=${INGRESS_SERVER_NAME:-"tca.tencent.com"}
# 前端nginx暴露端口
INGRESS_PORT=${INGRESS_PORT:-80}
# 微前端静态资源存放位置
WEB_DEPLOY_PATH=${WEB_DEPLOY_PATH:-"/usr/share/nginx/www"}
# nginx 配置地址，默认/etc/nginx/conf.d
NGINX_CONF_PATH=${NGINX_CONF_PATH:-"/etc/nginx/conf.d"}
# nginx 日志文件地址，默认/var/log/nginx
NGINX_LOG_PATH=${NGINX_LOG_PATH:-"/var/log/nginx"}

# 微前端基座
MICRO_FRONTEND_FRAMEWORK="framework"
# 微前端帮助文档
MICRO_FRONTEND_DOCUMENT="tca-document"
# 子微前端
MICRO_FRONTEND_APPS="login tca-layout tca-analysis tca-manage"

# 由于原来各个微前端采用了不同的nginx conf，后为简化开源版前端部署已重新调整配置，为兼容旧版此处默认使用清楚逻辑
function clear_old_nginx_conf() {
  # 清除各个应用的nginx conf文件
  MICRO_FRONTEND="$MICRO_FRONTEND_FRAMEWORK $MICRO_FRONTEND_APPS $MICRO_FRONTEND_DOCUMENT"
  for app in $MICRO_FRONTEND; do
    rm -f $NGINX_CONF_PATH/$app.conf
  done
}

# 清理资源文件
function clear_assets() {
  LOG_WARN "将路径下的资源文件和前端nginx配置备份到 ${WEB_DEPLOY_PATH}_bak 下..."
  cp -r $WEB_DEPLOY_PATH/ ${WEB_DEPLOY_PATH}_bak/
  cp -r $NGINX_CONF_PATH/tca_ingress.conf ${WEB_DEPLOY_PATH}_bak/
  LOG_INFO "开始清理路径下的资源文件 $WEB_DEPLOY_PATH ..."
  rm -rf $WEB_DEPLOY_PATH/
  LOG_INFO "开始清理前端nginx配置 ..."
  rm -f $NGINX_CONF_PATH/tca_ingress.conf
}

# 解压编译后文件
function init_unzip_build() {
  LOG_INFO "解压编译后文件到 $WEB_DEPLOY_PATH ..."
  rm -rf $WEB_DEPLOY_PATH/
  mkdir -p $WEB_DEPLOY_PATH
  cd $ROOT_PATH/build_zip/
  # 遍历并解压
  MICRO_FRONTEND="$MICRO_FRONTEND_FRAMEWORK $MICRO_FRONTEND_APPS $MICRO_FRONTEND_DOCUMENT"
  for app in $MICRO_FRONTEND; do
    unzip -o $app.zip -d $WEB_DEPLOY_PATH/$app
  done
  cd $ROOT_PATH
}

# 初始化配置 framework
function init_framework_web() {
  LOG_INFO "初始化配置 $MICRO_FRONTEND_FRAMEWORK ..."
  # index meta 配置项
  MICRO_FRONTEND_API=/static/configs.json
  MICRO_FRONTEND_SETTING_API=/static/settings.json
  TITLE=腾讯云代码分析
  DESCRIPTION=腾讯云代码分析，用心关注每行代码迭代、助力传承卓越代码文化！精准跟踪管理代码分析发现的代码质量缺陷、代码规范、代码安全漏洞、无效代码，以及度量代码复杂度、重复代码、代码统计。
  KEYWORDS=代码检查、圈复杂度、重复代码、代码统计
  FAVICON=/static/images/favicon.ico
  FRAMEWORK_DEPLOY_PATH=$WEB_DEPLOY_PATH/$MICRO_FRONTEND_FRAMEWORK

  LOG_INFO "index meta 配置 ..."
  replace_content="
  s|__TITLE__|$TITLE|g; \
  s|__KEYWORDS__|$KEYWORDS|g; \
  s|__DESCRIPTION__|$DESCRIPTION|g; \
  s|__FAVICON__|$FAVICON|g; \
  "
  LOG_INFO "[INFO]:index.html RUNTIME is enabled"
  LOG_INFO "[INFO]: change 404.html, unsupported-browser.html"
  sed -i "$replace_content" $FRAMEWORK_DEPLOY_PATH/404.html
  sed -i "$replace_content" $FRAMEWORK_DEPLOY_PATH/unsupported-browser.html

  LOG_INFO "[INFO]: change index.html"
  sed \
    "
    $replace_content \
    s|__MICRO_FRONTEND_API__|$MICRO_FRONTEND_API|g; \
    s|__MICRO_FRONTEND_SETTING_API__|$MICRO_FRONTEND_SETTING_API|g; \
    " \
    $FRAMEWORK_DEPLOY_PATH/index.runtime.html >$FRAMEWORK_DEPLOY_PATH/index.html

  LOG_INFO "conf 配置迁移 ..."
  # 将conf目录中的配置文件拷贝到 $MICRO_FRONTEND_FRAMEWORK static目录下
  cp $ROOT_PATH/conf/settings.json $FRAMEWORK_DEPLOY_PATH/static/settings.json
  cp $ROOT_PATH/conf/configs.json $FRAMEWORK_DEPLOY_PATH/static/configs.json
  LOG_INFO "$MICRO_FRONTEND_FRAMEWORK 配置完毕"
}

# 初始化配置web的nginx配置
function init_web_nginx() {
  LOG_INFO "初始化配置web的nginx配置 ..."
  SET_DEFAULT_SERVER=""
  if [ "$IS_DOCKER" == "TRUE" ]; then
    SET_DEFAULT_SERVER="default_server"
  fi
  apps=$(echo $MICRO_FRONTEND_APPS | sed 's/[ ]/\\|/g')
  sed \
    "
    s|SERVER_NAME|$INGRESS_SERVER_NAME|g; \
    s|SET_DEFAULT_SERVER|$SET_DEFAULT_SERVER|g; \
    s|PORT|$INGRESS_PORT|g; \
    s|NGINX_LOG_PATH|$NGINX_LOG_PATH|g; \
    s|WEB_DEPLOY_PATH|$WEB_DEPLOY_PATH|g; \
    s|SERVER_ENV|$SERVER_ENV|g; \
    s|MICRO_FRONTEND_FRAMEWORK|$MICRO_FRONTEND_FRAMEWORK|g; \
    s|MICRO_FRONTEND_DOCUMENT|$MICRO_FRONTEND_DOCUMENT|g; \
    s|MICRO_FRONTEND_APPS|$apps|g; \
    " \
    $ROOT_PATH/nginx/ingress.conf >$NGINX_CONF_PATH/tca_ingress.conf
}

# 启动nginx
function start() {
  LOG_INFO "启动 nginx ..."
  # wc -l 行数计算。当nginx无进程时，启动nginx，否则reload nginx
  nginx_is_start=$(ps -C nginx --no-header | wc -l)
  if [ $nginx_is_start -eq 0 ]; then
    nginx -t
    if [ "$IS_DOCKER" == "TRUE" ]; then
      nginx -g "daemon off;"
    else
      nginx
    fi
  else
    nginx -s reload
  fi
}

clear_old_nginx_conf
clear_assets
init_unzip_build
init_framework_web
init_web_nginx
start
