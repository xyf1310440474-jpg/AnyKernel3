# BORE 调度场景预设

把 BORE 从"编译进内核但用户无感"变成可一键切换的三套参数，兼顾省电 / 均衡 / 性能。

## 三套预设

| 预设 | offset | scale | smoothness | cache_lifetime | inherit | 取向 |
|---|---|---|---|---|---|---|
| `battery` 省电 | 32 | 768 | 2 | 50ms | 2 | 高容忍+低强度，减少激进重排与唤醒 |
| `balance` 均衡 | 24 | 1536 | 1 | 75ms | 2 | 接近内核默认，通用稳定 |
| `gaming` 性能 | 16 | 2048 | 0 | 100ms | 2 | 低容忍+高强度+零平滑，最快响应前台突发 |
| `stock` 复位 | 24 | 1536 | 1 | 75ms | 2 | 恢复内核编译默认值 |

> 这些是**基于参数实现的合理起点**，不是绝对最优。BORE 效果因负载与个人手感而异，
> 建议用 `status` 观察、逐项微调找到适合自己的值。

## 参数含义（取自 BORE v7.0.0 补丁实现）

- `penalty_offset`（0-63，默认 24）：突发"容忍阈值"，越高越不易惩罚突发任务 → 更宽容/省电；越低越激进 → 更跟手。
- `penalty_scale`（0-4095，默认 1536）：惩罚强度，越高 UI 响应越激进；0 = 关闭惩罚。
- `smoothness`（0-3，默认 1）：惩罚增长平滑度，越高越平缓；0 = 即时响应。
- `cache_lifetime`（ns，默认 75000000 = 75ms）：burst 记忆时长，越短越快遗忘历史突发。
- `inherit_type`（0-2，默认 2）：fork 继承范围，2 = 含祖先的完整继承链。

## 使用

方式 A（临时切换，root）：
```sh
su
/data/adb/modules/bore_profiles/bore-profile.sh gaming   # 立即生效
/data/adb/modules/bore_profiles/bore-profile.sh status   # 查看当前值
```

方式 B（开机持久化）：
```sh
su -c "echo gaming > /data/adb/bore_profile"   # 写入选择，重启后自动应用
```
可选值：`battery` / `balance`（默认）/ `gaming` / `stock`。

## 安装

打包本目录为 KernelSU 模块（含 `module.prop` + `post-fs-data.sh` + `bore-profile.sh`），
放到 `/data/adb/modules/bore_profiles/` 重启即可；或在 BakaSU 管理器「从本地安装」。

模块在 post-fs-data 阶段读取 `/data/adb/bore_profile` 应用预设，日志见
`/data/adb/modules/bore_profiles/last-apply.log`。

## 验证

```sh
su -c "/data/adb/modules/bore_profiles/bore-profile.sh status"
# 应看到 6 个节点的值已按预设改变
```
