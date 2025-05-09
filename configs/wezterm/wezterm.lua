local wezterm = require 'wezterm'
local c = wezterm.config_builder()

local a = wezterm.action
c.keys = {}
local function addKey(mods, key, action)
  table.insert(c.keys, {
    key = key, mods = mods, action = action
  })
end

c.enable_wayland = true

c.color_scheme = "catppuccin-mocha"
c.font = wezterm.font("Miracode")
c.font_size = 11

-- heard this helps with startup seed but it might be just placebo
c.font_dirs = { "@miracode@/share/fonts/truetype" }
c.font_locator="ConfigDirsOnly"

c.window_background_opacity = 0.8
c.window_content_alignment = {
  horizontal = 'Center',
  vertical = 'Center',
}
c.window_decorations = "NONE"

local padding = 8
c.window_padding = {
  left = padding, right = padding, top = padding, bottom = padding,
}

c.use_fancy_tab_bar = false
c.hide_tab_bar_if_only_one_tab = true
c.colors = {
  tab_bar = {
    background = "#071f3f",
    active_tab = {
      bg_color = "#174f8f",
      fg_color = "#c0c0c0",
    },
    inactive_tab = {
      bg_color = "#0b2f57",
      fg_color = "#c0c0c0",
    },
    inactive_tab_hover = {
      bg_color = "#0b2f57",
      fg_color = "#c0c0c0",
    },
    new_tab = {
      bg_color = "#071f3f",
      fg_color = "#071f3f",
    },
    new_tab_hover = {
      bg_color = "#071f3f",
      fg_color = "#071f3f",
    },
  }
}

c.skip_close_confirmation_for_processes_named = {
  "elvish", "bash", "sh", "tmux"
}

addKey("CTRL", "t", a.SpawnTab "CurrentPaneDomain")
addKey("CTRL", "w", a.CloseCurrentTab{confirm=true})
for i = 1, 9, 1 do
  addKey("CTRL" ,tostring(i), a.ActivateTab(i-1))
end
addKey("CTRL", "Tab", a.ActivateTabRelative(1))
addKey("CTRL|SHIFT", "Tab", a.ActivateTabRelative(-1))
addKey("CTRL", "PageUp", a.ActivateTabRelative(1))
addKey("CTRL", "PageDown", a.ActivateTabRelative(-1))

return c
