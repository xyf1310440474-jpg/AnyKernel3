# 更新日志

本文件记录 houji-bore-kernel 的变更。格式遵循 [Keep a Changelog](https://keepachangelog.com/zh-CN/1.1.0/)。

## [Unreleased] — 2026-11-21（本地优化，尚未推送上游）

> 这一节是 2026-11-21 的代码审查优化，均以独立 commit 提交，见 git log。
> 每条都做了可核验的验证（语法检查 / YAML 解析 / 逻辑模拟）。

### Fixed（修复）
- **SUSFS uname 伪装已验证生效**（P0-1 核实结论）：实机确认 BakaSU 内置 SUSFS 管理器
  提供运行时下发（持久化配置 `ksu_susfs config uname add`），重启后 `uname -r` 与官方
  boot.img 值逐字一致（`g0c3d559bcd85-ab14529422`）。故**无需**额外 susfs-init 模块，
  避免重复下发冲突。README 的 SUSFS 章节记录了完整配置与验证方法。
- **README 自相矛盾的 uname 说法**：原 BORE 章节写 `...houji-BORE-R1`、SUSFS 章节写官方伪装值，
  未说明两者关系。现已明确：真实值 vs 伪装值的区别、伪装需装模块才生效、验证内核身份的可靠方法。

### Added（新增）
- **CI 自动发布 Release + SHA256**（P0-2）：`kernel-custom.yml` 新增 `publish-release` job，
  构建成功后自动下载产物、计算 SHA256（生成 `SHA256SUMS.txt`）、用 softprops/action-gh-release 发版。
  此前 Release 正文写了 SHA 但 assets 为空，产物只在 Actions artifact 里。新增 `publish_release` 输入开关（默认开）。
- **BORE 场景预设**（P1-3）：[`scripts/houji/bore-profiles/`](scripts/houji/bore-profiles/) 提供
  省电 / 均衡 / 游戏三套参数 + KSU 开机模块，参数值取自 BORE 补丁实现语义，可通过
  `/data/adb/bore_profile` 持久化选择。
- **CHANGELOG**（本文件）：建立版本追溯。

### Changed（变更）
- README 刷机章节补充 `sha256sum -c SHA256SUMS.txt` 校验步骤，以及 SUSFS 伪装模块的安装指引。

---

## [1.0] — 项目初始基线

> 上游基线快照，来源于 `xyf1310440474-jpg/houji-bore-kernel` main 分支 2026-11-21 状态
> （本地基线 commit `b004410`）。以下为此前已存在的功能，非本次优化新增。

### 内核基线
- Linux 6.1.138 GKI，KMI `android14-11`（小米 14 / houji / SM8650 / 骁龙 8 Gen 3）
- 基于 LingLuo17/AnyKernel3 构建链，clang LTO
- 其它：MGLRU、UCLAMP、FQ qdisc

### 调度器
- BORE v7.0.0（CFS KABI-safe，Masahito Suzuki；android14-6.1 backport 由 dikafarabian/workbench 提供）
- 设计原则：只改 CFS 调度算法本身，不抢高通 WALT、HyperOS miperf2/perf2-hal/powerkeeper 的 sysfs 控制权

### Root / 隐藏
- BakaSU（KernelSU 变体）
- SUSFS v2.4.0（GKI），内核内置 + 管理器内置 SUSFS 管理界面

### 安全
- CVE-2026-43499 补丁（多内核版本，见 `security_patch/`）

### 构建系统
- GitHub Actions 多版本 workflow（android12~17 / 5.10~6.18）
- 入口 `kernel-custom.yml`，`build.yml` / `get-manager.yml` 可复用
- zram LZ4 NEON、bbg、net 增强等可选组件
