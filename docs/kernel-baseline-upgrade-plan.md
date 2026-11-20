# 内核基线上版验证方案（6.1.138 → 更新 LTS）

## 现状

| 项 | 值 |
|---|---|
| 当前编译基线 | Linux 6.1.138（数据文件 `data/android14/6.1.json` 中 2025-06 条目） |
| KMI | `android14-11`（**冻结**，由 build.yml 的 KMI_TAG 硬编码） |
| 数据文件 lts 字段 | 6.1.182 |
| 数据文件最新月度条目 | 6.1.176（2026-09） |
| BORE 补丁 | v7.0.0，android14-6.1 CFS KABI-safe backport（非绑死 6.1.138） |

## 结论先行：可以升，但必须分步验证，不要直接改基线

KMI `android14-11` 是 GKI 冻结点：只要 **KMI 不变**，同 KMI 内升 6.1.x 小版本，
vendor 模块（wlan / qseecom / 触摸）的 ABI 应保持兼容——这正是 GKI 的设计目的。
所以 6.1.138 → 6.1.176 **理论上**安全。但「理论上」不等于实测，风险点在下面。

## 为什么不无脑升（风险清单）

1. **BORE 补丁冲突**：补丁改 `include/linux/sched.h`、`kernel/sched/fair.c` 等核心文件。
   6.1.138 → 6.1.176 跨了 38 个小版本，这些文件必然有上游改动，`git apply` 大概率出现 hunk 偏移或失败。
   - 检查：`build.yml` 应用补丁步骤的 `.rej` 产物（`artifact_upload_mode`/reject 检查机制已有）。
2. **SUSFS 上游分支跟进**：SUSFS 补丁按 `gki-android14-6.1` 分支拉取，上游是否同步到 6.1.176 需确认；
   构建脚本已有 `susfs_branch_missing` 兜底，但「分支存在」≠「适配新基线」。
3. **CVE-2026-43499 等安全补丁**：`security_patch/` 里针对 6.1-6.6 的 rtmutex 补丁，
   升基线后要重验是否仍适用（上游 LTS 可能已内置修复，重复打会冲突）。
4. **KMI symbol list**：GKI 的 `abi_gki_protected_exports_*` / KMI symbol list 与具体基线绑定。
   升版本后若 KMI 漂移，`kmi_symbol_list_strict_mode` 会报错（构建脚本虽有 strip 逻辑，但要确认没掩盖真实问题）。

## 安全的升级验证流程（一次只改一件）

### 第 1 步：CI 上先用新基线完整构建（不刷机）
1. 临时把构建输入的内核版本指向 6.1.176（`gki_fetch.py` 从 android14-6.1-lts 分支 Makefile 取；
   或在 workflow_dispatch 里指定版本/补丁级别）。
2. 观察 BORE 补丁应用步骤：有无 `.rej`、编译是否通过。有 rej 必须先手工 rebase 补丁。
3. 观察 SUSFS 补丁、CVE 补丁步骤是否全绿。
4. 从 release/artifact 拿到 AK3 zip，核对 `uname -r` 基线已是 6.1.176、KMI 仍是 android14-11。

### 第 2 步：模块 ABI 交叉验证（刷机前）
比对新内核与 stock 的关键模块 vermagic / KMI：
```sh
# 新内核里（解包 boot 取 Image，或刷入后）
cat /proc/version
cat /proc/sys/kernel/osrelease
# 与本机 stock vendor_dlkm 模块比对
strings /vendor_dlkm/lib/modules/wlan.ko | grep -iE 'vermagic|android14-11'
```
KMI 字符串必须一致（`android14-11`），否则模块加载失败（vermagic mismatch）。

### 第 3 步：实机灰度（备份优先）
```sh
# 刷前备份当前可用 boot（你已在用的 6.1.138 + AK3）
dd if=/dev/block/by-name/boot_a of=/sdcard/Download/boot_6.1.138_backup.img bs=1M
```
1. 第三方 Recovery 刷新 AK3 到当前活动槽位 boot。
2. 逐项验证（这正好复用你 Skyward 排障时的检查清单）：
   - `uname -r` / `cat /proc/version` 基线正确
   - **触摸**（syna_tcm 驱动加载）
   - **WiFi**（wlan 模块加载、`wlan0` 起来、拿到 IP、能上网）—— 重点看有无 vermagic / q6 时序问题
   - **解密 / Root**（BakaSU 能拿到 root，SUSFS 命令可用）
   - BORE 节点：`ls /proc/sys/kernel/sched_burst_*`（用 bore-profiles 模块 `status` 验证）
3. 任一异常：dd 回备份的 boot，重启恢复。

### 第 4 步：确认稳定后再改默认基线
只有第 1~3 步全过，才把 workflow/数据文件里的默认基线从 6.1.138 提到 6.1.176，
并在 CHANGELOG 记一笔。

## 建议

- **不追求最新**：6.1.138 已在你的设备上实机验证全项正常（触摸/WiFi/解密/BORE）。
  GKI 的安全补丁由 KMI 内的 LTS 滚动提供，但「更新」本身不是目标——除非有明确的安全公告
  （如已合入的 CVE-2026-43499）或你需要的新特性，否则维持现状的风险反而更低。
- **真要升**：严格按上面 4 步走，尤其第 1 步的补丁 rebase 和第 3 步的 WiFi/触摸验证。
  你之前在 Skyward 上吃过 vermagic 不匹配导致模块加载失败的苦，KMI 漂移的坑是真实存在的。
- **收益评估**：BORE 是 CFS 调度层的改动，与 6.1 小版本关系不大；升级对 BORE 效果几乎无提升，
  主要收益是 LTS 安全修复。权衡时把这点算进去。
