# Dynamic Sticker Pack Skill

一个面向 Codex 的动态表情包工作流 Skill：从角色参考图出发，规划表情、生成统一源图、使用 MiniMax H3 制作短动画，再转换为可无限循环的 GIF，并完成媒体与视觉验收。

## 能做什么

- 锁定角色五官、轮廓、标志性配饰和画面风格
- 规划一组适合动画的表情与动作
- 生成白底或指定背景的方形表情源图
- 编写稳定文字、固定镜头的 MiniMax H3 动作提示词
- 串行生成短视频并检查角色漂移
- 自动判断直接循环或首尾融合
- 输出带独立调色板和无限循环标记的 GIF
- 可选移除与画面边缘连通的近白背景，并保护白色主体纹理
- 检查分辨率、帧率、时长、文件大小、白底和循环接缝

## 目录

```text
dynamic-sticker-pack/
|-- SKILL.md
|-- README.md
|-- LICENSE
|-- NOTICE
|-- THIRD_PARTY_NOTICES.md
|-- agents/openai.yaml
|-- scripts/convert-sticker-gifs.ps1
|-- scripts/remove-connected-white-background.py
`-- references/
    |-- source-images.md
    |-- minimax-h3.md
    |-- gif-and-qa.md
    `-- transparent-background.md
```

## 安装

把整个 `dynamic-sticker-pack` 文件夹复制到：

- Windows：`C:\Users\<用户名>\.codex\skills\dynamic-sticker-pack`
- macOS/Linux：`~/.codex/skills/dynamic-sticker-pack`
- 设置了 `CODEX_HOME` 时：`$CODEX_HOME/skills/dynamic-sticker-pack`

也可以直接克隆到默认 Skill 目录：

```powershell
git clone https://github.com/gKev1n/dynamic-sticker-pack.git "$env:USERPROFILE\.codex\skills\dynamic-sticker-pack"
```

```bash
git clone https://github.com/gKev1n/dynamic-sticker-pack.git "${CODEX_HOME:-$HOME/.codex}/skills/dynamic-sticker-pack"
```

重新打开 Codex 会话后，可以显式调用：

```text
$dynamic-sticker-pack 基于这张角色图生成一套可爱动态表情包
```

Skill 默认允许自动发现。

## GIF 转换脚本

依赖 PowerShell 7、FFmpeg 和 FFprobe：

```powershell
pwsh -File scripts/convert-sticker-gifs.ps1 `
  -InputPath "D:\stickers\video" `
  -OutputDirectory "D:\stickers\GIF\final" `
  -LoopMode Auto `
  -Json
```

脚本默认不覆盖已有文件。执行 `Get-Help scripts/convert-sticker-gifs.ps1 -Full` 可查看尺寸、帧率、颜色数、融合时长和覆盖开关。

## 可选透明背景

对于纯白或近白背景，可先在一张完整 GIF 上试运行：

```powershell
python scripts/remove-connected-white-background.py `
  "D:\stickers\GIF\final\01-happy.gif" `
  --output-dir "D:\stickers\GIF\transparent" `
  --json
```

该脚本依赖 Python 3、Pillow、NumPy 和 SciPy。它只移除与画面边缘连通的低纹理近白区域，比普通白色色键更适合白色角色，但不能替代语义分割模型。批量处理前必须在彩色底上检查完整动作。

## 外部依赖

- 源图阶段需要可用的图像生成或编辑工具
- H3 阶段需要用户已有且获准启动的 MiniMax H3 / ComfyUI 环境
- GIF 阶段需要 `ffmpeg` 与 `ffprobe`
- 可选透明背景脚本需要 `Pillow`、`NumPy` 与 `SciPy`

仓库不包含模型、运行时、用户素材或生成结果。

## 许可证

本仓库自有代码和文档采用 [Apache License 2.0](LICENSE)，版权声明见 [NOTICE](NOTICE)。

MiniMax H3、ComfyUI、FFmpeg、FFprobe、Pillow、NumPy 和 SciPy 均为外部项目，本仓库不分发或重新授权它们。输入素材、模型、工作流及生成结果也不自动受本仓库许可证覆盖；详情见 [THIRD_PARTY_NOTICES.md](THIRD_PARTY_NOTICES.md)。
