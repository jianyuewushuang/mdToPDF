# 样式注册表

本目录下的每个 `*.conf` 文件描述一种样式，文件名就是 Front Matter 中
`style` 字段可用的取值。构建脚本会枚举 `*.conf` 得到可用样式清单，
因此**新增样式不需要改动构建脚本主体逻辑**。

## 选择样式

在 Markdown 开头的 YAML Front Matter 中写：

```yaml
---
style: tikzflora
---
```

省略 `style` 时默认 `eisvogel`。写入未注册的样式名时，
构建会立即失败并打印可用样式清单，不会静默回退。

## `.conf` 字段契约

格式：每行 `KEY=VALUE`；`#` 开头的行为注释；空行忽略。所有**路径都相对于
项目根目录**书写，脚本在调用 Pandoc 前统一拼成绝对路径。

| 键 | 必需 | 含义 |
| --- | --- | --- |
| `TEMPLATE` | 是 | 该样式使用的 pandoc LaTeX 模板，传给 `--template`。 |
| `TEXINPUTS` | 否 | 空格分隔的目录列表，追加到 `TEXINPUTS` 环境变量（末尾保留空项以保留系统默认搜索路径）。Pandoc 会在临时目录中运行 `lualatex`，第三方 `.sty` / `.lua` 必须由此被 kpathsea 找到。 |
| `ENV_<NAME>` | 否 | 任意额外环境变量，例如 `ENV_FLORA_LUA=...` 会让脚本设置 `FLORA_LUA`。值同样按项目根相对路径解析；可重复多行。 |
| `LUA_FILTERS` | 否 | 空格分隔的 Lua 过滤器路径，脚本拼成绝对路径后逐个加 `--lua-filter`。与共享的 `alerts.lua` / `diagram.lua` 一起按声明顺序传给 pandoc。 |
| `PANDOC_ARGS` | 否 | 空格分隔的额外 pandoc 参数（值中不含路径、不含空格，例如 `--top-level-division=chapter`）。 |

约束：

- 值中不要出现空格。
- 键名大写；未知键会被脚本忽略并给出提示，避免拼写错误被静默吞掉。
- 一套样式可以有自己的模板、自己的第三方运行时、自己的过滤器，彼此隔离；
  `resources/eisvogel.latex` 与 `resources/alerts.lua`、`diagram.lua` 等共享
  资源由两个构建脚本统一传入，不需要在每个 `.conf` 里重复声明。

## 新增一个样式的步骤

1. 在 `resources/styles/` 下新建 `<name>.latex` 模板。最简单的方式是以`resources/eisvogel.latex` 为基线复制后做定向修改。
2. 若样式需要第三方 TeX 运行时，把文件放进 `resources/vendor/<name>/`，并在 `.conf` 中用 `TEXINPUTS` 指出目录。
3. 新建 `<name>.conf`，至少写 `TEMPLATE=...`。
4. 在 `src/example-<name>.md` 加一个能覆盖主要特性的示例，并在中英文README 的 Front Matter 章节补充该样式的专有参数。
5. 分别运行 `src/build_windows.ps1` 与 `src/build_linux.sh` 验证。

无需修改 `src/build_*.ps1` / `build_linux.sh`：脚本按文件名查找 `.conf`、
解析字段、拼装命令并做错误提示。

## 内置样式

| 样式 | 模板 | 说明 |
| --- | --- | --- |
| `eisvogel` | `resources/eisvogel.latex` | 默认样式，未写 `style` 时使用。 |
| `tikzflora` | `resources/styles/tikzflora.latex` | 独立模板，水彩花草页边装饰；第三方运行时位于 `resources/vendor/tikzflora/`。 |
