local wezterm = require('wezterm')
local config = wezterm.config_builder and wezterm.config_builder() or {}

config.term = 'wezterm'
config.hide_tab_bar_if_only_one_tab = true
config.window_padding = { left = 5, right = 5, top = 8, bottom = 8 }
config.adjust_window_size_when_changing_font_size = false
config.scrollback_lines = 10000
config.font = wezterm.font_with_fallback({
  { family = 'JetBrainsMono Nerd Font Mono', weight = 'Regular' },
  'SauceCodePro Nerd Font',
  'Hack Nerd Font Mono',
  'Apple SD Gothic Neo',
  'Apple Color Emoji',
})
config.font_rules = {
  {
    intensity = 'Bold',
    italic = false,
    font = wezterm.font_with_fallback({ { family = 'JetBrainsMono Nerd Font Mono', weight = 'Bold' } }),
  },
}
config.font_size = 17.0
config.cell_width = 0.9
config.line_height = 0.92
config.harfbuzz_features = { 'calt=0', 'clig=0', 'liga=0' }
config.use_ime = true
config.use_dead_keys = false

return config
