# Fcitx Status for Omarchy

![Fcitx Status for Omarchy](preview.png)

一个 Omarchy 4 状态栏插件，实时显示当前聚焦窗口的 Fcitx5 状态：

- `中`：Fcitx5 已激活并正在使用 `rime`
- `EN`：Fcitx5 未激活或正在使用 `keyboard-us`
- `--`：Fcitx5 未运行、当前没有输入上下文，或状态不可识别

右键点击状态文字会显示三个操作：**中文**、**英文**、**重启**。

## 操作语义

- **中文**：为当前聚焦窗口选择 `rime`，然后激活 Fcitx5。
- **英文**：为当前聚焦窗口选择 `keyboard-us`，然后停用输入法。
- **重启**：调用 Fcitx5 Controller D-Bus 接口的 `Restart`；当服务已经退出时，回退到重启 Omarchy 的 `omarchy-fcitx5.service`。

`rime` 是 Fcitx5 输入法 ID；`rime_ice` 是 Rime 内部方案名，两者不是同一层级的名称。

## 安装

```bash
omarchy plugin add https://github.com/manateelazycat/omarchy-fctix-status.git --enable --yes
```

插件默认显示在状态栏右侧。

## 更新

```bash
omarchy plugin update io.github.manateelazycat.fcitx-status --yes
```

## 卸载

```bash
omarchy plugin remove io.github.manateelazycat.fcitx-status --yes
```

卸载插件不会修改或删除现有的 Fcitx5、Rime 或输入法配置。

## 依赖

- Omarchy 4（Quattro）及其 Quickshell 插件系统
- 正在运行的 Fcitx5，当前输入法组包含 `keyboard-us` 和 `rime`
- `fcitx5-remote`、`jq`、`dbus-monitor` 和 `busctl`
- Omarchy 的 `omarchy-fcitx5.service`，或可用的 `fcitx5` 命令，作为 D-Bus
  重启失败时的回退方式

插件不会安装软件、请求提权或改写 Fcitx5/Rime 配置。

## 开发与验证

```bash
omarchy plugin validate .
./tests/fcitx-statusctl-test.sh
./scripts/fcitx-statusctl status
```

## 许可证

本项目依据 [GNU General Public License v3.0](LICENSE) 发布，SPDX 标识为
`GPL-3.0-only`。
