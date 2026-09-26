# Fcitx Status for Omarchy

English | [简体中文](README.zh-CN.md)

![Fcitx Status for Omarchy](preview.png)

An Omarchy 4 bar plugin that shows the Fcitx5 state of the focused window in real time:

- `中`: Fcitx5 is active and using `rime`.
- `EN`: Fcitx5 is inactive or using `keyboard-us`.
- `--`: Fcitx5 is not running, there is no current input context, or the state cannot be recognized.

Right-click the status text for three actions: **Chinese**, **English**, and **Restart**.

## Actions

- **Chinese**: Select `rime` for the focused window, then activate Fcitx5.
- **English**: Select `keyboard-us` for the focused window, then deactivate the input method.
- **Restart**: Call `Restart` on the Fcitx5 Controller D-Bus interface. If the service has exited, fall back to restarting Omarchy's `omarchy-fcitx5.service`.

`rime` is an Fcitx5 input method ID; `rime_ice` is the name of a scheme inside Rime. They refer to different layers.

## Install

```bash
omarchy plugin add https://github.com/manateelazycat/omarchy-fctix-status.git --enable --yes
```

The plugin appears on the right side of the bar by default.

## Update

```bash
omarchy plugin update io.github.manateelazycat.fcitx-status --yes
```

## Remove

```bash
omarchy plugin remove io.github.manateelazycat.fcitx-status --yes
```

Removing the plugin does not change or remove existing Fcitx5, Rime, or input method settings.

## Requirements

- Omarchy 4 (Quattro) and its Quickshell plugin system
- Running Fcitx5 with `keyboard-us` and `rime` in the current input method group
- `fcitx5-remote`, `jq`, `dbus-monitor`, and `busctl`
- Omarchy's `omarchy-fcitx5.service` or an available `fcitx5` command as a fallback when D-Bus restart fails

The plugin does not install software, request elevated privileges, or rewrite Fcitx5/Rime configuration.

## Development and validation

```bash
omarchy plugin validate .
./tests/fcitx-statusctl-test.sh
./scripts/fcitx-statusctl status
```

## License

This project is distributed under the [GNU General Public License v3.0](LICENSE), with SPDX identifier `GPL-3.0-only`.
