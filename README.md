# Hermes Agent — Windows 安装与运行脚本

本仓库收录了在 **Windows 10/11** 上安装和管理 [Hermes Agent](https://github.com/NousResearch/hermes-agent) 所需的两个 PowerShell 脚本，针对中国大陆网络环境做了镜像加速优化。

---

## 文件说明

### `hermes_install.ps1` — 安装脚本

自动完成 Hermes Agent 的全套安装流程，适用于中国大陆用户（使用国内镜像加速）。

**主要功能：**
- 自动安装 `uv`（快速 Python 包管理器）并下载 Python 3.11
- 从国内镜像（CNB）克隆 Hermes Agent 源码
- 使用清华、阿里云等 PyPI 镜像安装 Python 依赖
- 自动检测并绕过失效的本地代理，防止 Git / pip 下载卡死
- 支持安装可选扩展包和系统级依赖

**用法：**

```powershell
# 方式一：直接从镜像一键安装（推荐）
irm https://res1.hermesagent.org.cn/install.ps1 | iex

# 方式二：下载脚本后手动执行
.\hermes_install.ps1                    # 标准安装
.\hermes_install.ps1 -NoVenv           # 不创建虚拟环境
.\hermes_install.ps1 -SkipSetup        # 跳过交互式初始化配置
.\hermes_install.ps1 -WithSystemPackages    # 安装系统级依赖
.\hermes_install.ps1 -WithOptionalExtras    # 安装可选扩展
```

**可用参数：**

| 参数 | 类型 | 默认值 | 说明 |
|------|------|--------|------|
| `-NoVenv` | Switch | — | 不创建 Python 虚拟环境 |
| `-SkipSetup` | Switch | — | 跳过安装后的交互式配置向导 |
| `-WithSystemPackages` | Switch | — | 同时安装系统级依赖包 |
| `-WithOptionalExtras` | Switch | — | 安装可选功能扩展 |
| `-Branch` | String | `main` | 指定克隆的 Git 分支 |
| `-HermesHome` | String | `%LOCALAPPDATA%\hermes` | Hermes 主目录 |
| `-InstallDir` | String | `%LOCALAPPDATA%\hermes\hermes-agent` | 源码安装目录 |

---

### `hermes_gateway_run.ps1` — Gateway 启动管理脚本

用于在 Windows 上以后台服务方式运行 `hermes gateway`，并提供日志管理、进程状态查询与停止功能。

**主要功能：**
- **后台启动**：将 `hermes gateway run -vv` 作为隐藏进程运行，与当前终端完全解耦
- **日志管理**：stdout / stderr 合并写入按日期命名的日志文件，自动清理过期旧日志
- **进程管理**：通过 PID 文件追踪进程，支持查询运行状态和停止服务
- **编码修复**：自动设置 UTF-8 编码，防止中文日志乱码

**用法：**

```powershell
.\hermes_gateway_run.ps1                        # 后台启动（默认）
.\hermes_gateway_run.ps1 -Foreground            # 前台运行（调试用，可看实时输出）
.\hermes_gateway_run.ps1 -Stop                  # 停止后台进程
.\hermes_gateway_run.ps1 -Status                # 查看运行状态（PID、已运行时长）
.\hermes_gateway_run.ps1 -LogRetentionDays 14   # 设置日志保留天数（默认 7 天）
```

**可用参数：**

| 参数 | 类型 | 默认值 | 说明 |
|------|------|--------|------|
| `-LogDir` | String | `%LOCALAPPDATA%\hermes\logs` | 日志存放目录 |
| `-LogRetentionDays` | Int | `7` | 日志保留天数，超期自动删除 |
| `-Foreground` | Switch | — | 前台运行，日志同时输出到终端和文件 |
| `-Stop` | Switch | — | 停止正在运行的后台进程 |
| `-Status` | Switch | — | 显示当前进程状态和已运行时长 |

**日志位置：** `%LOCALAPPDATA%\hermes\logs\hermes-gateway-YYYY-MM-DD.log`

实时查看日志：
```powershell
Get-Content "$env:LOCALAPPDATA\hermes\logs\hermes-gateway-$(Get-Date -Format 'yyyy-MM-dd').log" -Wait
```

---

## 快速开始

```powershell
# 1. 安装 Hermes Agent
.\hermes_install.ps1

# 2. 启动 Gateway（后台运行）
.\hermes_gateway_run.ps1

# 3. 查看运行状态
.\hermes_gateway_run.ps1 -Status

# 4. 停止 Gateway
.\hermes_gateway_run.ps1 -Stop
```

---

## 系统要求

- Windows 10 / Windows 11
- PowerShell 7
- Git（用于克隆源码）
- 网络连接（安装时访问国内镜像源）
