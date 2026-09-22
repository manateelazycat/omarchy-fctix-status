# Fcitx Status for Omarchy

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

## 本地安装

代码固定保存在：

```text
/home/andy/omarchy-fctix-status
```

把源码目录链接到 Omarchy 用户插件目录，然后启用到右侧：

```bash
ln -s /home/andy/omarchy-fctix-status \
  ~/.config/omarchy/plugins/io.github.manateelazycat.fcitx-status
omarchy-shell shell rescanPlugins
omarchy plugin enable io.github.manateelazycat.fcitx-status right
```

## 验证

```bash
omarchy plugin validate /home/andy/omarchy-fctix-status
/home/andy/omarchy-fctix-status/tests/fcitx-statusctl-test.sh
/home/andy/omarchy-fctix-status/scripts/fcitx-statusctl status
```
