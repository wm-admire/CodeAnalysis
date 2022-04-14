#!/usr/bin/env bash

# 打印带颜色的状态，蓝色
function LOG_INFO() {
  echo -e "\033[34m >>> $*\033[0;39m"
}

# 打印带颜色的状态，黄色
function LOG_WARN() {
  echo -e "\033[33m >>> $*\033[0;39m"
}

# 打印带颜色的状态，黄色
function LOG_ERROR() {
  echo -e "\033[31m >>> $*\033[0;39m"
}
