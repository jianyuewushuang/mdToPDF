---
title: "花草样式示例"
author: [你的名字]
date: "2026-11-04"
subject: "Markdown"
keywords: [关键词, tikzflora]
subtitle: "水彩花草页边装饰"
titlepage: true
colorlinks: true
block-headings: true
toc: true
toc-own-page: true

style: tikzflora
# 标题页布局：title / flank / wreath / bouquet / scrollwork（默认 flank）
# 五种均按 tikzflora 原版排版，文字依次取 title / subtitle / author / date
flora-title-layout: bouquet
# flora-title-letters: false   # 关闭雕刻体大写字母（中文标题会自动回退为普通文字）
# flora-title-ornaments: "wreath=3"   # 按位置加权装饰件

# 正文布局：默认 split（区分左右页，tikzflora 原样）
# centered 会自动切换为对称边距，文字块在每页居中，花草左右对称生长
flora-layout: centered
# flora-header: "Florilegium"   # 外侧页眉文字，默认取 title

# 新版设置键
# flora-backdrop: dark          # light / dark / #rrggbb，dark 时自动加深色底色
# flora-cache: false            # 关闭 <jobname>-flora/ 页面缓存

# tikzflora 绘制参数（可逐项覆盖默认值）
flora-seed: 3
flora-visitors: 0.6
flora-mix: "lily=2, umbel=2, ghost=0, feather=2, fan=2"
flora-palette: "leaves=green"
flora-ornaments: "sun_crest=6, cul_de_lampe=3"
# 矢量金饰明显快于光栅金饰；想完全复刻示例的华丽效果可改为 raster
flora-gilt: vector
# flora-giltdpi: 150          # 仅 gilt=raster 时生效，长文档建议调低
---

> [!NOTE]
> 本文件使用 `style: tikzflora`，页面样式参考 tikzflora 自带示例：页眉为外侧
> 小型大写文字、页脚外侧为页码，均无分隔横线；目录页有环绕花环。封面选用
> `bouquet` 标题页布局，标题文字按 title / subtitle / author / date 依次填充。
> `flora-layout: centered` 让正文文字块在每页居中、花草左右对称生长；页面
> 留白处花草也会自动填充。新版运行时默认启用页面缓存并降低 PDF 压缩级别。

## 二级标题

### 三级标题

#### 四级标题

##### 五级标题

###### 六级标题

中文正文与 **加粗**、*斜体*、***加粗斜体***。

- 无序列表
- 无序列表

\newpage

1. 有序列表
2. 有序列表

> [!TIP]
> 提示框由 `alerts.lua` 渲染，两种样式共用。

五种提示块在 tikzflora 下同样可用：

> [!WARNING]
> 警告

```python
# Python 代码块
print("Hello, World!")
```

| 项目 | 占比 |
| --- | --- |
| 期末（闭卷） | 60% |
| 平时成绩 | 40% |

$$P(\text{甲胜}) = \frac12 + \frac14 = \frac34$$

(´▽`ʃ♡ƪ)ᓚᘏᗢ😋✊😊❤✓↔−

\vspace{5cm}

> 上面留出的空白会被花草长满。

```mermaid
stateDiagram-v2
    [*] --> NOMINAL
    NOMINAL --> EMERGENCY: 严重故障
    EMERGENCY --> [*]
```

![图片](resources/background.pdf)
