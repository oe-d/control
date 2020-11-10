-- Control 1.0.9
-- https://github.com/oe-d/control
-- See control.conf for settings and key binds

options = require 'mp.options'
u = require 'mp.utils'

o = {
    audio_devices = '\'auto\'',
    audio_device = 0,
    osc_paused = false,
    pause_minimized = 'no',
    play_restored = false,
    show_info = 'yes',
    info_duration = 1000,
    show_volume = true,
    step_method = 'seek',
    step_delay = -1,
    step_rate = 0,
    step_mute = 'auto',
    htp_speed = 2.5,
    htp_keep_dir = false,
    end_rewind = 'no',
    end_exit_fs = false,
    audio_symbol='🔊 ',
    audio_muted_symbol='🔈 ',
    image_symbol='🖼 ',
    music_symbol='🎵 ',
    video_symbol='🎞 '
}

function init()
    options.read_options(o, 'control')
    if o.audio_device > 0 then audio:set(o.audio_device) end
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
        elseif media.type == 'video' then
            return (not media.frames or media.playback.frame < 1) and o.video_symbol or
                o.video_symbol..media.playback.frame..' / '..media.frames..' ('..media.playback.progress..'%)\n'
                ..format(media.playback.time)..'\n'
                ..round(fps.fps, 3)..' fps ('..round(media.playback.speed, 2)..'x)'
        else
            return ''
        end
    end
    osd.msg_timer:kill()
    osd.osd_timer:kill()
    step.delay_timer:kill()
    step.delay_timer.timeout = o.step_delay / 1000
    step.hwdec_timer:kill()
    mp.register_event('file-loaded', function()
        media:on_load()
        if media.type == 'video' then fps:on_load() end
    end)
    mp.observe_property('window-minimized', 'bool', function(_, v) media.playback:on_minimize(v) end)
    mp.observe_property('pause', 'bool', function(_, v)
        osc:on_pause(v)
        step:on_pause(v)
    end)
    mp.observe_property('playback-time', 'number', function(_, v)
        media.playback:on_tick(v)
        if media.type == 'video' then fps:on_tick() end
        if osd.show then osd:set(nil, o.info_duration / 1000) end
    end)
    mp.observe_property('play-dir', 'string', function(_, v) step:on_dir(v) end)
    mp.observe_property('speed', 'number', function(_, v)
        media.playback.speed = v
        if o.show_info then osd:set(nil, o.info_duration / 1000) end
    end)
    mp.observe_property('eof-reached', 'bool', function(_, v)
        media.playback:on_eof(v)
        fullscreen.on_eof(v)
    end)
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
end

function split(string, pattern)
    local t = {}
    for i in string.gmatch(string, pattern) do
        table.insert(t, i)
    end
    return t
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
    return mp.get_property_native(property)
end

media = {
    frames = 0,
    duration = 0,
    type = nil,
    get_type = function(self)
        local tracks = get('track-list/count')
        for i = 0, tracks - 1 do
            if get('track-list/'..i..'/type') == 'video' then
                if get('track-list/'..i..'/albumart') then self.type = 'audio'
                elseif self.frames < 2 then self.type = 'image'
                else self.type = 'video' end
                return self.type
            end
        end
        if tracks > 0 then self.type = 'audio' end
        return self.type
    end,
    on_load = function(self)
        self.frames = get('estimated-frame-count')
        self.duration = get('duration')
        self:get_type()
    end,
    playback = {
        frame = 0,
        time = 0,
        progress = 0,
        speed = 0,
        eof = false,
        prev_pause = false,
        play = function(dir, speed)
            mp.command('no-osd set play-dir '..dir)
            mp.command('no-osd set speed '..speed)
            mp.commandv('seek', 0, 'relative+exact')
            mp.command('set pause no')
        end,
        pause = function(self)
            if self.eof then self.rewind()
            else mp.command('set pause '..(get('pause') and 'no' or 'yes')) end
        end,
        rewind = function(playlist_pos, pause)
            if playlist_pos then mp.set_property('playlist-pos-1', math.min(playlist_pos, get('playlist-count'))) end
            mp.add_timeout(0.01, function()
                mp.commandv('seek', 0, 'absolute')
                mp.command('set pause '..(pause and 'yes' or 'no'))
            end)
        end,
        on_tick = function(self, time)
            self.time = math.max(time or 0, 0)
            self.frame = math.min(round(media.frames * self.time / media.duration) + 1, media.frames)
            self.progress = math.floor(self.frame / media.frames * 100)
        end,
        on_minimize = function(self, minimized)
            if o.pause_minimized == 'yes' or o.pause_minimized == media:get_type() then
                if minimized then
                    self.prev_pause = get('pause')
                    mp.command('set pause yes')
                elseif o.play_restored then
                    if not self.prev_pause then mp.command('set pause no') end
                    self.prev_pause = false
                end
            end
        end,
        on_eof = function(self, eof)
            self.eof = eof
            if o.end_rewind ~= 'no' and eof and not step.played then self.rewind(tonumber(o.end_rewind), true) end
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
    get_list = function(self)
        local names = split(o.audio_devices, '\'([^\']+)\'')
        local user_list = {}
        local list = self:get()
        for i, v in ipairs(names) do
            table.insert(user_list, {name = v})
            for j, _ in ipairs(list) do
                if v == list[j].name then
                    user_list[i].description = list[j].description
                    break
                end
            end
        end
        return user_list
    end,
    get = function(self, index)
        local list = index and self:get_list() or get('audio-device-list')
        if (index and (index < 1 or index > table.getn(list) or not list[index].description)) then
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
    list = function(self, list, duration, do_print)
        local msg = ''
        for i, v in ipairs(list) do
            local symbol = ''
            local vol = ''
            if v.name == get('audio-device') then
                symbol = (get('mute') or get('volume') == 0) and o.audio_muted_symbol or o.audio_symbol
                if o.show_volume then vol = '('..get('volume')..') ' end
            end
            msg = msg..symbol..vol..v.description..'\n'
            if do_print then print('\''..v.name..'\''..' ('..v.description..')') end
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
        if self.valid and set_vol then
            mp.command('no-osd set mute no')
            mp.command('no-osd set volume '..vol)
        elseif self.valid and self.set_prev_vol then
            mp.command('no-osd set mute '..(self.prev_mute and 'yes' or 'no'))
            mp.command('no-osd set volume '..self.prev_vol)
            self.set_prev_vol = false
        end
        self:list(list, 2)
    end,
    msg_handler = function(self, cmd, ...)
        if cmd == 'list' then
            self.osd = true
            self:list(self:get(), 4, true)
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

osc = {
    overlay = mp.create_osd_overlay('ass-events'),
    on_pause = function(self, pause)
        if o.osc_paused then
            if pause then
                mp.command('script-message osc-visibility always no-osd')
                mp.add_timeout(0.05, function()
		            self.overlay:update()
		            self.overlay:remove()
	            end)
            else
                mp.command('script-message osc-visibility auto no-osd')
            end
        end
    end
}

fps = {
    interval = 0.5,
    prev_est_fps = 0,
    est_fps = 0,
    identical_count = 0,
    different_count = 0,
    fps = 0,
    prev_time = 0,
    prev_pos = 0,
    prev_drops = 0,
    prev_vop_dur = 0,
    vop_dur = 0,
    frames = 0,
    get_est_fps = function(self)
        self.est_fps = round(get('estimated-vf-fps') or 0, 3)
        if self.est_fps == self.prev_est_fps then
            self.identical_count = self.identical_count + 1
            self.different_count = 0
        else
            self.identical_count = 0
        end
        if self.identical_count == 0 then self.different_count = self.different_count + 1 end
        if self.different_count == 30 then self.identical_count = 1000 end
        self.prev_est_fps = self.est_fps
    end,
    get_fps = function(self)
        local time = mp.get_time()
        local vop = get('vo-passes') or {fresh = {}}
        for _, v in ipairs(vop.fresh) do
            self.vop_dur = self.vop_dur + v.last
        end
        if self.vop_dur ~= self.prev_vop_dur then self.frames = self.frames + 1 end
        self.prev_vop_dur = self.vop_dur
        self.vop_dur = 0
        local time_delta = time - self.prev_time
        if time_delta < self.interval then return end
        local spd = media.playback.speed
        local pos_delta = math.abs(media.playback.time - self.prev_pos)
        local drops = get('frame-drop-count') or 0
        local drop_delta = drops - self.prev_drops
        local mult = self.interval / time_delta
        local function hot_mess(speed)
            if drop_delta > 0 and self.frames * mult < self.est_fps * speed / math.max(self.est_fps / 30, 1) * self.interval * 0.95 then
                self.fps = round(self.frames * mult, 2)
            else
                self.fps = self.est_fps * spd
            end
        end
        if spd > 1 then
            if drop_delta > 0 and (pos_delta * mult > 2 or pos_delta * mult / self.interval > spd * 0.95 and self.frames * mult > 18 * self.interval) then
                self.fps = round(self.est_fps * pos_delta * mult / self.interval, 2)
            else
                hot_mess(1)
            end
        else
            hot_mess(spd)
        end
        self.prev_time = time
        self.prev_pos = media.playback.time
        self.prev_drops = drops
        self.frames = 0
    end,
    on_load = function(self)
        self.prev_est_fps = 0
        self.identical_count = 0
        self.different_count = 0
    end,
    on_tick = function(self)
        if self.identical_count < 60 then self:get_est_fps() end
        if osd.show then self:get_fps() end
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
    time_window = 0.5,
    prev_time = 0,
    clicks = 0,
    x = 0,
    cycle = function(self, e)
        if self.clicks == 2 and mp.get_time() - self.prev_time < self.time_window then
            if (e == 'down' and get('fs')) or (e == 'up' and not get('fs')) then
                mp.command('cycle fullscreen')
                self.clicks = 0
            end
        end
    end,
    on_click = function(self)
        if mp.get_time() - self.prev_time > self.time_window then self.clicks = 0 end
        if self.clicks == 1 and mp.get_time() - self.prev_time < self.time_window and math.abs(mp.get_mouse_pos() - self.x) < 5 then
            self.clicks = 2
        else
            self.x = mp.get_mouse_pos()
            self.clicks = 1
        end
        self.prev_time = mp.get_time()
    end,
    on_eof = function(eof)
        if o.end_exit_fs and eof and not step.played then mp.command('set fullscreen no') end
    end,
    key_handler = function(self, e)
        if e.key_name == 'MBTN_LEFT_DBL' then
            osd:set('Bind to MBTN_LEFT. Not MBTN_LEFT_DBL.', 4)
        elseif e.event == 'press' then
            osd:set('Received a key press event.\n'
                ..'Key down/up events are required.\n'
                ..'Make sure nothing else is bound to the key.', 4)
        elseif e.event == 'down' then
            self:on_click()
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
        if get('play-dir') == 'forward' and not get('pause') and get('estimated-frame-number') ~= step.dir_frame then
            mp.command('no-osd set hwdec '..step.prev_hwdec)
            step.hwdec_timer:kill()
            step.prev_hwdec = nil
        end
    end),
    on_dir = function(self, dir)
        if dir == 'forward' and self.prev_hwdec then
            self.dir_frame = get('estimated-frame-number')
            self.hwdec_timer:resume()
        end
    end,
    on_pause = function(self, pause)
        if not pause and self.stepped then
            if (o.step_mute == 'auto' and not self.muted) or (o.step_mute == 'hold' and not self.muted and not self.played) then mp.command('no-osd set mute no') end
            mp.commandv('seek', 0, 'relative+exact')
            self.stepped = false
        end
    end,
    play = function(self)
        self.played = true
        if o.step_mute == 'auto' and not self.muted then mp.command('no-osd set mute no')
        elseif o.step_mute == 'hold' then mp.command('no-osd set mute yes') end
        if self.direction == 'backward' then mp.command('no-osd set hwdec no') end
        media.playback.play(self.direction, self.play_speed)
    end,
    start = function(self, dir, htp)
        self.direction = dir
        self.prev_hwdec = self.prev_hwdec or get('hwdec')
        self.paused = get('pause')
        if not self.stepped then self.muted = get('mute') end
        self.prev_speed = media.playback.speed
        self.prev_pos = media.playback.time
        if o.show_info == 'yes' then osd.show = true end
        if htp then
            self.play_speed = o.htp_speed
            self:play()
        else
            self.play_speed = o.step_rate == 0 and 1 or o.step_rate / get('container-fps')
            self.delay_timer:resume()
            if not self.paused then mp.command('set pause yes') end
            if dir == 'forward' and o.step_method == 'step' then
                if o.step_mute ~= 'no' then mp.command('no-osd set mute yes') end
                mp.command('frame-step')
                self.stepped = true
            elseif dir == 'backward' or get('time-pos') < get('duration') then
                mp.commandv('seek', (dir == 'forward' and 1 or -1) / get('container-fps'), 'relative+exact')
            end
        end
    end,
    stop = function(self, dir, htp)
        self.delay_timer:kill()
        if dir == 'backward' and get('estimated-frame-number') > 0 and not self.played and media.playback.time == self.prev_pos then
            mp.command('frame-back-step')
            print('Backward seek failed. Reverted to backstep.')
        end
        if not htp or not o.htp_keep_dir then mp.command('no-osd set play-dir forward') end
        mp.command('no-osd set speed '..self.prev_speed)
        if o.step_mute ~= 'no' and (not self.muted and not (o.step_mute ~= 'no' and self.stepped)) then mp.command('no-osd set mute no') end
        if (htp and self.paused) or (not htp and ((o.step_method == 'step' and not self.played) or self.played)) then mp.command('set pause yes') end
        if self.played then mp.commandv('seek', 0, 'relative+exact') end
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
