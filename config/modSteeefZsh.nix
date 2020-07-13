{ pkgs, ... }:

with pkgs;

writeTextDir "themes/mod_steeef.zsh-theme" ''
# prompt style and colors based on Steve Losh's Prose theme:
# http://github.com/sjl/oh-my-zsh/blob/master/themes/prose.zsh-theme
#
# vcs_info modifications from Bart Trojanowski's zsh prompt:
# http://www.jukie.net/bart/blog/pimping-out-zsh-prompt
#
# git untracked files modification from Brian Carper:
# http://briancarper.net/blog/570/git-info-in-your-zsh-prompt

export VIRTUAL_ENV_DISABLE_PROMPT=1

function virtualenv_info {
    [ $VIRTUAL_ENV ] && echo '('%F{blue}`basename $VIRTUAL_ENV`%f') '
}
PR_GIT_UPDATE=1

setopt prompt_subst

autoload -U add-zsh-hook
autoload -Uz vcs_info

#use extended color pallete if available
if [[ $terminfo[colors] -ge 256 ]]; then
    turquoise="%F{9}"
    orange="%F{1}"
    purple="%F{13}"
    hotpink="%F{9}"
    limegreen="%F{3}"
else
    turquoise="%F{cyan}"
    orange="%F{yellow}"
    purple="%F{magenta}"
    hotpink="%F{red}"
    limegreen="%F{green}"
fi

# enable VCS systems you use
zstyle ':vcs_info:*' enable git svn

# check-for-changes can be really slow.
# you should disable it, if you work with large repositories
zstyle ':vcs_info:*:prompt:*' check-for-changes true

# set formats
# %b - branchname
# %u - unstagedstr (see below)
# %c - stagedstr (see below)
# %a - action (e.g. rebase-i)
# %R - repository path
# %S - path in the repository
PR_RST="%f"
FMT_BRANCH="(%{$turquoise%}%b%u%c''${PR_RST})"
FMT_ACTION="(%{$limegreen%}%a''${PR_RST})"
FMT_UNSTAGED="%{$orange%}●"
FMT_STAGED="%{$limegreen%}●"

zstyle ':vcs_info:*:prompt:*' unstagedstr   "''${FMT_UNSTAGED}"
zstyle ':vcs_info:*:prompt:*' stagedstr     "''${FMT_STAGED}"
zstyle ':vcs_info:*:prompt:*' actionformats "''${FMT_BRANCH}''${FMT_ACTION}"
zstyle ':vcs_info:*:prompt:*' formats       "''${FMT_BRANCH}"
zstyle ':vcs_info:*:prompt:*' nvcsformats   ""

function nix_shell {
  [ $IN_NIX_SHELL ] && echo '('%F{green}`echo $IN_NIX_SHELL`%f') '
}

function steeef_precmd {
    # check for untracked files or updated submodules, since vcs_info doesn't
    if git ls-files --other --exclude-standard 2> /dev/null | grep -q "."; then
        PR_GIT_UPDATE=1
        FMT_BRANCH="(%{$turquoise%}%b%u%c%{$hotpink%}●''${PR_RST})"
    else
        FMT_BRANCH="(%{$turquoise%}%b%u%c''${PR_RST})"
    fi
    zstyle ':vcs_info:*:prompt:*' formats " ''${FMT_BRANCH}"

    vcs_info 'prompt'
}
add-zsh-hook precmd steeef_precmd

# http://zsh.sourceforge.net/Doc/Release/Prompt-Expansion.html#Date-and-time
pr_24h_clock=' %*'

PROMPT=$'
%{$purple%}%n''${PR_RST} at %{$orange%}%m''${PR_RST} in %{$limegreen%}%~''${PR_RST} at%{$hotpink%}$pr_24h_clock''${PR_RST}$vcs_info_msg_0_$(virtualenv_info)$(nix_shell)
$ '

''
