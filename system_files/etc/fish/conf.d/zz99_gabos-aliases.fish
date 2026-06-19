#!/usr/bin/env fish

# --- Environment guard -------------------------------------------------------
if set -q DISTROBOX_ENTER_PATH
    return
end

# --- Helper utilities --------------------------------------------------------
function _command_exists
    command -v "$argv[1]" >/dev/null 2>&1
end

# --- Wrappers ----------------------------------------------------------------
function fastfetch
    if test (count $argv) -eq 0
        command fastfetch -c "/usr/share/gabos/gdots/system/fastfetch/fastfetch.jsonc"
    else
        command fastfetch $argv
    end
end

function neofetch
    if test (count $argv) -eq 0
        command fastfetch -c "/usr/share/gabos/gdots/system/fastfetch/fastfetch.jsonc"
    else
        command fastfetch $argv
    end
end

alias sudoedit="sudoedit-rs"

# -- Convience Alias's --------------------------------------------------------
alias update="sudo rakuos upgrade"

# --- Interactive tooling -----------------------------------------------------
if status is-interactive
    set -g fish_greeting "" # Disable welcome message

    if _command_exists fzf; fzf --fish | source; end
    if _command_exists starship; starship init fish | source; end
    if _command_exists zoxide; zoxide init fish --cmd cd | source; end
end
