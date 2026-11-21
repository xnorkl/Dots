# xnorlord's .zsh

# options
setopt autocd              # change directory just by typing its name
setopt correct             # auto correct mistakes
setopt interactivecomments # allow comments in interactive mode
setopt ksharrays           # arrays start at 0
setopt magicequalsubst     # enable filename expansion for arguments of the form ‘anything=expression’
setopt nonomatch           # hide error message if there is no match for the pattern
setopt notify              # report the status of background jobs immediately
setopt numericglobsort     # sort filenames numerically when it makes sense
setopt promptsubst         # enable command substitution in prompt

WORDCHARS=${WORDCHARS//\/} # Don't consider certain characters part of the word

# paths
export GOPATH=$HOME/go
export EDITOR=vim
[[ -d $HOME/Library/Python/3.9/bin ]] && export PATH=$PATH:$HOME/Library/Python/3.9/bin

# gh env
[[ -x /opt/homebrew/bin/brew ]] && eval "$(/opt/homebrew/bin/brew shellenv)"
command -v gh >/dev/null && export GITHUB_PERSONAL_ACCESS_TOKEN="$(gh auth token 2>/dev/null)"

# pyenv init
export PYENV_ROOT="$HOME/.pyenv"
command -v pyenv >/dev/null || export PATH="$PYENV_ROOT/bin:$PATH"
command -v pyenv >/dev/null && eval "$(pyenv init -)"

# ssh
plugins=(git ssh-agent)    # Set ssh agent

# hide EOL sign ('%')
export PROMPT_EOL_MARK=""

# configure key keybindings
bindkey -e                                        # emacs key bindings
bindkey ' ' magic-space                           # do history expansion on space
bindkey '^[[3;5~' kill-word                       # ctrl + Supr
bindkey '^[[1;5C' forward-word                    # ctrl + ->
bindkey '^[[C' forward-word                       # ctrl + ->
bindkey '^[[1;5D' backward-word                   # ctrl + <-
bindkey '^[[D' backward-word                      # ctrl + <-
bindkey '^[[5~' beginning-of-buffer-or-history    # page up
bindkey '^[[6~' end-of-buffer-or-history          # page down
bindkey '^[[Z' undo                               # shift + tab undo last action

# enable completion features
autoload -Uz compinit
compinit -d ~/.cache/zcompdump
zstyle ':completion:*:*:*:*:*' menu select
zstyle ':completion:*' matcher-list 'm:{a-zA-Z}={A-Za-z}' # case insensitive tab completion
zstyle ':completion:*' completer _expand _complete _ignored _approximate
zstyle ':completion:*' completions 1
zstyle ':completion:*' glob 1
zstyle ':completion:*' max-errors 5 numeric
zstyle ':completion:*' prompt '!'
zstyle ':completion:*' substitute 1
zstyle :compinstall filename "$HOME/.zshrc"

# history configurations
HISTFILE=~/.zsh_history
HISTSIZE=1000
SAVEHIST=2000
setopt hist_expire_dups_first # delete duplicates first when HISTFILE size exceeds HISTSIZE
setopt hist_ignore_dups       # ignore duplicated commands history list
setopt hist_ignore_space      # ignore commands that start with space
setopt hist_verify            # show command with history expansion to user before running it

# force zsh to show the complete history
alias history="history 0"

# make less more friendly for non-text input files, see lesspipe(1)
[ -x /usr/bin/lesspipe ] && eval "$(SHELL=/bin/sh lesspipe)"

# Dirstack
DIRSTACKFILE="$HOME/.cache/zsh/dirs"
[[ -d ${DIRSTACKFILE:h} ]] || mkdir -p ${DIRSTACKFILE:h}
if [[ -f $DIRSTACKFILE ]] && [[ $#dirstack -eq 0 ]]; then
    dirstack=( ${(f)"$(< $DIRSTACKFILE)"} )
    [[ -d ${dirstack[0]} ]] && cd ${dirstack[0]}   # ksharrays: index 0 is first
fi
chpwd() {
    # default needed: function-only shells (e.g. snapshots) don't carry the variable
    print -l $PWD ${(u)dirstack} >"${DIRSTACKFILE:-$HOME/.cache/zsh/dirs}"
}

DIRSTACKSIZE=20

setopt AUTO_PUSHD PUSHD_SILENT PUSHD_TO_HOME

## Remove duplicate entries
setopt PUSHD_IGNORE_DUPS

## This reverts the +/- operators
setopt PUSHD_MINUS

### Fish-like Syntax
#source /usr/share/zsh/plugins/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh

# set variable identifying the chroot you work in (used in the prompt below)
if [ -z "${debian_chroot:-}" ] && [ -r /etc/debian_chroot ]; then
    debian_chroot=$(cat /etc/debian_chroot)
fi

# set a fancy prompt 
case "$TERM" in
    xterm-color|*-256color) color_prompt=yes;;
esac

#fpath=( "${ZDOTIR:-$HOME}/.zfunctions" $fpath)

# set starship
command -v starship >/dev/null && eval "$(starship init zsh)"



# enable color support of ls, less and man, and also add handy aliases
if [ -x /usr/bin/dircolors ]; then
    test -r ~/.dircolors && eval "$(dircolors -b ~/.dircolors)" || eval "$(dircolors -b)"
    alias ls='ls --color=auto'
    alias dir='dir --color=auto'
    alias vdir='vdir --color=auto'
    alias grep='grep --color=auto'
    alias fgrep='fgrep --color=auto'
    alias egrep='egrep --color=auto'
    alias diff='diff --color=auto'
    alias ip='ip --color=auto'

    export LESS_TERMCAP_mb=$'\E[1;31m'     # begin blink
    export LESS_TERMCAP_md=$'\E[1;36m'     # begin bold
    export LESS_TERMCAP_me=$'\E[0m'        # reset bold/blink
    export LESS_TERMCAP_so=$'\E[01;33m'    # begin reverse video
    export LESS_TERMCAP_se=$'\E[0m'        # reset reverse video
    export LESS_TERMCAP_us=$'\E[1;32m'     # begin underline
    export LESS_TERMCAP_ue=$'\E[0m'        # reset underline

    # Take advantage of $LS_COLORS for completion as well
    zstyle ':completion:*' list-colors "${(s.:.)LS_COLORS}"
fi

# enable auto-suggestions based on the history
if [ -f /usr/share/zsh-autosuggestions/zsh-autosuggestions.zsh ]; then
    . /usr/share/zsh-autosuggestions/zsh-autosuggestions.zsh
    # change suggestion color
    ZSH_AUTOSUGGEST_HIGHLIGHT_STYLE='fg=#999'
fi

## set aliases
alias ll='ls -l'
alias la='ls -A'
alias l='ls -CF'
alias v='nvim'
alias gp='grep -G "^[0-9]*/"'
alias sed='gsed'
alias ls='ls --color=always'
alias pop='popd'
alias push='pushd'
alias ds='dirs -v'
alias les='/usr/share/vim/vim81/macros/less.sh'
alias success='lolcat ~/.tp -a -s 40 -d 2'
alias wiki='vim ~/Wiki/vimwiki/index.wiki'
alias myip='curl ifconfig.me'
alias claude-personal='CLAUDE_CONFIG_DIR=~/.claude-personal claude'
alias claude-work='CLAUDE_CONFIG_DIR=~/.claude-work claude'   
alias cc=claude-work



###Functions
function createpasswd {
    LC_CTYPE=C tr -dc '[:graph:]' < /dev/urandom | tr -d '"'\' | head -c 32 | xargs
}

function sshtmux { 
    /usr/bin/ssh -t "$@" "tmux new -A"
}

function sshtunnel { 
    ssh -L 127.0.0.1:2222:$3:22 $1 -i $2 -N -o ServerAliveInterval=60
}

function getcert () {
	nslookup $1
    	(openssl s_client -showcerts -servername $1 -connect $1:443 <<< "Q" | openssl x509 -text | grep -iA2 "Validity")
}

function getservice () {
    sudo ss -tulpn | awk '{$3=""; $4=""; print $0}' | grep $1 | column -n results -N proto,state,src,dst,proc,etc -J 
}

function umask () {stat -f '%Lp' $1}
function umasks () {find $1 -print0 | xargs -0 stat -f '%Lp %n'}

function ffrecord () {
    ffmpeg -video_size 3440x1440 -framerate 25 -f x11grab -show_region 1 -select_region 1 -i :0.0 -f pulse -ac 2 -i $2 -c:v libx264 -crf 28 -preset ultrafast $1 -async 1 -vsync 1
}


fpath+=${ZDOTDIR:-~}/.zsh_functions

autoload -U +X bashcompinit && bashcompinit
[[ -x /opt/homebrew/bin/terraform ]] && complete -o nospace -C /opt/homebrew/bin/terraform terraform
[[ -x /opt/homebrew/bin/boundary ]] && complete -o nospace -C /opt/homebrew/bin/boundary boundary

# tool env scripts (each installer's own, sourced only if present)
for f in .local/bin/env .atuin/bin/env .deno/env .ghcup/env .bun/_bun \
         Library/Caches/@asyncapi/cli/autocomplete/zsh_setup; do
    [[ -f $HOME/$f ]] && . "$HOME/$f"
done
command -v atuin >/dev/null && eval "$(atuin init zsh)"

# tool bin dirs, prepended in original order (last = highest priority)
export BUN_INSTALL="$HOME/.bun" FLYCTL_INSTALL="$HOME/.fly"
for d in .antigravity/antigravity/bin .bun/bin .git-ai/bin .cubic/bin .kimi-code/bin .fly/bin; do
    [[ -d $HOME/$d ]] && PATH="$HOME/$d:$PATH"
done
unset f d

# machine/engagement-specific config — not in the dotfiles repo
[[ -f ~/.zshrc.local ]] && . ~/.zshrc.local
