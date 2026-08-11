local wezterm = require 'wezterm'
local c = wezterm.config_builder()
local a = wezterm.action

c.enable_wayland = true

-- -- OpenGL triggers repeated i915 GPU hangs on this system. Vulkan via WebGPU
-- -- avoids the reset loop (and the resulting WirePlumber device churn).
-- c.front_end = "WebGpu"

c.color_scheme =
  -- "catppuccin-mocha"
  -- "Decaf (base16)"
  -- "Dehydration (Gogh)"
  -- "Dimmed Monokai (Gogh)"
  -- "Doom Peacock"
  "duskfox"
;;

c.font = wezterm.font_with_fallback({
  "Monaspace Krypton",
  "Symbols Nerd Font Mono",
  "Noto Sans Mono CJK JP",
})
c.font_size = 11

c.font_rules = {
  -- Regular italic → Monaspace Radon
  {
    italic = true,
    intensity = 'Normal',
    font = wezterm.font {
      family = 'Monaspace Radon',
      style = 'Italic',
    },
  },
  -- Dim italic → Monaspace Radon
  {
    italic = true,
    intensity = 'Half',
    font = wezterm.font {
      family = 'Monaspace Radon',
      style = 'Italic',
    },
  },
  -- Bold (not italic) → Monaspace Argon
  {
    intensity = 'Bold',
    italic = false,
    font = wezterm.font {
      family = 'Monaspace Argon',
      weight = 'Bold',
    },
  },
  -- Bold+Italic → Monaspace Argon
  {
    intensity = 'Bold',
    italic = true,
    font = wezterm.font {
      family = 'Monaspace Argon',
      weight = 'Bold',
      style = 'Italic',
    },
  },
}

-- don't ask the compositor to resize the terminal when zooming font size.
-- in niri this keeps the column stable instead of snapping to a new cell grid.
c.adjust_window_size_when_changing_font_size = false

-- heard this helps with startup speed but it might be just placebo
c.font_locator="ConfigDirsOnly"
c.font_dirs = {
  "@monaspace@/share/fonts/opentype",
  "@nf_symbols@/share/fonts/truetype",
  "@noto_cjk@/share/fonts/opentype",
}

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

-- what the fuck????????????????
c.enable_kitty_keyboard = true

-- disable ligatures
-- c.harfbuzz_features = { 'calt = 0', 'clig = 0', 'liga = 0' }

c.use_fancy_tab_bar = false
c.tab_max_width = 32

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

-- disable copy on select
c.mouse_bindings = {
  {
    event = { Up = { streak = 1, button = 'Left' } },
    mods = 'NONE',
    action = wezterm.action.Nop,
  },
  {
    event = { Up = { streak = 2, button = 'Left' } },
    mods = 'NONE',
    action = wezterm.action.Nop,
  },
  {
    event = { Up = { streak = 3, button = 'Left' } },
    mods = 'NONE',
    action = wezterm.action.Nop,
  }
}

c.skip_close_confirmation_for_processes_named = {
  "elvish", "bash", "sh", "tmux", "nu"
}

-- binds
c.keys = {}
local function addKey(mods, key, action)
  table.insert(c.keys, {
    key = key, mods = mods, action = action
  })
end

for i = 1, 9, 1 do
  addKey("CTRL",     tostring(i),   a.ActivateTab(i-1))
end
addKey("CTRL",       "t",           a.SpawnTab "CurrentPaneDomain")
addKey("CTRL",       "w",           a.CloseCurrentTab{confirm=true})
addKey("CTRL",       "Tab",         a.ActivateTabRelative(1))
addKey("CTRL|SHIFT", "Tab",         a.ActivateTabRelative(-1))
addKey("CTRL",       "PageUp",      a.ActivateTabRelative(1))
addKey("CTRL",       "PageDown",    a.ActivateTabRelative(-1))


-- ctrl+shift+u collides with fcitx5
addKey("CTRL|SHIFT", "y",           a.CharSelect{})

c.warn_about_missing_glyphs = false

return c
