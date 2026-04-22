use jj.nu
use systemd-timers.nu

def all-cheatsheets [] {
  [
    (jj cheatsheet)
    (systemd-timers cheatsheet)
  ]
}

def "nu-complete-help-topics" [] {
  all-cheatsheets | each {|sheet| $sheet.aliases } | flatten | uniq | sort
}

def print-available-cheatsheets [sheets] {
  print "Available cheatsheets:"
  for sheet in $sheets {
    print $"  ($sheet.command) - ($sheet.title)"
  }
  print "Use `!help <cmd>` to view one."
}

def render-cheatsheet [sheet] {
  print $"(ansi cyan_bold)($sheet.title)(ansi reset)"
  print $sheet.description
  print ""

  $sheet.rows
}

export def "!help" [cmd?: string@nu-complete-help-topics] {
  let sheets = (all-cheatsheets)
  let topic = (($cmd | default "") | str downcase | str trim)

  if $topic == "" {
    print-available-cheatsheets $sheets
    return
  }

  let matches = ($sheets | where {|sheet| $topic in $sheet.aliases})
  if ($matches | is-empty) {
    print $"No cheatsheet found for '($topic)'."
    print ""
    print-available-cheatsheets $sheets
    return
  }

  render-cheatsheet ($matches | first)
}
