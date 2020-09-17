# Control

Features:
- Improved cycle fullscreen when using mouse.
- Cycle pause and replay video at the end of playback.
- List and set/cycle audio devices with volume options.
- Display playback info.
- Customizable frame step.
- Hold to play with speed setting.

See [`control.conf`](https://github.com/oe-d/control/blob/master/control.conf) for settings and example key binds.

# Key binds

#### `cycle-fullscreen`
Cycle fullscreen and prevent draggable fullscreen window.

#### `cycle-pause`
Cycle pause and replay video at the end of playback.

#### `list-audio-devices`
Shows an indexed list of audio devices.

#### `cycle-audio-devices`
Cycle a list of audio devices separated by space.

Usage: `no-osd` (optional) `iv#r` where `i` = index, `v#` = volume (optional), `r` = remember volume (optional).

`r` will remember current volume and change back to it when cycling to a device without the `v` option.

Example: `Tab script-message-to control cycle-audio-devices no-osd 1v50 3r 2v100`

#### `set-audio-device`
Same usage as `cycle-audio-devices`

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
