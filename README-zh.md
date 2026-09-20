# mdToPDF

> 本项目已开源至[github](https://github.com/jianyuewushuang/mdToPDF?tab=readme-ov-file)和[gitlink](https://www.gitlink.org.cn/jianyuewushuang/mdToPDF)（国内网络友好）。

一个基于 **Pandoc + LuaLaTeX** 的中文 Markdown转PDF项目。

该项目基于[Eisvogel](https://github.com/Wandmalfarbe/pandoc-latex-template)改进而来，进行了大量中文适配。

支持六级标题分级字号、中文伪粗体/伪斜体、彩色 emoji 与特殊符号、github风格提示框、
代码高亮、表格与数学公式，适合把课程笔记、实验报告、文档直接排版成精致美观的 PDF。

## 预览

![预览图](./preview/example_01.avif)

![预览图](./preview/example_02.avif)

![预览图](./preview/example_03.avif)

![预览图](./preview/example_04.avif)

## 特性

- **六级标题分级字号**：`#` ~ `######` 逐级递减，层级清晰。
- **中文加粗 / 斜体**：通过 `AutoFakeBold` / `AutoFakeSlant` 使得无加粗和斜体的字体也可进行合成。
- **彩色 emoji 与特殊符号**：使用 `lualatex` + `mainfontfallback` ，可渲Unicode字符和彩色表情符号。
- **github风格提示框**：借助 `alerts.lua` 过滤器渲染
  `note / tip / important / warning / caution` 五种彩色提示块。
- **代码高亮、表格、数学公式**：基于 Pandoc 原生支持，语法高亮风格为 `idiomatic`。
- **标题页 / 目录 / 链接着色**：通过 YAML 格式Front Matter开关控制。

## 目录结构

```
mdToPDF/
├── src/                    # 存放 Markdown 源文件
│   └── example.md          # Markdown文件示例
├── build/                  # 构建产物目录，PDF 由 build.ps1 自动生成
├── preview/                # 示例构建产物及其预览图
├── resources/              # 模板与资源
│   ├── latex/
│   │   ├── eisvogel.latex  # LaTeX 模板
│   │   └── eisvogel.beamer # beamer 模板
│   ├── alerts.lua          # gitub风格提示框 Lua 过滤器
│   └── background.pdf      # 标题页 / 页面背景图
├── build.ps1               # Windows 系统构建脚本
└── LICENSE.md              # PolyForm Noncommercial License 1.0.0
```

## 环境要求

| 组件 | 版本 / 说明 |
| --- | --- |
| [Pandoc](https://pandoc.org/installing.html) | 安装教程可参考[我写的一篇博文](https://blog.jianyuewushuang.top/2026/05/09/pandoc%E6%8A%80%E6%9C%AF%E6%96%87%E6%A1%A3/) |
| [TeX Live](https://www.tug.org/texlive/) | 安装教程可参考[我写的另一篇博文](https://blog.jianyuewushuang.top/2026/03/26/LaTex%E6%8A%80%E6%9C%AF%E6%96%87%E6%A1%A3/) |
| 字体 | `SimSun`、`Source Sans 3`、`Noto Color Emoji`、`FreeSans`、`DejaVu Sans` |

字体说明：`SimSun`用于中文正文；`Source Sans 3` 为西文主字体；
`Noto Color Emoji / FreeSans / DejaVu Sans` 组成 emoji 与特殊符号的回退链。

## 使用方法

### 一键构建

把 Markdown 文件放进 `src/`，然后运行构建脚本：

```powershell
.\build.ps1
```

脚本会遍历 `src/` 下所有 `*.md`，逐个生成同名 `build/<name>.pdf`。

构建脚本参数：

- 输入格式：`markdown+alerts`
- 模板：`resources/latex/eisvogel.latex`
- 引擎：`lualatex`
- 过滤器：`resources/alerts.lua`
- 语法高亮：`idiomatic`
- 中文主字体：`SimSun`；西文主字体：`Source Sans 3`
- emoji / 符号回退链：`Noto Color Emoji` → `FreeSans` → `DejaVu Sans`

### 单文件构建

```powershell
pandoc .\src\example.md -o .\build\example.pdf `
  --from markdown+alerts `
  --template ".\resources\latex\eisvogel.latex" `
  --syntax-highlighting idiomatic `
  --pdf-engine "lualatex" `
  -V CJKmainfont="SimSun" `
  -V mainfont="Source Sans 3" `
  -V mainfontfallback="Noto Color Emoji:mode=harf" `
  -V mainfontfallback="FreeSans:mode=harf" `
  -V mainfontfallback="DejaVu Sans:mode=harf" `
  --lua-filter ".\resources\alerts.lua"
```

## 编写 Markdown

### Front Matter

在 `.md` 文件顶部用 YAML 块设置标题、作者、目录、标题页等：

```markdown
---
title: "标题"
author: [你的名字]
date: "2026-09-12"
subject: "Markdown"
keywords: [关键词, markdown]
subtitle: "副标题"
titlepage: true            # 启用封面页
titlepage-rule-color: "00727c"
titlepage-background: "<绝对路径>"   # 标题页背景
page-background: "<绝对路径>"        # 正文页背景
colorlinks: true          # 链接着色
block-headings: true      # 标题独占一行
toc: true                 # 目录
toc-own-page: true        # 目录单独成页
---
```

> [!NOTE]
> 在测试时发现背景使用绝对路径无法正常构建，如有其他疑问，欢迎在Issues板块讨论。

### github风格提示框

使用 GitHub 风格的 `> [!TYPE]` 引用语法，由 `alerts.lua` 渲染为彩色块：

```markdown
> [!NOTE]
> 说明
```

> [!NOTE]
> 说明

```markdown
> [!TIP]
> 技巧
```

> [!TIP]
> 技巧

```markdown
> [!IMPORTANT]
> 重要
```

> [!IMPORTANT]
> 重要

```markdown
> [!WARNING]
> 警告
```

> [!WARNING]
> 警告

```markdown
> [!CAUTION]
> 危险
```

> [!CAUTION]
> 危险

## 自定义

- **改模板**：编辑 `resources/latex/eisvogel.latex`（标题字号、字体、配色、页眉页脚等）。
- **改github风格提示框样式**：编辑 `resources/alerts.lua`（颜色、边框、标题文案）。
- **改构建流程**：编辑 `build.ps1`。
- **参考上游**：有其他问题也可参考上游项目[Eisvogel](https://github.com/Wandmalfarbe/pandoc-latex-template)。

## LICENSE

本项目基于 [PolyForm Noncommercial License 1.0.0](LICENSE.md) 发布。

> Required Notice: Copyright 2026 jianyuewushuang <jianyuewushuang@163.com>

非商业用途可自由使用、修改与分发；如需商业用途请联系作者。
