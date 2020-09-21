# Control

Features:
- Pause on minimize.
- Improved cycle fullscreen when using mouse.
- Cycle pause with video replay at the end of playback.
- Rewind at the end of playback.
- Exit fullscreen at the end of playback.
- List and set/cycle audio devices with volume options.
- Display playback info.
- Customizable frame step.
- Hold to play with speed setting.

[`Changelog`](CHANGELOG.md)

# Installation

[`control.lua`](https://raw.githubusercontent.com/oe-d/control/master/control.lua) goes in the `scripts` folder.
[`control.conf`](https://raw.githubusercontent.com/oe-d/control/master/control.conf) goes in the `script-opts` folder.

Edit settings in `control.conf`.

Linux, macOS

`~/.config/mpv/scripts/`

`~/.config/mpv/script-opts/`

Windows

`%APPDATA%\mpv\scripts`

`%APPDATA%\mpv\script-opts`

# Key binds

See [`control.conf`](https://github.com/oe-d/control/blob/master/control.conf) for example key binds.

#### `cycle-fullscreen`
Cycle fullscreen and prevent draggable fullscreen window.

#### `cycle-pause`
Cycle pause and replay video at the end of playback.

#### `list-audio-devices`
Shows a list of audio devices. Prints device names and description to console.

#### `cycle-audio-devices`
Cycle a list of audio devices separated by space. Devices first need to be added to `control.conf`.

Usage: `no-osd` (optional) `iv#r` where `i` = index, `v#` = volume (optional), `r` = remember volume (optional).

`r` will remember current volume and change back to it when cycling to a device without the `v` option.

#### `set-audio-device`
Same usage as `cycle-audio-devices` except `r` which is ignored.

#### `toggle-info`
Toggle playback info. Shows frame count, progress, fps and speed.

#### `step`
Frame step with step method, delay, rate and muting options.

#### `step-back`
Frame step backward.

#### `htp`
Hold to play with speed setting and muting options.

#### `htp-back`
Hold to play backward.
