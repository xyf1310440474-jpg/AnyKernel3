#!/bin/sh
# BORE 调度器场景化预设切换工具
#
# 用法（root）：
#   bore-profile.sh battery|balance|gaming|stock   # 应用预设
#   bore-profile.sh status                          # 查看当前值
#   bore-profile.sh                                 # 显示本帮助
#
# 参数语义（取自本仓库 patches/bore/bore-v7.0.0.patch 实现）：
#   penalty_offset  : 突发"容忍阈值"(0-63, 默认24)。越高越不易惩罚突发任务 → 更宽容/省电；
#                     越低越激进惩罚 → 更跟手。burst 超过此阈值才开始计罚。
#   penalty_scale   : 惩罚强度(0-4095, 默认1536)。越高 UI 响应越激进；0 = 关闭惩罚。
#   smoothness      : 惩罚增长平滑度(0-3, 默认1)。越高越平缓；0=最激进即时响应。
#   cache_lifetime  : burst 记忆时长(ns, 默认75000000=75ms)。越短越快"遗忘"历史突发。
#   inherit_type    : fork 继承(0-2, 默认2)。0=不继承 1=自身 2=含祖先(完整继承链)。
#
# 这些预设是"合理的调参起点"，不是绝对最优。BORE 效果因负载/个人手感而异，
# 可用 status 观察后再微调单个节点。

P=/proc/sys/kernel
LOG_TAG="bore-profile"

has_bore() { [ -d "$P" ] && ls "$P" | grep -q '^sched_burst_' 2>/dev/null; }

apply() {
  has_bore || { echo "[$LOG_TAG] 未检测到 BORE 节点（内核未编译 CONFIG_SCHED_BORE）" >&2; return 1; }
  set -- $1
  echo "$2" > "$P/sched_burst_penalty_offset"  2>/dev/null || :
  echo "$3" > "$P/sched_burst_penalty_scale"   2>/dev/null || :
  echo "$4" > "$P/sched_burst_smoothness"      2>/dev/null || :
  echo "$5" > "$P/sched_burst_cache_lifetime"  2>/dev/null || :
  echo "$6" > "$P/sched_burst_inherit_type"    2>/dev/null || :
  echo "[$LOG_TAG] 已应用 $1 ; status:"
  status
}

status() {
  has_bore || { echo "[$LOG_TAG] 未检测到 BORE 节点" >&2; return 1; }
  for k in sched_bore sched_burst_penalty_offset sched_burst_penalty_scale \
           sched_burst_smoothness sched_burst_cache_lifetime sched_burst_inherit_type; do
    printf '  %-32s = %s\n' "$k" "$(cat "$P/$k" 2>/dev/null || echo N/A)"
  done
}

case "${1:-}" in
  battery)
    # 省电：高容忍 + 低强度 + 高平滑 + 短记忆 → 减少激进重排与无谓唤醒
    apply "battery 32 768 2 50000000 2" ;;
  balance)
    # 均衡：接近内核默认，稳定通用
    apply "balance 24 1536 1 75000000 2" ;;
  gaming)
    # 游戏/性能：低容忍 + 高强度 + 零平滑 + 长记忆 → 最快识别并重排突发前台任务
    apply "gaming 16 2048 0 100000000 2" ;;
  stock)
    # 恢复内核编译默认值
    apply "stock 24 1536 1 75000000 2" ;;
  status)
    status ;;
  *)
    sed -n '2,20p' "$0" | sed 's/^# \{0,1\}//' ;;
esac
