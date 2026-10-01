#!/usr/bin/env bash

set -euo pipefail

# 取绝对路径
resolve_path() {
    if command -v realpath >/dev/null 2>&1; then
        realpath "$1"
    else
        (cd "$(dirname "$1")" && printf '%s/%s\n' "$PWD" "$(basename "$1")")
    fi
}

# 切换到脚本所在目录（src/）
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
RESOURCES_DIR="$PROJECT_ROOT/resources"
BUILD_DIR="$PROJECT_ROOT/build"
MMDC_BIN="$PROJECT_ROOT/node_modules/.bin/mmdc"

# 字体（允许通过环境变量覆盖）
CJK_FONT="${CJK_FONT:-SimSun}"
MAIN_FONT="${MAIN_FONT:-Source Sans 3}"

# 代码高亮：pandoc 3.6+ 使用 --syntax-highlighting 并内置 idiomatic 样式；
# 旧版本仍使用 --highlight-style，且没有 idiomatic 时回退为默认样式
HIGHLIGHT_STYLE="${HIGHLIGHT_STYLE:-idiomatic}"
if pandoc --help 2>/dev/null | grep -q -- '--syntax-highlighting'; then
    HIGHLIGHT_ARGS=(--syntax-highlighting "$HIGHLIGHT_STYLE")
elif pandoc --list-highlight-styles 2>/dev/null | grep -qx "$HIGHLIGHT_STYLE"; then
    HIGHLIGHT_ARGS=(--highlight-style "$HIGHLIGHT_STYLE")
else
    echo "警告: 当前 pandoc 不支持高亮样式 $HIGHLIGHT_STYLE，改用默认样式" >&2
    HIGHLIGHT_ARGS=()
fi

# 字体预检：Linux 各发行版字体差异大，缺字体时 fontspec 的报错晦涩难懂，
# 这里提前给出明确提示。可用 SKIP_FONT_CHECK=1 跳过。
REQUIRED_FONTS=("$MAIN_FONT" "$CJK_FONT" "Noto Color Emoji" "FreeSans" "DejaVu Sans")
if [[ "${SKIP_FONT_CHECK:-0}" != "1" ]] && command -v fc-list >/dev/null 2>&1; then
    missing_fonts=()
    for font_name in "${REQUIRED_FONTS[@]}"; do
        if ! fc-list -q "${font_name%%:*}"; then
            missing_fonts+=("$font_name")
        fi
    done
    if [[ ${#missing_fonts[@]} -gt 0 ]]; then
        echo "错误: 缺少以下必需字体: ${missing_fonts[*]}" >&2
        echo "      请安装后重试，或用环境变量指定替代字体，例如：" >&2
        echo "      CJK_FONT=\"Noto Serif CJK SC\" MAIN_FONT=\"Noto Sans\" $0" >&2
        echo "      也可设置 SKIP_FONT_CHECK=1 跳过本检查。" >&2
        exit 1
    fi
fi

mkdir -p "$BUILD_DIR"

# 配置 mermaid-cli：diagram.lua 通过 MERMAID_BIN 环境变量调用它。
# 容器 / CI / 禁用非特权 user namespace 的 Ubuntu 上 Chromium 沙箱无法启动，
# 探测失败时自动生成带 --no-sandbox 的包装脚本（仅渲染本地可信图表）。
if command -v timeout >/dev/null 2>&1; then
    TIMEOUT_CMD=(timeout 90)
else
    TIMEOUT_CMD=()
fi

setup_mermaid() {
    if [[ ! -x "$MMDC_BIN" ]]; then
        echo "警告: 未找到本地 mermaid-cli: $MMDC_BIN" >&2
        echo "      含 Mermaid 图表的文档会构建失败；请先在项目根目录执行 npm install" >&2
        return 0
    fi
    local probe_dir cfg wrapper
    probe_dir="$(mktemp -d)"
    printf 'flowchart LR\n  A --> B\n' > "$probe_dir/probe.mmd"
    if ${TIMEOUT_CMD[@]+"${TIMEOUT_CMD[@]}"} "$MMDC_BIN" \
            --input "$probe_dir/probe.mmd" \
            --output "$probe_dir/probe.svg" >/dev/null 2>&1; then
        export MERMAID_BIN="$(resolve_path "$MMDC_BIN")"
        rm -rf "$probe_dir"
        echo "mermaid-cli 检测通过"
        return 0
    fi
    cfg="$BUILD_DIR/puppeteer-config.json"
    printf '{"args":["--no-sandbox","--disable-setuid-sandbox"]}\n' > "$cfg"
    if ${TIMEOUT_CMD[@]+"${TIMEOUT_CMD[@]}"} "$MMDC_BIN" -p "$cfg" \
            --input "$probe_dir/probe.mmd" \
            --output "$probe_dir/probe.svg" >/dev/null 2>&1; then
        wrapper="$BUILD_DIR/mmdc-wrapper.sh"
        {
            printf '#!/usr/bin/env bash\n'
            printf 'exec %q -p %q "$@"\n' "$(resolve_path "$MMDC_BIN")" "$cfg"
        } > "$wrapper"
        chmod +x "$wrapper"
        export MERMAID_BIN="$wrapper"
        rm -rf "$probe_dir"
        echo "mermaid-cli 检测通过（受限环境，使用 --no-sandbox 兼容模式）"
        return 0
    fi
    rm -rf "$probe_dir"
    echo "警告: mermaid-cli 无法启动，Mermaid 图表将被跳过" >&2
}

setup_mermaid

shopt -s nullglob
md_files=(*.md)
shopt -u nullglob

if [[ ${#md_files[@]} -eq 0 ]]; then
    echo "错误: 在 $SCRIPT_DIR 下未找到任何 .md 文件" >&2
    exit 1
fi

failed=0
for input_file in "${md_files[@]}"; do
    base="${input_file%.md}"
    output_file="$BUILD_DIR/$base.pdf"
    echo "==> 构建 $input_file -> ${output_file#"$PROJECT_ROOT"/}"
    if pandoc "$input_file" \
        -o "$output_file" \
        --from markdown+alerts \
        --template "$RESOURCES_DIR/eisvogel.latex" \
        ${HIGHLIGHT_ARGS[@]+"${HIGHLIGHT_ARGS[@]}"} \
        --pdf-engine "lualatex" \
        -V CJKmainfont="$CJK_FONT" \
        -V mainfont="$MAIN_FONT" \
        -V mainfontfallback="Noto Color Emoji:mode=harf" \
        -V mainfontfallback="FreeSans:mode=harf" \
        -V mainfontfallback="DejaVu Sans:mode=harf" \
        --lua-filter "$RESOURCES_DIR/alerts.lua" \
        --lua-filter "$RESOURCES_DIR/diagram.lua"; then
        echo "    成功"
    else
        echo "    失败: $input_file" >&2
        failed=1
    fi
done

if [[ "$failed" -ne 0 ]]; then
    echo "部分文件构建失败" >&2
    exit 1
fi
echo "全部构建完成，输出目录: $BUILD_DIR"
