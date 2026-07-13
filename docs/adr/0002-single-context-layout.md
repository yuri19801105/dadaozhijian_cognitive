# ADR-0002: 单上下文文档布局

## 状态

已接受

## 背景

部分工程技能(`improve-codebase-architecture`、`diagnosing-bugs`、`tdd`)会读取 `CONTEXT.md` 与 `docs/adr/` 来学习领域语言与历史决策。需要确定这些领域文档的布局。

## 决策

采用**单上下文布局**:一个 `CONTEXT.md` + 一个 `docs/adr/` 目录,均置于仓库根。不引入 `CONTEXT-MAP.md`(多上下文/monorepo 布局)。

## 理由

- 本项目为单一认知模型构想,无独立前后端上下文,单上下文已足够。
- 与全局 Matt Pocock 技能配置保持一致(见 `~/.claude/CLAUDE.md` 的 Agent skills 块),降低跨环境认知负担。

## 影响

- 技能在探索代码前读取根 `CONTEXT.md` 与 `docs/adr/`。
- 若未来演化为 monorepo,再经 `/domain-modeling` 升级为多上下文布局。
