---
name: ponytail-help
description: "ponytail 全部模式与技能的快速参考卡。当用户说 ponytail help/怎么用 ponytail/有哪些命令/what ponytail commands 时调用。"
---

# Ponytail Help

Display this reference card when invoked. One-shot, do NOT change mode, write
flag files, or persist anything.

> Trae 适配说明：Trae 无斜杠命令，下表中的触发方式均为「在对话中直接说出短语」。
> 核心阶梯规则每轮生效（见 `.trae/rules/ponytail.md`），技能按需触发。

## Levels

| Level | Trigger (say in chat) | What change |
|-------|----------------------|-------------|
| **Lite** | "ponytail lite" | Build what's asked, name the lazier alternative in one line. |
| **Full** | "ponytail" / "be lazy" | The ladder enforced: YAGNI → stdlib → native → one line → minimum. Default. |
| **Ultra** | "ponytail ultra" / "极简模式" | YAGNI extremist. Deletion before addition. Challenges requirements before building. |

Level sticks until changed or session end.

## Skills

| Skill | Trigger (say in chat) | What it does |
|-------|----------------------|--------------|
| **ponytail** | "ponytail" / "be lazy" / "最简方案" | Lazy mode itself. Simplest solution that works. |
| **ponytail-review** | "ponytail-review" / "审查过度设计" | Over-engineering review: `L42: yagni: factory, one product. Inline.` |
| **ponytail-audit** | "ponytail-audit" / "审计代码库" | Whole-repo over-engineering audit, ranked. |
| **ponytail-debt** | "ponytail debt" / "技术债台账" | Harvest `ponytail:` shortcuts into a tracked ledger. |
| **ponytail-gain** | "ponytail gain" / "收益记分牌" | Measured-impact scoreboard: less code, less cost, more speed. |
| **ponytail-help** | "ponytail help" / "怎么用 ponytail" | This card. |

## Deactivate

Say "stop ponytail" or "正常模式". Resume anytime with "ponytail".

## Always-on rule

The core ladder lives in `.trae/rules/ponytail.md` and is active every
response. To make it stop applying, remove or rename that file.

## More

Full docs + examples: https://github.com/DietrichGebert/ponytail
