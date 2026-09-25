---
title: "标题"
author: [你的名字]
date: "2026-09-12"
subject: "Markdown"
keywords: [关键词, markdown]
subtitle: "副标题"
titlepage: true
titlepage-rule-color: "00727c"
titlepage-background: "C:/Users/jianyuewushuang/document/code/programs/mdToPDF/resources/background.pdf"
page-background: "C:/Users/jianyuewushuang/document/code/programs/mdToPDF/resources/background.pdf"
colorlinks: true
block-headings: true
toc: true
toc-own-page: true
---

## 二级标题

### 三级标题

#### 四级标题

##### 五级标题

###### 六级标题

正文

**加粗**

*斜体*

***加粗斜体***

- 无序列表
- 无序列表

1. 有序列表
2. 有序列表

> [!CAUTION]
> 警告

```python
# Python代码块
print("Hello, World!")
```

| 项目 | 占比 |
| --- | --- |
| 期末（闭卷） | 60% |
| 平时成绩 | 40% |
| 每堂课笔记作业 | 10% |
| 期中检测 + 平时作业 | 30% |

$$P(\text{甲胜}) = \frac12 + \frac14 = \frac34,\quad P(\text{乙胜}) = \frac14$$

(´▽`ʃ♡ƪ)ᓚᘏᗢ😋✊😊❤✓

```mermaid
stateDiagram-v2
    [*] --> NOMINAL
    NOMINAL --> DEGRADED_A: 单传感器失效
    DEGRADED_A --> NOMINAL: 传感器恢复
    NOMINAL --> DEGRADED_B: 单舵面/单发失效
    DEGRADED_B --> EMERGENCY: 性能不足/包线越界
    NOMINAL --> EMERGENCY: 链路丢失超时/双IMU失效/火警
    DEGRADED_A --> EMERGENCY: 冗余耗尽
    EMERGENCY --> RTL_OR_LOITER: 自主返航或盘旋等待
    EMERGENCY --> PARACHUTE: 姿态不可控/结构损伤
    EMERGENCY --> DITCH: 迫降
```

![图片](resources/background.pdf)
