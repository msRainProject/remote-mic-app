# 鼠标模式设置窗口证据

- 2026-10-04，源码提交 `a3de49a80a18f0376b19e4763fbb6dd3adaee34a`；1.9.21 / Build 228，Apple Silicon 本地 Debug UI 构建。
- 使用现有 `SettingsScreenshotRenderer` 交互入口运行生产 `SettingsView`，在 `1020 × 772` 最小窗口选择“系统与媒体”或滚动至模式状态。中英文、浅色/深色、动作编辑和开启状态共 8 张功能截图，另有 1 张未绑定鼠标模式的映射开启对照。
- 模式开启图通过 HID 菜单长按报告驱动实例状态；权限与鼠标输出注入测试值，不启动真实蓝牙、语音或鼠标事件。顶部“正在初始化蓝牙”和编辑器中的监听未启用属于截图环境；不能据此判断真机可用。
- 图像是窗口捕获工具返回的原始 JPEG 字节，未缩放、重绘或重新压缩。每张均检查标题、导航、主要控件、滚动、字号与对比度；尺寸和 SHA-256 如下。
- 中文动作和状态显示正常；英文动作沿用现有单行截断。英文页头在启用自定义映射时可出现左端裁切，未绑定鼠标模式的对照也复现（见 baseline 图），因此不能将英文最小窗口整体判为通过，仍需独立处理。按键、连接、回眸、设置导航与滚动已在中文最小窗口逐页检查，未改变窗口几何。
- 本地 UI 构建只用于代理检查，不是可交付安装包；Developer ID 签名、公证和实机矩阵尚未执行。测试步骤见[测试手册](../../Testing/ButtonMouseMode.md)，PR 保持 Draft。

| 文件 | 格式 | 像素尺寸 | SHA-256 |
| --- | --- | --- | --- |
| [active-en-dark.jpg](active-en-dark.jpg) | JPEG | 1020 × 772 | `2b59091fa1f2995100ff448b34c5b226285cb0593c6f151a213412653dc6ea84` |
| [active-en-light.jpg](active-en-light.jpg) | JPEG | 1020 × 772 | `f873bb795c08ecd338e98591070787450b89d823563fd3e67fccbd4652a6fd17` |
| [active-zh-hans-dark.jpg](active-zh-hans-dark.jpg) | JPEG | 1020 × 772 | `dc1eb9e45ad34e5ba58a52f899bea6a09441f56bcc7f809574b1a566821d417d` |
| [active-zh-hans-light.jpg](active-zh-hans-light.jpg) | JPEG | 1020 × 772 | `a83d53c8318ff1f232e88d11205229e81de2f86d1c709d362bd489e5c70030ad` |
| [baseline-enabled-en-light.jpg](baseline-enabled-en-light.jpg) | JPEG | 1020 × 772 | `157a4eafcae84bc0a7be5f3f26c7f587c849d5ab9313306d90df8f01d202202b` |
| [editor-en-dark.jpg](editor-en-dark.jpg) | JPEG | 1020 × 772 | `35042fbc96f66a097344965ef281fae370524639bcc1c6b236b1fdd3b595cb69` |
| [editor-en-light.jpg](editor-en-light.jpg) | JPEG | 1020 × 772 | `d0070a90ede4b4e324848b1b72d689bddffa1d75c47363146e56a9b0d6c3be31` |
| [editor-zh-hans-dark.jpg](editor-zh-hans-dark.jpg) | JPEG | 1020 × 772 | `d83330db40e4b4b503c8d3e123f10a5decce1240f42a0b7261febba9dd7d6894` |
| [editor-zh-hans-light.jpg](editor-zh-hans-light.jpg) | JPEG | 1020 × 772 | `72c02271f72392074a9efea1d25b97159727a80d9bd0aa767545558e8a991768` |

## 滚轮补充证据

- 2026-10-04，源码提交 `c2fea4e64d05a7c8585f796eefd502fd4c101b13`；1.9.21 / Build 228，Apple Silicon Release，本地 ad-hoc UI 检查构建。
- 相同生产交互入口和最小 `1020 × 772` 窗口；增加中英文浅色/深色共 4 张状态截图，提示加减键滚动。逐张检查文字、对比度、导航、滚动和控件边界。新增状态提示均完整可见；本次没有修改或宣称修复之前记录的英文页头布局问题。
- 使用隔离测试配置、HID 长按回放和注入权限/输出，不是实体遥控器、真实系统滚轮或语音验收。图像保留捕获接口返回的原始 JPEG 字节。

| 文件 | 格式 | 像素尺寸 | SHA-256 |
| --- | --- | --- | --- |
| [scroll-active-en-dark.jpg](scroll-active-en-dark.jpg) | JPEG | 1020 × 772 | `900f71b5a7fc790c1941f8dc4a18a60072c24007f188c3d2499434ac71427dbb` |
| [scroll-active-en-light.jpg](scroll-active-en-light.jpg) | JPEG | 1020 × 772 | `4c3c7efa67404f57c330d112616bfd44b28035a7b5bb3f9b78196c214b6c0c1a` |
| [scroll-active-zh-hans-dark.jpg](scroll-active-zh-hans-dark.jpg) | JPEG | 1020 × 772 | `681951ae8c8899d757fb6b8c4437e01161777fe5e037e89275e18e3bd4cfba7f` |
| [scroll-active-zh-hans-light.jpg](scroll-active-zh-hans-light.jpg) | JPEG | 1020 × 772 | `2202ae96ef27234e29ebd2e8c52fa8f157abba55357bfaaddc3b178f31c190c9` |

## 右键补充证据

- 2026-10-04，源码提交 `666b6dea67ff0a37de011a39220fff21fd7e16fb`；1.9.21 / Build 228，Apple Silicon Release 本地 ad-hoc UI 检查构建。
- 相同生产交互入口，真实窗口为最小/默认 `1020 × 772` points；本次捕获接口输出为 Retina 原始 `2040 × 1544` JPEG，与旧图的像素密度不同，未缩放或重新压缩。
- 中英文浅色/深色共 4 张，逐张检查新增菜单右键提示、退出方法、字号、对比度、导航和滚动边界，状态文案完整可见。原绑定仍显示普通模式动作，开启状态解释临时接管。没有改动或宣称修复历史英文页头问题。
- 使用隔离配置、HID 长按回放和注入权限/输出；这些图不证明实际遥控器右键、蓝牙、系统权限或语音验收。

| 文件 | 格式 | 像素尺寸 | SHA-256 |
| --- | --- | --- | --- |
| [right-click-active-en-dark.jpg](right-click-active-en-dark.jpg) | JPEG | 2040 × 1544 | `64b56599c24c64d177db7547eb0fafc005bc89cfcbf60b853834164be327539f` |
| [right-click-active-en-light.jpg](right-click-active-en-light.jpg) | JPEG | 2040 × 1544 | `c0d468a15788feab98a99174c9ffd0f74571a58ac59642856f4047db3a5cd464` |
| [right-click-active-zh-hans-dark.jpg](right-click-active-zh-hans-dark.jpg) | JPEG | 2040 × 1544 | `7371e4097c39dc1e655771bf780175c4e4b1475d21c3d2dbde51280d7146ffa5` |
| [right-click-active-zh-hans-light.jpg](right-click-active-zh-hans-light.jpg) | JPEG | 2040 × 1544 | `be27696c9e5d4e34508b239ec9beea1dfd04683a967e9ad250015cac5c5a3db3` |
