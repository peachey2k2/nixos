--- @diagnostic disable-next-line
hl = hl

hl.debug({
  disable_logs = false,
})

hl.monitor({
  output = "",
  mode = "preferred",
  position = "auto",
  scale = 1,
})

local terminal = "wezterm"
local fileManager = "thunar"
local webBrowser = "helium"
local mainMod = "SUPER"

hl.on("hyprland.start", function()
  hl.exec_cmd("caelestia shell -d")
  hl.exec_cmd("copyq")
  hl.exec_cmd("swaybg -i ~/.config/hypr/bg.png")
  hl.exec_cmd("flameshot")
  hl.exec_cmd("alarm-clock-applet -h")
  hl.exec_cmd("nm-applet")
  hl.exec_cmd("emote")
  hl.exec_cmd("thunar --daemon")
  hl.exec_cmd("loopspinner -d")
  hl.exec_cmd("fcitx5 -d")
  hl.exec_cmd("systemctl --user start hyprpolkitagent")
  hl.exec_cmd("xhost +SI:localuser:root")
end)

hl.env("HYPRCURSOR_THEME", "rose-pine-hyprcursor")
hl.env("HYPRCURSOR_SIZE", "24")
hl.env("GTK_THEME", "Vimix-dark-doder:dark")
hl.env("XMODIFIERS", "@im=fcitx")
hl.env("DOTNET_SYSTEM_GLOBALIZATION_INVARIANT", "1")

hl.config({
  general = {
    gaps_in = 5,
    gaps_out = "5, 30",
    border_size = 2,
    col = {
      inactive_border = "rgba(3f3f3fff)",
      active_border = "rgba(c2c1ffff)",
    },
    resize_on_border = false,
    allow_tearing = false,
    layout = "scrolling",
  },

  decoration = {
    rounding = 5,
    active_opacity = 1.0,
    inactive_opacity = 1.0,
    shadow = {
      enabled = true,
      range = 4,
      render_power = 3,
      color = "rgba(1a1a1aee)",
    },
    blur = {
      enabled = false,
    },
  },

  animations = {
    enabled = true,
  },

  dwindle = {
    pseudotile = true,
    preserve_split = true,
  },

  scrolling = {
    column_width = 0.5,
    focus_fit_method = 1,
    explicit_column_widths = ",0.333,0.5,1.0",
  },

  misc = {
    force_default_wallpaper = 0,
    disable_hyprland_logo = true,
  },

  input = {
    kb_layout = "tr",
    kb_variant = "intl",
    kb_model = "",
    kb_options = "",
    kb_rules = "",
    follow_mouse = 2,
    sensitivity = 0.2,
    touchpad = {
      natural_scroll = false,
    },
  },

})

hl.device({
  name = "epic-mouse-v1",
  sensitivity = -0.5,
})

hl.animation({ leaf = "global", enabled = false })
hl.animation({ leaf = "border", enabled = false })
hl.animation({ leaf = "windows", enabled = true, speed = 2, bezier = "default", style = "slide" })
hl.animation({ leaf = "windowsIn", enabled = false })
hl.animation({ leaf = "windowsOut", enabled = false })
hl.animation({ leaf = "fadeIn", enabled = false })
hl.animation({ leaf = "fadeOut", enabled = false })
hl.animation({ leaf = "fade", enabled = false })
hl.animation({ leaf = "layers", enabled = false })
hl.animation({ leaf = "layersIn", enabled = false })
hl.animation({ leaf = "layersOut", enabled = false })
hl.animation({ leaf = "fadeLayersIn", enabled = false })
hl.animation({ leaf = "fadeLayersOut", enabled = false })
hl.animation({ leaf = "workspaces", enabled = false })
hl.animation({ leaf = "workspacesIn", enabled = true, speed = 2, bezier = "default", style = "slidevert" })
hl.animation({ leaf = "workspacesOut", enabled = true, speed = 2, bezier = "default", style = "slidevert" })

hl.bind(mainMod .. " + T", hl.dsp.exec_cmd(terminal))
hl.bind("ALT + F4", hl.dsp.window.close())
hl.bind("SUPER + SHIFT + M", hl.dsp.exit())
hl.bind("SUPER + SHIFT + DELETE", hl.dsp.exec_cmd("poweroff"))
hl.bind(mainMod .. " + E", hl.dsp.exec_cmd(fileManager))
hl.bind(mainMod .. " + SPACE", hl.dsp.window.float({ action = "toggle" }))
hl.bind(mainMod .. " + W", hl.dsp.exec_cmd(webBrowser))
hl.bind(mainMod .. " + S", hl.dsp.exec_cmd("flameshot gui"))
hl.bind(mainMod .. " + SHIFT + S", hl.dsp.exec_cmd("flameshot gui"))
hl.bind(mainMod .. " + G", hl.dsp.exec_cmd("emote"))
hl.bind(mainMod .. " + V", hl.dsp.exec_cmd("copyq menu"))
hl.bind(mainMod .. " + A", hl.dsp.exec_cmd("alarm-clock-applet"))
hl.bind(mainMod .. " + P", hl.dsp.window.pseudo())
hl.bind(mainMod .. " + J", hl.dsp.layout("togglesplit"))

hl.bind(mainMod .. " + left", hl.dsp.focus({ direction = "left" }))
hl.bind(mainMod .. " + right", hl.dsp.focus({ direction = "right" }))
hl.bind(mainMod .. " + up", hl.dsp.focus({ direction = "up" }))
hl.bind(mainMod .. " + down", hl.dsp.focus({ direction = "down" }))

hl.bind(mainMod .. " + SHIFT + left", hl.dsp.layout("swapcol l"))
hl.bind(mainMod .. " + SHIFT + right", hl.dsp.layout("swapcol r"))
hl.bind(mainMod .. " + D", hl.dsp.layout("colresize +conf"))

for i = 1, 10 do
  local key = i % 10
  hl.bind(mainMod .. " + " .. key, hl.dsp.focus({ workspace = i }))
  hl.bind(mainMod .. " + SHIFT + " .. key, hl.dsp.window.move({ workspace = i }))
end

hl.bind(mainMod .. " + mouse:272", hl.dsp.window.drag(), { mouse = true })
hl.bind(mainMod .. " + mouse:273", hl.dsp.window.resize(), { mouse = true })

hl.bind("XF86AudioRaiseVolume", hl.dsp.exec_cmd("wpctl set-volume @DEFAULT_AUDIO_SINK@ 5%+"), { locked = true, repeating = true })
hl.bind("XF86AudioLowerVolume", hl.dsp.exec_cmd("wpctl set-volume @DEFAULT_AUDIO_SINK@ 5%-"), { locked = true, repeating = true })
hl.bind("XF86AudioMute", hl.dsp.exec_cmd("wpctl set-mute @DEFAULT_AUDIO_SINK@ toggle"), { locked = true, repeating = true })
hl.bind("XF86AudioMicMute", hl.dsp.exec_cmd("wpctl set-mute @DEFAULT_AUDIO_SOURCE@ toggle"), { locked = true, repeating = true })

hl.bind("XF86AudioNext", hl.dsp.exec_cmd("playerctl next"), { locked = true })
hl.bind("XF86AudioPause", hl.dsp.exec_cmd("playerctl play-pause"), { locked = true })
hl.bind("XF86AudioPlay", hl.dsp.exec_cmd("playerctl play-pause"), { locked = true })
hl.bind("XF86AudioPrev", hl.dsp.exec_cmd("playerctl previous"), { locked = true })

hl.bind(mainMod .. " + mouse:276", hl.dsp.exec_cmd("hyprctl -q keyword cursor:zoom_factor $(hyprctl getoption cursor:zoom_factor -j | jq '.float * 1.5')"))
hl.bind(mainMod .. " + mouse:275", hl.dsp.exec_cmd("hyprctl -q keyword cursor:zoom_factor $(hyprctl getoption cursor:zoom_factor -j | jq '(.float * 0.66) | if . < 1 then 1 else . end')"))
hl.bind(mainMod .. " + SHIFT + mouse:276", hl.dsp.exec_cmd("hyprctl -q keyword cursor:zoom_factor 1"))
hl.bind(mainMod .. " + SHIFT + mouse:275", hl.dsp.exec_cmd("hyprctl -q keyword cursor:zoom_factor 1"))

hl.window_rule({
  name = "suppress-maximize-events",
  match = { class = ".*" },
  suppress_event = "maximize",
})

hl.window_rule({
  name = "fix-xwayland-drags",
  match = {
    class = "^$",
    title = "^$",
    xwayland = true,
    float = true,
    fullscreen = false,
    pin = false,
  },
  no_focus = true,
})

hl.window_rule({ name = "copyq-float", match = { class = "^(com.github.hluk.copyq)$" }, float = true })
hl.window_rule({ name = "alarm-float", match = { class = "^(alarm-clock-applet)$" }, float = true })
hl.window_rule({ name = "alarm-size", match = { class = "^(alarm-clock-applet)$" }, size = "400 400" })

hl.window_rule({ name = "quickshell-border", match = { class = "^(org.quickshell)$" }, border_size = 0 })
hl.window_rule({ name = "quickshell-shadow", match = { class = "^(org.quickshell)$" }, no_shadow = true })
hl.window_rule({ name = "quickshell-float", match = { class = "^(org.quickshell)$" }, float = true })
hl.window_rule({ name = "flameshot-float", match = { title = "^(flameshot).*$" }, float = true })

hl.window_rule({ name = "godot-tile", match = { class = "(Godot)", initial_title = "(Godot)" }, tile = true })
hl.window_rule({ name = "pds-float", match = { class = "^(pds.exe)$" }, float = true })
hl.window_rule({ name = "loopspinner-float", match = { title = "^(loopspinner)$" }, float = true })

-- Caelestia global actions via dispatcher command
hl.bind("SUPER + R", hl.dsp.exec_cmd("hyprctl dispatch global caelestia:launcher"))
for _, k in ipairs({ "mouse:272", "mouse:273", "mouse:274", "mouse:275", "mouse:276", "mouse:277", "mouse_up", "mouse_down" }) do
  hl.bind("SUPER + " .. k, hl.dsp.exec_cmd("hyprctl dispatch global caelestia:launcherInterrupt"))
end

hl.bind("$kbSession", hl.dsp.exec_cmd("hyprctl dispatch global caelestia:session"))
hl.bind("$kbClearNotifs", hl.dsp.exec_cmd("hyprctl dispatch global caelestia:clearNotifs"), { locked = true })
hl.bind("$kbShowPanels", hl.dsp.exec_cmd("hyprctl dispatch global caelestia:showall"))
hl.bind("$kbLock", hl.dsp.exec_cmd("hyprctl dispatch global caelestia:lock"))

hl.bind("$kbRestoreLock", hl.dsp.exec_cmd("caelestia shell -d"), { locked = true })
hl.bind("$kbRestoreLock", hl.dsp.exec_cmd("hyprctl dispatch global caelestia:lock"), { locked = true })

hl.bind("XF86MonBrightnessUp", hl.dsp.exec_cmd("hyprctl dispatch global caelestia:brightnessUp"), { locked = true })
hl.bind("XF86MonBrightnessDown", hl.dsp.exec_cmd("hyprctl dispatch global caelestia:brightnessDown"), { locked = true })

hl.bind("CTRL + SUPER + SPACE", hl.dsp.exec_cmd("hyprctl dispatch global caelestia:mediaToggle"), { locked = true })
hl.bind("XF86AudioPlay", hl.dsp.exec_cmd("hyprctl dispatch global caelestia:mediaToggle"), { locked = true })
hl.bind("XF86AudioPause", hl.dsp.exec_cmd("hyprctl dispatch global caelestia:mediaToggle"), { locked = true })
hl.bind("CTRL + SUPER + EQUAL", hl.dsp.exec_cmd("hyprctl dispatch global caelestia:mediaNext"), { locked = true })
hl.bind("XF86AudioNext", hl.dsp.exec_cmd("hyprctl dispatch global caelestia:mediaNext"), { locked = true })
hl.bind("CTRL + SUPER + MINUS", hl.dsp.exec_cmd("hyprctl dispatch global caelestia:mediaPrev"), { locked = true })
hl.bind("XF86AudioPrev", hl.dsp.exec_cmd("hyprctl dispatch global caelestia:mediaPrev"), { locked = true })
hl.bind("XF86AudioStop", hl.dsp.exec_cmd("hyprctl dispatch global caelestia:mediaStop"), { locked = true })

hl.bind("SUPER + SHIFT + P", hl.dsp.exec_cmd("caelestia wallpaper -r ~/.config/hypr/wallpapers/"))
