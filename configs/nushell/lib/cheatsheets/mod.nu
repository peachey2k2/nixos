use jj.nu [jj-cheatsheet]

def all-cheatsheets [] {
  [
    (jj-cheatsheet)
  ]
}

def print-available-cheatsheets [sheets] {
  print "Available cheatsheets:"
  for sheet in $sheets {
    print $"  ($sheet.command) - ($sheet.title)"
  }
  print "Use `%help <cmd>` to view one."
}

def render-cheatsheet [sheet] {
  print $"(ansi cyan_bold)($sheet.title)(ansi reset)"
  print $sheet.description
  print ""

  $sheet.rows
}

export def "%help" [cmd?: string] {
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
