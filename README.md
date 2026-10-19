# MPV 播放器一键脚本安装 VapourSynth 的 MVTools 插帧/补帧功能

## Windows 用户安装教程

- 下载文件 [Install-VsMVTools.ps1](https://github.com/mpvConfig/mpvTools/blob/main/Install-VsMVTools.ps1)
- 放到 mpv 播放器根目录下（`mpv.exe`同目录）
- 选中 `Install-VsMVTools.ps1`文件：右键 > 使用 PowerShell 运行
- 下载的东西比较多（耐心等待），运行成功会自动增加快捷键到 `input.conf` 右键菜单，无需任何操作设置
- 执行完后重启播放器，可通过快捷键启用或者右键菜单选择启用插帧

## Mac/Linux 用户

> Mac/Linux 端未测试，请自行测试（本人暂无真机进行测试，如出问题请自行 AI 修复）

### macOS，下载文件 [install-macos.sh](https://github.com/mpvConfig/mpvTools/blob/main/install-macos.sh)

给权限：

```bash
chmod +x install-macos.sh
```

运行：

```bash
./install-macos.sh
```

在脚本运行过程中，如果 Homebrew 需要密码（比如更新 Homebrew 软件库），它会**自动**在终端提示输入密码，输一下就行了。

### Linux，下载文件 [install-linux.sh](https://github.com/mpvConfig/mpvTools/blob/main/install-linux.sh)

给权限：

```bash
chmod +x install-linux.sh
```

运行：

```bash
./install-linux.sh
```
