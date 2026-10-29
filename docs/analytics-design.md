# 家族网页访问统计设计草案（讨论稿）

> 定位：**已定案（2026-10-15）**。用户准则：独立开发者，最少投入、可行范围内最好、成本不可高 → 免费方案锁定。本文档保留全部备选作依据，执行只按下表。
>
> | 决策点 | 定案 |
> |---|---|
> | A 宿主 | 云 SaaS（自托管全面出局：家庭 80/443 封锁；Ali-HK ~24-40 CNY/月 + 运维，超出成本线） |
> | B 工具 | **百度统计，仅此一家**（免费、实测 0.13s 最稳）。Clarity 暂缓（热图非刚需，省一次注册）；Plausible 出局（$9+/月 负担不起） |
> | C pitboard 盲区 | 接受；agent 消费用 GitHub 侧数据观测。Ali-HK 迁移出局 |
> | D 接入 | **一个站点条目 `jrtx.site`（含全部子域）+ 一个 hm.js ID 覆盖全部 20 站**（已核实所有站均在该主域下），按 URL 维度拆产品流量。用户一次性投入 = 注册 + 建 1 个站点 + 回传 1 个 ID；其余全部由 agent 滚动 PR 完成 |
> | E 隐私 | 面板仅内部使用，不公开悬挂数字 |
> 下载量侧已上线：本仓库每日快照 + `jrtx.site/family-metrics/` 分析页（2026-10-15 起攒序列）。

## 0. 已定约束（2026-10-15 用户拍板 + 本机实测）

| 约束 | 内容 | 来源 |
|---|---|---|
| 家庭自托管出局 | 国内家庭网络开不了 80/443；Unraid 全部服务走非常规端口。HTTPS 页面引用 HTTP/非常规端口统计端点会被浏览器拦（混合内容） | 用户定调 |
| 大陆可达性 | Google Fonts 已因此全家族禁用；统计脚本若不可达 = 首屏等待 + 数据全盲 | 家族既定 |
| 实测可达性（本机，2026-10-15） | ✅ 百度统计 0.13s · ✅ Clarity 0.44s · ✅ Plausible 云 ~1.0s（付费）；❌ GoatCounter(gc.zgo.at) · ❌ CF Insights（尽管 jrtx.site DNS 在 CF）· ❌ Umami 云 · ❌ 51LA | curl 实测 |
| 现网无任何统计 | 81 个站点 HTML（主站+产品站+文档站）零埋点；GitHub Pages 无服务端日志，过去的数据已永久缺失，每晚一天攒序列就少一天 | 全量扫描 |

## 1. 宿主选型（决策点 A）

| 选项 | 事实 | 评估 |
|---|---|---|
| **云统计服务（SaaS）** | 百度/Clarity/Plausible 均实测可达，零运维 | **推荐起步**。代价：数据在第三方 |
| 阿里云自托管 | 已有公网入口先例（moonbeam 信令）；**注意 region**：大陆区 80/443 对外 web 服务需 ICP 备案（jrtx.site 未备案，不可行），**香港区无备案要求**、大陆访问一般稳定 | 数据主权升级位。GoatCounter 自托管=单二进制+SQLite，最省。成本 ≈24–40 CNY/月 + 运维 |
| fnOS（异地） | Docker 能力已验证（moonbeam relay 常驻）；但公网形态未知（trim-cli 本会话缺失未能探测），且若同样走非常规端口则与 Unraid 同因出局 | 暂不推荐；公网形态明确前不列候选 |
| Unraid（家庭） | **已否决**（80/443 封锁） | — |

**推荐**：SaaS 起步（先用起来、今天就开始攒数据），Ali-HK GoatCounter 自托管作为后续"数据主权"升级位——迁移成本 = 换一段 script 标签。

## 2. 工具选型（决策点 B）

| 工具 | 可达性 | 成本 | 形态 | 结论 |
|---|---|---|---|---|
| **百度统计** | ✅ 0.13s（最快） | 免费 | 云，中文面板，PV/UV/来源/地域全 | **推荐打底** |
| **Microsoft Clarity** | ✅ 0.44s | 免费 | 云，热图+会话回放，默认免 cookie、输入脱敏 | **推荐叠加**（想要热图再加） |
| Plausible 云 | ✅ ~1.0s | $9+/月 | 云，干净面板、可导出、免 cookie | 付费升级位 |
| GoatCounter 云 | ❌ 不可达 | — | — | 出局（自托管版见宿主选型） |
| CF Web Analytics | ❌ beacon 域不可达 | — | — | 出局（DNS 在 CF ≠ 统计可用） |
| Umami 云 / 51LA | ❌ 不可达 | — | — | 出局 |

**推荐**：百度统计打底 + Clarity 叠加（两者均免费、async 标签互不阻塞）。

## 3. pitboard 的特殊性（决策点 C）

pitboard 是 GitHub Pages 静态站（pages.yml + CNAME），无服务端日志。但比"没有日志"更要紧的是它的**读者构成**：pitboard 的分发模型是 agent 优先（`/skill/pitboard/SKILL.md` 直出、llms.txt、甩链接给 agent 自装）——**agent 用 curl 拉取 SKILL.md/llms.txt 不执行 JS，JS 埋点对这部分流量永久失明**。

选项：
1. **接受盲区（推荐起步）**：人类读者走埋点；agent 消费侧的替代观测面 = GitHub 侧数据（repo traffic API 的 clone/star、skill 仓库 fork）+ family-metrics 的下载快照。
2. **迁移 pitboard 回自托管 Racket web-server**（它本来就是 Racket 全栈单进程设计）：服务端日志能同时看到人和 agent。但需要一个 80/443 可达的公网宿主 → 只有 Ali-HK 路线成立；家庭/fnOS 均不可行。这与决策点 A 绑定。

**推荐**：先接受盲区 + 埋点上线；若 agent 消费数据被证明重要（pitboard 战略上是 agent 分发样板），随 Ali-HK 升级位一并迁移。

## 4. 批量接入计划（决策点 D）

范围：主站（turlamai.github.io）+ pitboard + 产品站 ~10 个仓库（合计 81 个 HTML）。

- **对「零依赖」规范的影响**：产品主页规范要求零外部依赖，其立法本意是**不阻塞首屏渲染**（Google Fonts 案）。统计信标以 `async` 加载、不阻塞渲染、不参与布局，不违反本意；建议在产品主页规范中补一条明文：*允许 async 无阻塞统计信标，禁止渲染阻塞型外部资源*。
- **滚动节奏**：Phase 1 = 主站 + pitboard（2 处，先跑通面板与口径）→ Phase 2 = 产品站逐仓库 PR（每仓库 1 个 commit，顺手验证暗色/双语页面不受影响）。
- 每站口径统一：一个站点一个百度站点 ID（或按产品分），Clarity 一个 project；family-metrics 页面本身 noindex 且内部用，不接入。

## 5. 数据主权与隐私口径（决策点 E）

- 家族站点全部是静态营销/文档页，自身不采集个人信息；统计只看 PV/UV/来源/地域粒度。
- 百度统计使用 cookie；Clarity 默认免 cookie 且输入脱敏；Plausible/GoatCounter 免 cookie。若在意口径：Clarity 可独立使用，百度面板数字仅内部使用。
- family-metrics（下载快照）数据全部来自 GitHub 公开 API，无隐私问题；分析页已 `noindex`。
- 对外披露口径：不在产品站公开悬挂访问量数字（如需晒数据，引用自家面板截图，不暴露面板地址）。

## 6. 决策点汇总

| # | 决策点 | 推荐 | 备选 |
|---|---|---|---|
| A | 统计端点宿主 | 云 SaaS 起步 | Ali-HK 自托管 GoatCounter（主权升级位） |
| B | 工具 | 百度统计 + Clarity 叠加 | Plausible（付费、干净、可导出） |
| C | pitboard agent 流量盲区 | 接受，用 GitHub 侧数据替代观测 | pitboard 迁 Ali-HK Racket 自托管（服务端日志） |
| D | 接入节奏 | 主站+pitboard 先行 → 产品站滚动 | 一次性全量 |
| E | 隐私口径 | 面板内部用、免 cookie 工具优先 | — |

**拍板后执行序**：注册百度统计账号（需用户持有账号体系）→ 拿到站点 ID → Phase 1 两站埋点 PR → 验证面板收数 → Phase 2 滚动。
