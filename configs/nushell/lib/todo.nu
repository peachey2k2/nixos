def todo-file [] {
  $env.HOME | path join "todo.md"
}

def todo-undone-items [] {
  if not ((todo-file) | path exists) {
    return []
  }

  open --raw (todo-file)
  | lines
  | enumerate
  | where {|row| $row.item | str starts-with "- [ ] "}
  | each {|row|
    {
      line: ($row.index + 1)
      text: ($row.item | str replace -r '^- \[ \] ' '')
    }
  }
}

def todo-mark-done [line: int] {
  let file_lines = open --raw (todo-file) | lines
  let updated = $file_lines
    | update ($line - 1) ($file_lines
      | get ($line - 1)
      | str replace -r '^- \[ \] ' '- [x] '
    )
    | str join (char nl)

  $"($updated)\n" | save -f (todo-file)
}

def todo-mark-delete [line: int] {
  let updated = open --raw (todo-file)
    | lines
    | drop nth ($line - 1)
    | str join (char nl)

  $"($updated)\n" | save -f (todo-file)
}

def todo-confirm-finished [item: string] {
  let answer = try {
    ["yes", "no", "delete"] | input list -f $"Finished implementing: [($item)]?"
  } catch {
    return "no"
  }

  $answer
}

def --env todo-work-item [item: record] {
  print $"Working on: ($item.text)"
  print "Opening a new shell. Exit it when done."

  $env.TODO_ITEM = $item.text
  nu
  hide-env TODO_ITEM

  let answer = (todo-confirm-finished $item.text)

  match $answer {
    "yes" => {
      todo-mark-done $item.line
    },
    "delete" => {
      todo-mark-delete $item.line      
    },
    _ => {},
  }
}

def todo-add-items-from-editor [] {
  let tmp = (^mktemp)
  let editor_parts = (($env.EDITOR? | default "vi") | split row " ")
  run-external ($editor_parts | first) ...($editor_parts | skip 1) $tmp
  let text = (open --raw $tmp | str trim)
  rm -p $tmp

  if (($text | str length) == 0) {
    return []
  }

  let new_items = ($text | lines | where {|x| ($x | str length) != 0})
  if ($new_items | is-empty) {
    return []
  }

  let start_line = if ((todo-file) | path exists) {
    (open --raw (todo-file) | lines | length) + 1
  } else {
    1
  }

  if not ((todo-file) | path exists) {
    "" | save -f (todo-file)
  }

  let formatted = ($new_items | each {|l| $"- [ ] ($l)"} | str join (char nl))
  $"($formatted)\n" | save -a (todo-file)

  $new_items
  | enumerate
  | each {|row|
    {
      line: ($start_line + $row.index)
      text: $row.item
    }
  }
}

export def "!todo add" [] {
  todo-add-items-from-editor | ignore
}

export def "!todo pick" [] {
  let undone = (todo-undone-items)

  if ($undone | is-empty) {
    print "No undone todo items."
    return
  }

  let selected = try {
    $undone | input list -f "Pick a todo item"
  } catch {
    return
  }

  todo-work-item $selected
}

export def "!todo random" [] {
  let undone = (todo-undone-items)

  if ($undone | is-empty) {
    print "No undone todo items."
    return
  }

  let index = (random int ..(($undone | length) - 1))
  let selected = ($undone | get $index)
  todo-work-item $selected
}

export def "!todo imm" [] {
  let created = (todo-add-items-from-editor)

  if ($created | is-empty) {
    return
  }

  let selected = if (($created | length) == 1) {
    $created | first
  } else {
    try {
      $created | input list -f "Pick item to start now"
    } catch {
      return
    }
  }

  todo-work-item $selected
}
