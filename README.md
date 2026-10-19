# MPV播放器一键脚本安装 VapourSynth 的 MVTools 插帧/补帧功能

## Windows 用户安装教程
### 前置条件 python（已安装的跳过此步骤）
- 安装 python [https://www.python.org/downloads](https://www.python.org/downloads)
- 安装完 python 后再安装 pip  
先检查是否已安装 pip，打开cmd命令行工具，按快捷键`Win+r` 输入 `cmd`，复制以下命令执行

```bash
pip --version
```

如果没有输出版本号，再复制以下命令执行安装
```bash
python -m ensurepip --default-pip
```
### 安装 VapourSynth MVTools 步骤
- 下载文件 [Install-VsMVTools.ps1](https://github.com/mpvConfig/mpvTools/blob/main/Install-VsMVTools.ps1)
- 放到 mpv播放器根目录下（`mpv.exe`同目录）
- 选中 `Install-VsMVTools.ps1`文件：右键 > 使用 powerShell 运行
- 运行成功会自动增加快捷键到 `input.conf` 右键菜单，无需任何操作设置
- 执行完后重启播放器，可通过右键菜单选择启用插帧
