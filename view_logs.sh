#!/bin/bash

# Android Logcat 查看脚本
# 使用方法: ./view_logs.sh [选项]

echo "=== Android Logcat 查看工具 ==="
echo ""
echo "选择查看方式:"
echo "1. Flutter 日志 (推荐)"
echo "2. 所有日志"
echo "3. 只显示错误日志"
echo "4. Flutter + 错误日志"
echo "5. 保存日志到文件"
echo ""

read -p "请选择 (1-5): " choice

case $choice in
  1)
    echo "查看 Flutter 日志..."
    flutter logs
    ;;
  2)
    echo "查看所有日志..."
    adb logcat
    ;;
  3)
    echo "只显示错误日志..."
    adb logcat *:E
    ;;
  4)
    echo "查看 Flutter 和错误日志..."
    adb logcat -s flutter:V *:E
    ;;
  5)
    filename="logcat_$(date +%Y%m%d_%H%M%S).txt"
    echo "保存日志到 $filename..."
    adb logcat > "$filename"
    ;;
  *)
    echo "使用默认: Flutter 日志"
    flutter logs
    ;;
esac

