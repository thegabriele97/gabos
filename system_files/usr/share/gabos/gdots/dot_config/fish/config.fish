if status is-interactive
    # Commands to run in interactive sessions can go here

    # Solves HOME being set to a symlink, which causes issues with fish prompt
    set -gx HOME (realpath $HOME)
end
