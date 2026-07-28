def --env fzf-complete [] {
  let buffer = commandline
  # get-cursor/set-cursor count grapheme clusters, completion spans are utf-8 byte
  # offsets, and `str substring`/`str length` default to bytes.
  let cursor = commandline get-cursor
  let prefix = ($buffer | str substring --grapheme-clusters 0..<$cursor)
  let completions = ($prefix | commandline complete --detailed)

  if ($completions | is-empty) {
    return
  }

  # `complete` keeps fzf's exit code out of $env.LAST_EXIT_CODE: dismissing the picker
  # exits 130, which would otherwise show up as a failed command in the prompt.
  let picker = (
    $completions
    | enumerate
    | each {|entry|
        # Newlines/tabs in a description would desync the index round-trip below.
        let description = (
          $entry.item.description?
          | default ""
          | str replace --all --regex '\s+' " "
        )
        $"($entry.index)\t($entry.item.value)\t($description)"
      }
    | str join (char nl)
    | ^fzf
        --height "40%"
        --layout reverse
        --border
        --select-1
        --delimiter "\t"
        --with-nth "2.."
    | complete
  )

  if $picker.exit_code != 0 {
    return
  }

  let choice = ($picker.stdout | str trim)

  if ($choice | is-empty) {
    return
  }

  let selected = ($completions | get ($choice | split row "\t" | first | into int))
  let before = ($buffer | str substring 0..<$selected.span.start)
  let after = ($buffer | str substring $selected.span.end..)

  commandline edit --replace $"($before)($selected.value)($after)"
  commandline set-cursor (
    $"($before)($selected.value)" | str length --grapheme-clusters
  )
}

$env.config.keybindings ++= [{
  name: fzf_completion
  modifier: none
  keycode: tab
  mode: [emacs vi_insert]
  event: {
    send: executehostcommand
    cmd: "fzf-complete"
  }
}]
