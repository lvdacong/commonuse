# Claude Code 代理包装器配置说明

记录于 2026-04-07，用于以后回顾或者重装系统时复刻这套配置。

## 要解决的问题

在国内使用 Claude Code 必须走代理才能访问 claude.ai 等 Anthropic 域名，否则会被地域屏蔽返回 "app-unavailable-in-region"。Claude Code 是 Node.js 应用，而 Node.js **不会读取 Windows 系统代理设置**，只认 `HTTP_PROXY` 和 `HTTPS_PROXY` 环境变量。这意味着即使系统代理开着，直接运行 `claude` 命令依然会失败。

之前的临时方案是写一个 `cld.bat` 脚本，启动前先 `set HTTP_PROXY=http://127.0.0.1:7890` 再调用 `claude`。这种方式有几个不便：

1. 命令名 `cld` 不是官方的 `claude`，需要额外记忆，与 Claude 官方文档里的命令对不上。
2. TUN 模式下，硬编码的 `127.0.0.1:7890` 可能和 TUN 路由冲突或代理客户端关闭了 HTTP 监听端口，导致连不上。
3. 切换系统代理模式和 TUN 模式时需要维护两个不同的 bat。

## 最终方案

在 `C:\data\commonuse\` 下放一个 `claude.bat` 包装器，让它在 PATH 顺序上排到真正的 `claude.exe` 前面，从而成为 `claude` 命令的真正入口。包装器做三件事：

1. 读取 Windows 注册表里的系统代理状态
2. 根据状态决定是否注入 `HTTP_PROXY`/`HTTPS_PROXY` 环境变量
3. 用 `%*` 把全部命令行参数原样转发给真正的 `claude.exe`

这样无论在系统代理模式还是 TUN 模式下，都只需要输入 `claude` 一个命令。

## 工作原理

### 代理状态检测

包装器读取注册表 `HKCU\Software\Microsoft\Windows\CurrentVersion\Internet Settings` 下的两个值：

- `ProxyEnable` 为 1 表示系统代理打开
- `ProxyServer` 是当前的代理地址，例如 `127.0.0.1:7890`

绝大多数代理客户端在切换到 TUN 模式时会同步把系统代理关掉，所以 `ProxyEnable` 这个值能可靠地反映当前是哪种网络模式。

判断逻辑：

| `ProxyEnable` 值 | 含义 | 包装器行为 |
|---|---|---|
| `0x1` | 系统代理开启 | 从 `ProxyServer` 读出地址，设置 `HTTP_PROXY`/`HTTPS_PROXY` |
| `0x0` 或缺失 | 系统代理关闭 | 不设置任何代理变量，假定是 TUN 或直连 |

代理地址从注册表动态读取而不是硬编码，所以以后改了代理端口也不用动脚本。

### PATH 顺序的关键

Windows 解析命令时会按 PATH 目录顺序逐个查找。`claude.exe` 的真实安装位置是 `C:\Users\ASUS\.local\bin\claude.exe`，这个目录原本在用户 PATH 里排在 `C:\data\commonuse` 前面，会被先找到。

为了让包装器生效，必须把 `C:\data\commonuse` 移动到 `C:\Users\ASUS\.local\bin` **前面**。改动是在用户 PATH 里做的，不涉及系统 PATH，无需管理员权限。

修改后的相关顺序：

```
... npm ; C:\data\commonuse ; C:\Users\ASUS\.local\bin ; VS Code\bin ; ...
```

PATH 改动是直接写注册表 `HKCU\Environment\Path` 完成的，写入时用 `REG_EXPAND_SZ` 类型保留 `%VAR%` 展开能力，写完后广播 `WM_SETTINGCHANGE` 让新进程能立即拿到新值。

### 参数透明转发

包装器最后一行是 `"C:\Users\ASUS\.local\bin\claude.exe" %*`。`%*` 在 cmd 里代表"命令行后所有参数"，所以下面这些用法都可以正常工作：

```
claude
claude --resume
claude --resume abc-123
claude config get
claude -p "写个脚本"
claude doctor
```

唯一需要注意的小坑：cmd 的 `%*` 对 `&` `|` `>` `<` `^` 这几个特殊字符的处理偶尔会出问题。常规命令完全没问题，如果以后真碰到带特殊字符的复杂参数，可以换成 PowerShell 启动器实现更稳的转发。

## 相关文件清单

| 路径 | 作用 |
|---|---|
| `C:\data\commonuse\claude.bat` | 包装器本身，是这套方案的核心文件 |
| `C:\Users\ASUS\.local\bin\claude.exe` | Claude Code 官方安装的二进制，包装器调用它 |
| `C:\Users\ASUS\.claude\settings.json` | 包含 `permissions.defaultMode: bypassPermissions` 和 `skipDangerousModePermissionPrompt: true`，让 Claude 启动时直接进入跳过权限确认模式 |
| `C:\Users\ASUS\Documents\user_path_backup_<时间戳>.txt` | 修改 PATH 之前的备份，稳定后可删 |

`settings.json` 里的两项配置是官方等价于命令行 `--dangerously-skip-permissions` 的方式，配上之后包装器内部不需要也不应该再加这个参数。

## 验证方法

每次重装、迁移或者怀疑配置出错时，新开一个终端窗口运行：

```
where claude
```

正确输出应该是两行，`.bat` 排在第一行：

```
C:\data\commonuse\claude.bat
C:\Users\ASUS\.local\bin\claude.exe
```

然后运行 `claude --version`，应该能正常返回版本号，例如 `2.1.92 (Claude Code)`。

启动 `claude` 时包装器会先打印一行状态：

- 系统代理模式下打印 `[cld] System proxy mode: 127.0.0.1:7890`
- TUN 模式或直连下打印 `[cld] TUN mode or direct connection (no HTTP proxy env vars set)`

看到状态行就说明包装器在生效。

## 使用前提

包装器只做"翻译"，不会替你启动代理。使用流程是：

1. 先打开代理软件，确认进入了系统代理模式或 TUN 模式
2. 然后输入 `claude` 即可启动

如果完全没开代理就直接运行 `claude`，注册表 `ProxyEnable` 为 0，包装器什么都不做，Node.js 直连 claude.ai 会被地域屏蔽。

## 故障排查

### `where claude` 找不到 `.bat` 或者 `.exe` 在前

说明 PATH 顺序错了或者文件丢了。检查：

1. `C:\data\commonuse\claude.bat` 是否存在
2. 注册表 `HKCU\Environment\Path` 里 `C:\data\commonuse` 是否在 `C:\Users\ASUS\.local\bin` 前面
3. 是否在新开的终端窗口里测试，已经打开的进程不会拿到 PATH 修改后的值

### `claude` 启动后报网络错误

按下面顺序检查：

1. 代理软件是否在运行
2. 系统代理模式下，注册表 `ProxyEnable` 是否是 1
3. TUN 模式下，TUN 接管是否生效，能否在浏览器里打开 `https://pivot.claude.ai`
4. 包装器启动时打印的状态行是否符合预期

### Claude 自动更新后包装器失效

Claude Code 自动更新只会覆盖 `C:\Users\ASUS\.local\bin\claude.exe`，不会动 `C:\data\commonuse\claude.bat` 和 PATH 注册表。所以正常情况下更新不会破坏这套方案。

如果哪天 Claude 改了安装位置，需要把 `claude.bat` 里的 `C:\Users\ASUS\.local\bin\claude.exe` 这一行改成新的路径。

## 重装系统时的复刻步骤

1. 装好 Claude Code 官方版，确认 `claude.exe` 安装到了 `C:\Users\ASUS\.local\bin\claude.exe`
2. 把这个目录下的 `claude.bat` 复制到 `C:\data\commonuse\`
3. 把 `C:\data\commonuse` 加到用户 PATH，且必须排在 `C:\Users\ASUS\.local\bin` 前面
4. 在 `~/.claude/settings.json` 里设置 `permissions.defaultMode: bypassPermissions` 和 `skipDangerousModePermissionPrompt: true`
5. 新开终端，`where claude` 验证包装器在前，`claude --version` 验证能跑
