#!/bin/sh
# BORE 预设 KSU 模块：开机应用选定预设
# 修改 /data/adb/bore_profile 可切换开机预设：battery|balance|gaming|stock
MODDIR=${0%/*}
PROFILE_FILE=/data/adb/bore_profile
HELPER="$MODDIR/bore-profile.sh"

profile=$(cat "$PROFILE_FILE" 2>/dev/null | tr -d '[:space:]')
case "$profile" in
  battery|balance|gaming|stock) ;;
  profile=*) profile=${profile#profile=} ;;  # 兼容 "profile=gaming" 写法
  *) profile=balance ;;                       # 默认均衡
esac

chmod +x "$HELPER" 2>/dev/null
"$HELPER" "$profile" > "$MODDIR/last-apply.log" 2>&1
