# Fcitx Status for Omarchy

English | [简体中文](README.zh-CN.md)

![Fcitx Status for Omarchy](preview.png)

An Omarchy 4 bar plugin that shows the Fcitx5 state of the focused window in real time:

- Boxed `中` icon: Fcitx5 is active and using `rime`.
- Boxed `En` icon: Fcitx5 is inactive or using `keyboard-us`.
- `--`: Fcitx5 is not running, there is no current input context, or the state cannot be recognized.

The vector icons follow the bar's theme color and icon size. The right-click menu offers **Chinese**, **English**, **Switch input method**, and **Restart**.

## Actions

- **Chinese**: Select `rime` for the focused window, then activate Fcitx5.
- **English**: Select `keyboard-us` for the focused window, then deactivate the input method.
- Choose **Switch input method** to open a searchable list of configured Rime schemas, such as Rime Ice. The current schema appears first with a check mark. Selecting a schema switches the focused window to Rime and applies that schema.
- **Restart**: Call `Restart` on the Fcitx5 Controller D-Bus interface. If the service has exited, fall back to restarting Omarchy's `omarchy-fcitx5.service`.

`rime` is an Fcitx5 input method ID; `rime_ice` is the name of a scheme inside Rime. They refer to different layers.

## Install

Set up Rime in Fcitx5 before enabling the plugin. On Omarchy, install the integration with `sudo pacman -S --needed fcitx5-rime`, then add **Keyboard - English (US)** and **Rime** to the active input method group in Fcitx5 Configuration. Configure the Rime schemas you want to see in the picker.

```bash
omarchy plugin add https://github.com/manateelazycat/omarchy-fctix-status.git --enable --yes
```

The plugin appears on the right side of the bar by default.

Install `python-yaml` if you want the picker to show display names such as 雾凇拼音. Without it, you can still search for and switch schemas by ID, such as `rime_ice`.

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
- Running Fcitx5 with the `fcitx5-rime` add-on and `keyboard-us` and `rime` in the current input method group
- `fcitx5-remote`, `jq`, `dbus-monitor`, and `busctl`
- Python 3 for listing Rime schemas, with optional PyYAML (`python-yaml` on Omarchy) for display names
- Omarchy's `omarchy-fcitx5.service` or an available `fcitx5` command as a fallback when D-Bus restart fails

The plugin does not install software or request elevated privileges.

## Development and validation

Install `python-yaml` to run the controller tests for both display names and the ID fallback.

```bash
omarchy plugin validate .
./tests/fcitx-statusctl-test.sh
./scripts/fcitx-statusctl status
```

## License

This project is distributed under the [GNU General Public License v3.0](LICENSE), with SPDX identifier `GPL-3.0-only`.
