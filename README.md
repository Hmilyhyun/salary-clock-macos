# Salary Clock

Salary Clock 是一个 macOS 原生桌面工资时钟。输入月薪、日薪或时薪，设置工作日、上下班时间和午休时段，即可查看当天累计收入、已工作时间和预计收入。支持跨午夜班次、中文和英文界面。

## 桌面使用

双击主窗金额进入迷你模式。拖动金额可移动迷你窗，双击可返回主窗。通过菜单栏时钟可打开主界面、切换迷你模式或调整置顶。右键迷你窗可以调整背景透明度。迷你窗开启置顶后可跨桌面显示并覆盖其他应用的全屏窗口。

主窗口在 Dock 显示运行图标。迷你模式隐藏运行图标后，macOS 仍可能保留「最近使用」图标。设置中的「迷你模式下重启 Dock 以隐藏最近使用图标」默认关闭。开启后，应用在进入迷你模式时检查自己的最近使用条目。如果找到，会移除该条目并重启当前用户的 Dock，期间 Dock 会短暂消失，窗口动画可能中断。

## 构建与运行

需要 macOS 14 或更高版本，以及支持 Swift 5.9 或更高版本的 Xcode 或 Command Line Tools。在仓库根目录执行：

```sh
./package.sh
open "build/Salary Clock.app"
```

脚本通过 Swift Package Manager 构建，打包应用和图标，并进行本机临时签名。将构建出的应用复制到「应用程序」后，可以在应用设置中开启登录启动。

薪资计算回归测试需要 Swift 6 或更高版本，可运行 `swift test --disable-xctest`。如果 Command Line Tools 未找到 `TestingMacros`，可显式指定其插件目录。

```sh
swift test --disable-xctest \
  -Xswiftc -plugin-path -Xswiftc "$(xcode-select -p)/usr/lib/swift/host/plugins/testing"
```

## 设置与迁移

设置保存于当前 macOS 用户的偏好中。首次启动时，如检测到兼容的旧版工资时钟配置，应用会尝试导入薪资、班次和显示偏好。窗口位置与尺寸优先使用原生版已保存的布局。

## 来源与许可

Salary Clock 是基于 [PayDance](https://github.com/MrBaoboer/PayDance) 修改的独立、非官方 macOS 版本。界面与窗口管理使用 SwiftUI 和 AppKit，薪资计算逻辑由 PayDance 移植到 Swift，应用使用独立图标。

Based on PayDance. Copyright (C) 2026 Mr.Baoboer. Licensed under the GNU Affero General Public License v3.0 only.

软件代码采用 [AGPL-3.0-only](LICENSE)。上游的[附加条款](legal/ADDITIONAL_TERMS.md)、[商标政策](legal/TRADEMARK.md)和[品牌素材说明](legal/BRAND-ASSETS.md)随源码保留。
