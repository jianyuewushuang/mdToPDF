---
style: tikzflora
title: "花草样式示例"
author: [你的名字]
date: "2026-11-04"
subject: "Markdown"
keywords: [关键词, tikzflora]
subtitle: "水彩花草页边装饰"
titlepage: true
titlepage-rule-color: "00727c"
colorlinks: true
block-headings: true
toc: true
toc-own-page: true

# tikzflora 绘制参数（可逐项覆盖默认值）
flora-seed: 3
flora-visitors: 0.6
flora-mix: "lily=2, umbel=2, ghost=0"
flora-palette: "leaves=green"
flora-ornaments: "sun_crest=6, cul_de_lampe=3"
# 矢量金饰明显快于光栅金饰；想完全复刻示例的华丽效果可改为 raster
flora-gilt: vector
# flora-giltdpi: 150          # 仅 gilt=raster 时生效，长文档建议调低
---

> [!NOTE]
> 本文件使用 `style: tikzflora`。封面页有冠饰与尾饰，目录页有环绕花环，
> 正文页花草沿外侧页边逐页生长，页面留白处也会自动填充。

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
