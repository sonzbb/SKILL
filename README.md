# OpenCode Sidecar V3

中文

一句话：**让 Codex 继续做主脑，把长日志、长搜集、大范围扫描、重复执行这些重材料任务交给 OpenCode sidecar，并且在派发后立刻给出可点击监控链接。**

这个仓库提供的是一套可分发的 `OpenCode sidecar` 技能与桥接实现。目标不是替代 Codex，而是把适合 worker 的任务从主线程里拆出去，让 Codex 负责规划、判断、审核和最后结论。

## 一句话开始

把这个仓库链接和下面这段话交给 Codex：

```text
安装并使用 https://github.com/sonzbb/SKILL 里的 OpenCode Sidecar V3。
如果当前机器还没配置好 OpenCode，请先完成所需本地配置。
然后在当前仓库启用这个 sidecar，让 Codex 作为主脑，把适合分派的长任务、日志任务、资料搜集任务交给 OpenCode。
每次派发后，请直接把可点击监控链接回给我，让我能在 Codex 右侧浏览器里实时看 sidecar 在做什么。
```

正常使用时，你不需要记桥接命令、任务 ID、会话 URL。  
你只需要自然地说：

```text
这个任务按小任务处理。
```

```text
这个任务丢给 sidecar，用便宜模型先搜资料。
```

```text
这个任务交给 sidecar，用 pro 模型做深一点的分析。
```

```text
这个任务是图片相关，走多模态模型。
```

```text
先让 opencode 整理材料，你再做最终判断。
```

## 这套东西是干什么的

这套 V3 方案解决的是下面这类问题：

- Codex 很擅长判断、规划、综合，但不适合一直背长日志和长材料
- 纯资料搜集、全文扫描、批量整理、重复试跑，容易吃掉很多 token
- 如果 Codex 不断自己轮询 sidecar 状态，主线程还是会很重
- 用户往往看不到 sidecar 到底在做什么，体验像“黑盒后台”

V3 的核心改进是：

- Codex 继续做主脑
- OpenCode 处理边界清晰的 worker 任务
- 本地桥接脚本使用一次性等待，而不是反复让 Codex 查询状态
- 任务结束后只回收紧凑的 `result.md`
- **每次派发后都返回明确的监控入口**

## 适合什么任务

适合交给 sidecar 的：

- 长日志分析
- 长时间资料搜集
- 多页面信息整理
- 多文件代码扫描
- 仓库级初步 review
- 有边界的调试尝试
- 反复执行的检查、模拟、验证

更适合直接让 Codex 处理的：

- 小而窄的问题
- 需要立即拍板的取舍
- 强依赖上下文连续性的精细修改
- 主要价值在判断，而不在搬运材料的任务

一句规则：

- **要判断的事，优先让 Codex 做**
- **要搬运、搜集、扫描、跑大量材料的事，优先交给 OpenCode**

## 模式划分

| 模式 | 用途 | 边界 |
| --- | --- | --- |
| `research` | 公网资料搜集 | 不读仓库，不跑 shell |
| `repo-readonly` | 日志、调试、代码审查、仓库探索 | 不允许改代码 |
| `repo-write` | 明确边界的实现任务 | 每次都要显式授权写入 |

## 模型路由

这套仓库里已经把模型选择思路整理成规则：

- **图片、多模态、截图理解、视觉检查**  
  优先多模态模型，例如 `MIMO V2.5`

- **纯文本资料搜集、快速整理、初步扫描**  
  优先 `DeepSeek V4 Flash`

- **复杂分析、根因排查、跨文件深推理**  
  优先 `DeepSeek V4 Pro`

- **试运行、链路验证、最低成本 smoke test**  
  优先 `flash-free`

详细规则见 [`.opencode-bridge/MODEL-ROUTING.md`](./.opencode-bridge/MODEL-ROUTING.md)。

## 监控入口

V3 新增了稳定的监控返回约定。  
每次 sidecar 任务派发后，Codex 不应该只告诉你“已经发出去了”，而应该直接回这些字段：

- `Task ID`
- `Mode`
- `Model`
- `Session ID`
- `monitorUrl`
- `monitorHtmlPath`
- `resultPath`

推荐回复模板：

```text
结论：任务已经交给 sidecar。

- Task ID: <task-id>
- Mode: <mode>
- Model: <model>
- Session ID: <session-id>
- 监控链接: <monitorUrl>
- 本地监控页: <monitorHtmlPath>
- 结果文件: <resultPath or pending>

你现在可以直接打开监控链接，在 Codex 右侧浏览器里实时看 sidecar 在做什么。
```

## 仓库结构

```text
.
├── README.md
├── SKILL.md
├── .opencode-bridge/
│   ├── README.md
│   ├── MODEL-ROUTING.md
│   ├── config.json
│   ├── tests/
│   └── *.ps1
└── docs/
    └── superpowers/
```

说明：

- `README.md` 是给人类读的入口
- `SKILL.md` 是给 Codex 读和执行的技能说明
- `.opencode-bridge/` 是真正的 V3 桥接实现
- `docs/` 里保留了设计与计划文档

## 对外使用方式

如果你是人类使用者：

- 看这个首页 README
- 把仓库链接交给 Codex
- 用自然语言下发任务
- 派发后直接打开返回的监控链接

如果你是 Codex / agent：

- 读取根目录 [SKILL.md](./SKILL.md)
- 按里面的模式、模型、等待规则和监控回复模板执行

## 验证

当前仓库内置了两类检查：

- [`.opencode-bridge/tests/Test-Bridge.ps1`](./.opencode-bridge/tests/Test-Bridge.ps1)
- [`.opencode-bridge/tests/Test-OpenCodeSidecarSkill.ps1`](./.opencode-bridge/tests/Test-OpenCodeSidecarSkill.ps1)

## 补充说明

- OpenCode 的 provider 认证仍然由 OpenCode 自己管理
- 写任务必须显式授权，不能从历史偏好里自动推断
- 这个仓库的重点是“让 sidecar 真能被复用，并且让监控入口对用户可见”
