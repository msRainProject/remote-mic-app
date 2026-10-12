# 顺序按键生产 UI 证据

源码提交：`45360554ff6fad69ebe91ea930bf45accbb579df`。版本 `1.9.21`，本地 debug 构建，用于界面检查，不是签名公证安装包。

使用现有生产 `SettingsScreenshotRenderer` 的 interactive 入口，隔离 UserDefaults、生产 SettingsView 和实际 NSWindow；内容尺寸为默认/最小 `1020 × 772 pt`，CUA 保存原始 JPEG 字节 `2040 × 1544 px`（2x），没有裁剪、缩放、重绘或重新压缩。窗口标题为 `SayAll — Settings Review`；截图展示客户端内容，原生窗口按钮通过 AX 可访问。

已逐张检查中英文浅色/深色的页头、侧栏、动作选择、步骤编号、编辑操作、字体、对比度及纵向滚动。configured 是五步脱敏示例；keyboard 是向下滚动后的标准键盘；empty 是清空后的状态。中文浅色实际窗口中完成添加、上移、删除、清空及所有可见侧栏入口检查。键区和后续步骤通过既有纵向滚动访问，不改变窗口几何。

此模式不启动蓝牙/HID或音频、不改用户映射；初始化蓝牙是 fixture 占位状态。截图不证明真实遥控器或目标 App 收到按键。测试和未覆盖边界见 [测试手册](../../Testing/KeySequences.md)。

| 文件 | 格式与像素 | SHA-256 |
| --- | --- | --- |
| [configured-en-dark.jpg](configured-en-dark.jpg) | JPEG 2040 × 1544 | 18fa697995167a120e487bbb40e346d39ee236faacdda98e5f4a354429380a48 |
| [configured-en-light.jpg](configured-en-light.jpg) | JPEG 2040 × 1544 | 61b1a76f3f0b3861d8ff46f936dbc00cd2ddb6e2c1867e58d4bb51c7b1489c6e |
| [configured-zh-hans-dark.jpg](configured-zh-hans-dark.jpg) | JPEG 2040 × 1544 | 780943411dbab96db67fa938290dd298d1fd152dd0c6dcc35999c3125e3c7131 |
| [configured-zh-hans-light.jpg](configured-zh-hans-light.jpg) | JPEG 2040 × 1544 | 2486be929c7eef91fdc007a8a0c4d75de2c6b42f867b93bf2aeafbaedc22f1c1 |
| [empty-zh-hans-dark.jpg](empty-zh-hans-dark.jpg) | JPEG 2040 × 1544 | 4d2809a0a28c607176912d6ccef543e5fe27e5534acf7183b54f08d713a8e181 |
| [keyboard-zh-hans-dark.jpg](keyboard-zh-hans-dark.jpg) | JPEG 2040 × 1544 | e23259775e0128b60e2dae56af59fc95c2b7218e97d06976c3fb51d59650e70e |
| [keyboard-zh-hans-light.jpg](keyboard-zh-hans-light.jpg) | JPEG 2040 × 1544 | c5adaf26f4b5e147197a2f919b0b1821472a62456099bfc8bda0fa0a6e421900 |
