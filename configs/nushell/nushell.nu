$env.NIX_SHELL_DEPTH = $env.NIX_SHELL_DEPTH? | default 0
$env.SHELL_DEPTH = $env.SHELL_DEPTH? | default 0
$env.config.show_banner = false

$env.EDITOR = "@editor@"
$env.VISUAL = "@editor@"
$env.SHELL = (^which nu)

# default `rm` to send to trash instead of deleting. `-p` bypasses.
$env.config.rm.always_trash = true

# basic vim bindings for commands
$env.config.edit_mode = "vi"

# make the cursor look sane
$env.config.cursor_shape.vi_insert = "line"
$env.config.cursor_shape.vi_normal = "block"

# completion thingy
$env.CARAPACE_BRIDGES = "inshellisense,carapace,zsh,fish,bash"

$env.config.use_kitty_protocol = true
$env.config.display_errors.exit_code = true
$env.config.display_errors.termination_signal = true

# give the tables a lil bit of that swag
$env.config.table.mode = "light"
$env.config.table.index_mode = "auto"
$env.config.table.padding = {left:0, right:1} # 1 space is too little and 3 is too much
$env.config.table.trim.methodology = "truncating"
$env.config.table.trim.truncating_suffix = "…" # save space for +2 characters
$env.config.table.missing_value_symbol = $"(ansi red)(ansi reset)"

$env.config.datetime_format.table = null
$env.config.datetime_format.normal = $"(ansi blue_bold)%d(ansi reset)(ansi yellow)/(ansi blue_bold)%m(ansi reset)(ansi yellow)/(ansi blue_bold)%Y(ansi reset) (ansi magenta_bold)%H(ansi reset)(ansi yellow):(ansi magenta_bold)%M(ansi reset)(ansi yellow):(ansi magenta_bold)%S(ansi reset)"


mkdir ($nu.data-dir | path join "vendor/autoload")
starship init nu | save -f ($nu.data-dir | path join "vendor/autoload/starship.nu")
