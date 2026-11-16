# ZCode Mobile

> iOS 客户端：在 App 内通过 **扫码 / 输入链接** 远程连接 ZCode 官方桌面客户端，支持 **同时管理多个客户端、自由切换**。产出未签名 IPA，自签安装。

仓库状态：**脚手架 + CI 已就绪**，push 即自动构建未签名 IPA。

---

## 一、实测结论（2026-11-16，基于真实抓取）

对桌面端 ZCode 3.18.2 的「移动远程控制」功能实测（Chrome 打开官方提供的链接，逐项验证）：

### 1. 二维码内容 = 一条 HTTPS 链接

桌面端左下角 📱 图标 → 弹出「移动远程控制」面板 →「复制链接」，内容形如：

```
https://zcode.z.ai/remote/v4?sid=d_XXXXXXXXXXXXXXXXX&mid=<机器UUID>&name=<设备名>&app_version=3.18.2
```

| 参数 | 含义 | App 用途 |
|---|---|---|
| `sid` | 工作区/配对令牌（敏感） | 页面连接凭据，App 原样透传给官方页面 |
| `mid` | 机器唯一 ID (UUID) | **多客户端去重键**：同 mid = 同一台设备，更新链接不新增会话 |
| `name` | 设备名（如 AtlasOS） | 会话卡片显示名 |
| `app_version` | 桌面端版本 | 诊断用 |

### 2. 远程页面是官方托管的版本化 SPA

- 页面地址：`https://zcode.z.ai/remote/v4/<app_version>/...`（React SPA，与桌面端同版本发布）
- **必须登录**：打开链接先进入「Web Remote Control Sign In」，要求与电脑端 **同一账号**，分「中国 / 全球」区，走浏览器 OAuth 授权
- 协议错误码族（页面 JS 内可见）：`remote-authentication-failed` / `remote-host-unreachable` / `remote-connection-timeout` / `remote-host-key-changed` 等，与桌面端 `remote-project` 错误映射一致 → **连接经官方云端中继**，手机任意网络可用，无局域网依赖

### 3. 域名现状

| 域名 | 状态 |
|---|---|
| `zcode.z.ai` | ✅ 正常（主域，`/remote/v4`、OAuth 均在此） |
| `zcode.chatglm.site` | ❌ 本网络连接被重置（旧域/备用域，桌面端旧代码仍有引用） |
| `api.z.ai` | ✅ 正常（301） |

### 4. 对 App 的直接推论

1. **不需要逆向连接协议**：登录后的连接握手、消息通道全部由官方页面完成。App 里每个会话 = 一个加载官方 `/remote/v4` 链接的 `WKWebView`，协议兼容性 100%，官方升级页面 App 零改动。
2. **登录态可共享**：所有会话的 WebView 共用同一个 `WKWebsiteDataStore`，登录一次（OAuth 跳转一次）全部会话可用。
3. **多客户端天然支持**：每个桌面客户端有自己的 sid/mid 链接；App 侧维护会话列表（mid 去重），多 WebView 并发互不干扰。
4. 扫码只做一件事：从二维码解析出链接 → 存入会话列表。

---

## 二、架构

```
┌────────────────────────────────────────────────────┐
│              ZCode Mobile (SwiftUI, iOS 16+)       │
│                                                    │
│  扫码 VisionKit DataScanner / 手动输入 / 剪贴板      │
│        │ LinkParser 解析 sid/mid/name              │
│        ▼                                           │
│  SessionStore（mid 去重，持久化会话列表）             │
│        │                                           │
│  ┌─────▼──────────────────────────────────────┐    │
│  │ NavigationStack 会话列表（名称/链接/删除）    │    │
│  └─────┬──────────┬──────────┬────────────────┘    │
│        ▼          ▼          ▼                     │
│   SessionView  SessionView  SessionView  ←随时切换  │
│   (WKWebView)  (WKWebView)  (WKWebView)            │
│        └──────────┴──────────┘                     │
│         共享 WKWebsiteDataStore（登录一次）           │
└────────────────────────────────────────────────────┘
                    │ HTTPS
                    ▼
        zcode.z.ai /remote/v4（官方页面+云端中继）
                    │ WSS
                    ▼
            桌面客户端（AtlasOS…）
```

### 关键决策

| 决策 | 理由 |
|---|---|
| WebView 承载官方页面而非逆向协议 | 页面要求账号登录 + OAuth，协议动态构造；WebView 路线协议无关、随官方自动升级 |
| `mid` 作会话去重键 | 桌面端每次可能生成新 sid，mid 才是设备的稳定标识 |
| 共享 data store | 避免每个会话重复登录 |
| xcodegen 生成 Xcode 工程 | 仓库内无需提交 pbxproj，CI 用 brew 装 xcodegen 即可构建 |
| CI 产出**未签名 IPA** | 签名交给用户自签（Sideloadly/AltStore/证书），仓库不持有任何凭据 |

---

## 三、已就绪的内容

```
ZCodeMobile/            App 源码（SwiftUI）
  ZCodeMobileApp.swift      入口
  Models.swift              RemoteSession + LinkParser（链接解析/去重键提取）
  SessionStore.swift        会话持久化（mid 去重）
  ContentView.swift         会话列表 + 扫码/手动输入入口
  SessionView.swift         WKWebView 会话页（共享登录态）
  ScanView.swift            VisionKit 扫码封装 + 相机权限处理
project.yml             xcodegen 工程定义
.github/workflows/build.yml   CI：生成工程 → 未签名归档 → 打包 IPA → 产物
```

## 四、CI 构建 IPA

push 到 `main` 自动触发（也可在 Actions 页手动 `workflow_dispatch`）：

1. macOS runner：`brew install xcodegen` → `xcodegen generate`
2. `xcodebuild archive`（`CODE_SIGNING_ALLOWED=NO`，不签名）
3. `.app` 打包为 `Payload/…ipa` 结构 → **未签名 IPA**
4. 上传为 Actions Artifact；打 tag（`v0.1.0` 等）时自动附到 GitHub Release

> macOS runner 限额：public 仓库免费；本仓库已设为 public。

## 五、安装到 iPhone（自签）

下载 Actions/Release 里的 IPA 后任选：

| 方式 | 说明 |
|---|---|
| **Sideloadly / AltStore** + 免费 Apple ID | 最简单，7 天有效期需续签 |
| 付费开发者账号签名 | 1 年有效期，日常自用推荐 |
| esign 等自签工具 + 证书 | 有证书资源时用 |

## 六、路线图（按序推进，无需等待）

- [x] 协议实测：链接格式 / 登录墙 / 中继确认（本文档第一节）
- [x] 仓库脚手架 + CI（本仓库已具备）
- [ ] **首个绿色构建**：修复 CI 中暴露的编译问题，拿到 v0.1 IPA
- [ ] 真机自测：登录一次 → 加载会话 → 验证远控可用
- [ ] 多会话切换打磨：会话保活策略、退后台重连、WebView 内存优化（按需挂起）
- [ ] 增值功能：剪贴板自动识别链接、会话别名编辑、深色模式适配、iPad 双栏
- [ ] （远期）高频操作原生化：抓一次登录态的 WS 流量后评估

## 七、风险与对策

| 风险 | 对策 |
|---|---|
| 登录 OAuth 在 WebView 内的兼容性（弹窗/跳转） | WKWebView 处理 `window.open` 回调；不行则引导用系统 Safari 登录后复制回跳链接（M1 阶段实测） |
| 官方页面更新（版本路径变化） | 页面 URL 以链接为准，App 不硬编码版本号；解析只认 `/remote/` 路径 |
| iOS 后台挂起连接 | 回前台刷新页面 + 会话状态可视化；官方页面自带重连逻辑 |
| sid 泄漏风险 | 链接等同远控凭据：App 内不明文展示 sid、不支持导出，删除会话即清除 |
| GitHub 网络不稳 | CI 在 GitHub 侧构建，不受本地网络影响 |

---

*本方案基于 2026-11-16 对 ZCode 3.18.2 桌面端与官方远控页面的实测，取代 v1 中的假设性内容。*
