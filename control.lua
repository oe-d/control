-- Control 1.0.5
-- https://github.com/oe-d/control
-- See control.conf for settings and key binds

options = require 'mp.options'
u = require 'mp.utils'

o = {
    audio_device = 0,
    pause_minimized = 'no',
    play_restored = 'no',
    show_info = 'yes',
    info_duration = 1000,
    show_volume = 'yes',
    step_method = 'seek',
    step_delay = -1,
    step_rate = 0,
    step_mute = 'auto',
    htp_speed = 2.5,
    htp_keep_dir = 'no',
    end_rewind = 'no',
    end_exit_fs = 'no',
    audio_symbol='🔊 ',
    audio_muted_symbol='🔈 ',
    image_symbol='🖼 ',
    music_symbol='🎵 ',
    video_symbol='🎞 '
}

function init()
    options.read_options(o, 'control')
    if o.step_delay == -1 then o.step_delay = get('input-ar-delay') end
    if o.step_rate == -1 then o.step_rate = get('input-ar-rate') end
    if o.end_rewind == 'file' then mp.set_property('keep-open', 'always') end
    if o.show_info == 'start' then
        o.show_info = 'yes'
        osd:toggle()
    end
    osd.default_msg = function()
        if media.type == 'image' then
            return o.image_symbol
        elseif media.type == 'audio' then
            return o.music_symbol
        else
            local frame = get('frame')
            local frames = get('frames')
            if not frame or not frames then return o.video_symbol
            else frame = frame + 1 end
            local progress = math.floor(frame / frames * 100)
            return o.video_symbol..math.min(frame, frames)..' / '..frames..' ('..progress..'%)\n'
                ..format(math.max(get('pos') or 0, 0))..'\n'
                ..round(fps.fps, 3)..' fps ('..round(get('speed'), 2)..'x)'
        end
    end
    osd.msg_timer:kill()
    osd.osd_timer:kill()
    step.delay_timer:kill()
    step.delay_timer.timeout = o.step_delay / 1000
    step.hwdec_timer:kill()
    if o.audio_device > 0 then audio:set(o.audio_device) end
    mp.register_event('file-loaded', function() media:get_type() end)
    mp.observe_property('window-minimized', 'bool', function(_, v)
        if o.pause_minimized == 'yes' or o.pause_minimized == media:get_type() then
            if v then media.playback:on_minimize()
            elseif o.play_restored == 'yes' then media.playback:on_restore() end
        end
    end)
    mp.observe_property('playback-time', 'number', function(_, _)
        if osd.show then
            fps:tick()
            osd:set(nil, o.info_duration / 1000)
        end
    end)
    mp.observe_property('play-dir', 'string', function(_, v)
        if v == 'forward' and step.prev_hwdec then
            step.dir_frame = get('frame')
            step.hwdec_timer:resume()
        end
    end)
    mp.observe_property('eof-reached', 'bool', function(_, v)
        media.playback.eof = v
        if v and not step.played then
            if o.end_rewind ~= 'no' then
                local pos = tonumber(o.end_rewind)
                if pos then mp.set_property('playlist-pos-1', math.min(pos, get('playlist-count'))) end
                mp.add_timeout(0.01, function() media.playback.rewind(true) end)
            end
            if o.end_exit_fs == 'yes' then mp.command('set fullscreen no') end
        end
    end)
end

function split(string, pattern)
    local str = {}
    for i in string.gmatch(string, pattern) do
        table.insert(str, i)
    end
    return str
end

function round(number, decimals)
    decimals = decimals or 0
    return math.floor(number * 10 ^ decimals + 0.5) / 10 ^ decimals
end

function format(time)
    time = time or 0
    local h = math.floor(time / 3600)
    local m = math.floor(time % 3600 / 60)
    local s = time % 60
    return string.format('%02d:%02d:%06.03f', h, m, s)
end

function get(property)
    local props = {
        drops = 'frame-drop-count',
        e_fps = 'estimated-vf-fps',
        fps = 'container-fps',
        frame = 'estimated-frame-number',
        frames = 'estimated-frame-count',
        pos = 'playback-time'
    }
    for k, v in pairs(props) do
        if k == property then property = v end
    end
    return mp.get_property_native(property)
end

media = {
    type = nil,
    get_type = function(self)
        if get('track-list/0/type') == 'video' and get('frames') == 0 then
            self.type = 'image'
        elseif get('track-list/0/type') == 'audio' or get('track-list/0/albumart') == 'yes' then
            self.type = 'audio'
        else
            self.type = 'video'
        end
        return self.type
    end,
    playback = {
        eof = false,
        prev_pause = false,
        pause = function(self)
            if self.eof then
                self.rewind()
            else
                if get('pause') and step.stepped then
                    mp.commandv('seek', 0, 'relative+exact')
                    step.stepped = false
                end
                mp.command('set pause '..(get('pause') and 'no' or 'yes'))
            end
        end,
        rewind = function(pause)
            mp.commandv('seek', 0, 'absolute')
            mp.command('set pause '..(pause and 'yes' or 'no'))
        end,
        on_minimize = function(self)
            self.prev_pause = get('pause')
            mp.command('set pause yes')
        end,
        on_restore = function(self)
            if not self.prev_pause then mp.command('set pause no') end
            self.prev_pause = false
        end
    }
}

audio = {
    osd = true,
    prev_list = '',
    i = 0,
    set_prev_vol = false,
    prev_mute = false,
    prev_vol = 0,
    valid = true,
    get = function(self, index)
        local list = get('audio-device-list')
        if index and (index < 1 or index > table.getn(list)) then
            self.valid = false
            list[1].name = 'Invalid device index ('..index..')'
            list[1].description = list[1].name
            index = 1
        end
        return index and list[index] or list
    end,
    set = function(self, index)
        local name = self:get(index).name
        if self.valid then mp.command('no-osd set audio-device '..name) end
    end,
    list = function(self, list, show_index, duration)
        local msg = ''
        for i, v in ipairs(list) do
            local symbol = ''
            local vol = ''
            if v.name == get('audio-device') then
                symbol = (get('mute') or get('volume') == 0) and o.audio_muted_symbol or o.audio_symbol
                if o.show_volume == 'yes' then vol = '('..get('volume')..') ' end
            end
            i = show_index and i..': ' or ''
            msg = msg..i..symbol..vol..string.gsub(v.description, 'Autoselect', 'Default')..'\n'
        end
        if self.osd then osd:set(msg, duration) end
    end,
    cycle = function(self, list)
        if u.to_string(list) ~= self.prev_list then self.i = 0 end
        self.prev_list = u.to_string(list)
        self.i = self.i == table.getn(list) and 1 or self.i + 1
        local remember_vol = false
        local index = 0
        local set_vol = false
        local vol = 0
        for i, v in ipairs(list) do
            local iv = split(v, '%d+')
            if i == (self.i > 1 and self.i - 1 or table.getn(list)) and string.find(v, 'r') then
                self.set_prev_vol = true
                remember_vol = true
            end
            if i == self.i then
                index = tonumber(iv[1])
                if iv[2] then
                    set_vol = true
                    vol = iv[2]
                end
            end
            list[i] = self:get(tonumber(iv[1]))
        end
        if remember_vol then
            self.prev_mute = get('mute')
            self.prev_vol = get('volume')
        end
        self.valid = true
        self:set(index)
        if set_vol then
            mp.command('no-osd set mute no')
            mp.command('no-osd set volume '..vol)
        elseif self.set_prev_vol then
            mp.command('no-osd set mute '..(self.prev_mute and 'yes' or 'no'))
            mp.command('no-osd set volume '..self.prev_vol)
            self.set_prev_vol = false
        end
        self:list(list, false, 2)
    end,
    msg_handler = function(self, cmd, ...)
        if cmd == 'list' then
            self.osd = true
            self:list(self:get(), true, 4)
        elseif cmd == 'cycle' then
            local args = {...}
            if args[1] == 'no-osd' then
                table.remove(args, 1)
                self.osd = false
            else
                self.osd = true
            end
            self:cycle(args)
        end
    end
}

fps = {
    interval = 0.5,
    fps = 0,
    prev_time = 0,
    prev_pos = 0,
    prev_drops = 0,
    prev_vop_dur = 0,
    vop_dur = 0,
    frames = 0,
    tick = function(self)
        local vop = get('vo-passes') or {fresh = {}}
        for _, v in ipairs(vop.fresh) do
            self.vop_dur = self.vop_dur + v.last
        end
        if self.vop_dur ~= self.prev_vop_dur then self.frames = self.frames + 1 end
        self.prev_vop_dur = self.vop_dur
        self.vop_dur = 0
        local fps = get('e_fps')
        local t_delta = mp.get_time() - self.prev_time
        if not fps or t_delta < self.interval then return end
        local spd = get('speed')
        local pos_delta = math.abs((get('pos') or 0) - (self.prev_pos or 0))
        local drops = (get('drops') or 0) - (self.prev_drops or 0)
        local mult = self.interval / t_delta
        local function hot_mess(speed)
            if drops > 0 and self.frames * mult < fps * speed / math.max(fps / 30, 1) * self.interval * 0.95 then
                self.fps = round(self.frames * mult, 2)
            else
                self.fps = fps * spd
            end
        end
        if spd > 1 then
            if drops > 0 and (pos_delta * mult > 2 or pos_delta * mult / self.interval > spd * 0.95 and self.frames * mult > 18 * self.interval) then
                self.fps = round(fps * pos_delta * mult / self.interval, 2)
            else
                hot_mess(1)
            end
        else
            hot_mess(spd)
        end
        self.prev_time = mp.get_time()
        self.prev_pos = get('pos')
        self.prev_drops = get('drops')
        self.frames = 0
    end
}

osd = {
    default_msg = nil,
    msg = '',
    show = false,
    toggled = false,
    osd_timer = mp.add_timeout(1e8, function() mp.set_property('osd-msg1', '') end),
    msg_timer = mp.add_timeout(1e8, function() osd.msg = osd.default_msg() end),
    set = function(self, msg, duration)
        if msg or not self.toggled or (self.toggled and self.osd_timer.timeout ~= 1e8) then
            self.osd_timer:kill()
            self.osd_timer.timeout = self.toggled and 1e8 or duration
            self.osd_timer:resume()
            mp.set_property('osd-level', 1)
        end
        if msg then
            self.msg = msg
            self.msg_timer:kill()
            self.msg_timer.timeout = duration
            self.msg_timer:resume()
            mp.add_timeout(0.1, function() mp.set_property('osd-msg1', self.msg) end)
        elseif not self.msg_timer:is_enabled() then
            self.msg = self.default_msg()
            mp.set_property('osd-msg1', self.msg)
        else
            mp.set_property('osd-msg1', self.msg)
        end
    end,
    toggle = function(self)
        self.toggled = not self.toggled
        self.show = self.toggled
        self:set(nil, 0)
    end
}

fullscreen = {
    prev_time = 0,
    clicks = 0,
    x = 0,
    click = function(self)
        if mp.get_time() - self.prev_time > 0.3 then self.clicks = 0 end
        if self.clicks == 1 and mp.get_time() - self.prev_time < 0.3 and math.abs(mp.get_mouse_pos() - self.x) < 5 then
            self.clicks = 2
        else
            self.x = mp.get_mouse_pos()
            self.clicks = 1
        end
        self.prev_time = mp.get_time()
    end,
    cycle = function(self, e)
        if self.clicks == 2 and mp.get_time() - self.prev_time < 0.3 then
            if (e == 'down' and get('fs')) or (e == 'up' and not get('fs')) then
                mp.command('cycle fullscreen')
                self.clicks = 0
            end
        end
    end,
    key_handler = function(self, e)
        if e.key_name == 'MBTN_LEFT_DBL' then
            osd:set('Bind to MBTN_LEFT. Not MBTN_LEFT_DBL.', 4)
        elseif e.event == 'press' then
            osd:set('Received a key press event.\n'
                ..'Key down/up events are required.\n'
                ..'Make sure nothing else is bound to the key.', 4)
        elseif e.event == 'down' then
            self:click()
            self:cycle(e.event)
        elseif e.event == 'up' then
            self:cycle(e.event)
        end
    end
}

step = {
    e_msg = false,
    direction = nil,
    prev_hwdec = nil,
    dir_frame = 0,
    paused = false,
    muted = false,
    prev_speed = 1,
    prev_pos = 0,
    play_speed = 1,
    stepped = false,
    played = false,
    delay_timer = mp.add_timeout(1e8, function() step:play() end),
    hwdec_timer = mp.add_periodic_timer(1 / 60, function()
        if get('play-dir') == 'forward' and not get('pause') and get('frame') ~= step.dir_frame then
            mp.command('no-osd set hwdec '..step.prev_hwdec)
            step.hwdec_timer:kill()
            step.prev_hwdec = nil
        end
    end),
    play = function(self)
        self.played = true
        if self.direction == 'backward' then mp.command('no-osd set hwdec no') end
        mp.command('no-osd set play-dir '..self.direction)
        mp.command('no-osd set speed '..self.play_speed)
        if o.step_mute == 'auto' and not self.muted then mp.command('no-osd set mute no')
        elseif o.step_mute == 'hold' then mp.command('no-osd set mute yes') end
        mp.commandv('seek', 0, 'relative+exact')
        mp.command('set pause no')
    end,
    start = function(self, dir, htp)
        self.direction = dir
        self.prev_hwdec = self.prev_hwdec or get('hwdec')
        self.paused = get('pause')
        self.muted = get('mute')
        self.prev_speed = get('speed')
        self.prev_pos = get('pos')
        if o.show_info == 'yes' then osd.show = true end
        if htp then
            self.play_speed = o.htp_speed
            self:play()
        else
            self.play_speed = o.step_rate == 0 and 1 or o.step_rate / get('fps')
            self.delay_timer:resume()
            mp.command('set pause yes')
            if dir == 'forward' and o.step_method == 'step' then
                if o.step_mute ~= 'no' then mp.command('no-osd set mute yes') end
                mp.command('frame-step')
                self.stepped = true
            elseif dir == 'backward' or get('time-pos') < get('duration') then
                mp.commandv('seek', (dir == 'forward' and 1 or -1) / get('fps'), 'relative+exact')
            end
        end
    end,
    stop = function(self, dir, htp)
        self.delay_timer:kill()
        if dir == 'backward' and get('frame') > 0 and not self.played and get('pos') == self.prev_pos then
            mp.command('frame-back-step')
            print('Backward seek failed. Reverted to backstep.')
        end
        if not htp or o.htp_keep_dir == 'no' then mp.command('no-osd set play-dir forward') end
        mp.command('no-osd set speed '..self.prev_speed)
        if not self.muted then mp.command('no-osd set mute no') end
        mp.command('set pause yes')
        if self.played then mp.commandv('seek', 0, 'relative+exact') end
        if htp and not self.paused and not (media.playback.eof and get('keep-open-pause')) then mp.command('set pause no') end
        self.played = false
        if not osd.toggled then osd.show = false end
    end,
    on_press = function(self, dir, htp)
        local msg = 'Received a key press event.\n'
            ..(htp and 'Key down/up events are required.\n'
            or 'Only single frame steps will work.\n')
            ..'Make sure nothing else is bound to the key.'
        if htp then
            osd:set(msg, 4)
            return
        else
            if not self.e_msg then
                print(msg)
                self.e_msg = true
            end
            self:start(dir, false)
            mp.add_timeout(0.1, function() self:stop(dir, false) end)
        end
    end,
    key_handler = function(self, e, dir, htp)
        if media.type ~= 'video' then return
        elseif e.event == 'press' then self:on_press(dir, htp)
        elseif e.event == 'down' then self:start(dir, htp)
        elseif e.event == 'up' then self:stop(dir, htp) end
    end
}

init()

mp.register_script_message('list-audio-devices', function() audio:msg_handler('list') end)
mp.register_script_message('set-audio-device', function(...) audio:msg_handler('cycle', ...) end)
mp.register_script_message('cycle-audio-devices', function(...) audio:msg_handler('cycle', ...) end)
mp.add_key_binding(nil, 'toggle-info', function() osd:toggle() end)
mp.add_key_binding(nil, 'cycle-pause', function() media.playback:pause() end)
mp.add_key_binding(nil, 'cycle-fullscreen', function(e) fullscreen:key_handler(e) end, {complex = true})
mp.add_key_binding(nil, 'step', function(e) step:key_handler(e, 'forward') end, {complex = true})
mp.add_key_binding(nil, 'step-back', function(e) step:key_handler(e, 'backward') end, {complex = true})
mp.add_key_binding(nil, 'htp', function(e) step:key_handler(e, 'forward', true) end, {complex = true})
mp.add_key_binding(nil, 'htp-back', function(e) step:key_handler(e, 'backward', true) end, {complex = true})
