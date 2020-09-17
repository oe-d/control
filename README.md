# Control
mpv script with various features mainly for controlling playback.

`control.conf` contains info on settings and example key binds.

# Key binds

#### `cycle-fullscreen`
Cycle fullscreen and prevent draggable fullscreen window.

#### `cycle-pause`
Cycle pause and replay video at the end of playback.

#### `list-audio-devices`
Shows an indexed list of audio devices.

#### `cycle-audio-devices`
Cycle a list of audio devices separated by space.

Usage: no-osd (optional) iv# where i = index, v# = volume (optional).

Example: `Tab script-message-to control cycle-audio-devices no-osd 1v50 3 2v100`

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
