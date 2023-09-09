
# Prompt
#
# vcs_info is a function that (among other things) stores the branch name of the
# current git repo you are in within a variables called $vcs_info_msg_0_
#
# autoload -Uz allows us to call the function 'vcs_info'
autoload -Uz vcs_info

# precmd() is a special zsh function that runs before every time a prompt is 
# printed. (Normally this is after a command has been executed and we redraw the
# prompt underneath the output of the previous command. We have to run vcs_info 
# after every command because we may have moved into another git repo, or 
# changed branches and therefore the information vcs_info stored in the 
# $vcs_info_msg_0_ variable would be out of date.
precmd() { vcs_info }

# We are formatting the contents of the vcs_info_msg_0_ variable (its contents
# will replace the %b in the format text below" 
zstyle ':vcs_info:git:*' formats '(%F{11}%b%F{white})'

# This option allows us to run commands within our prompt expansion which we 
# need for shuf and vcs_info
setopt PROMPT_SUBST

# List of good found colors
#   147 - Light purple
#
# PROMPT holds the prompt for left hand side of the terminal. RPROMPT holds for 
# the right hand side.
#
# IMPORTANT: PROMPT and RPROMPT needs to be in single quotes otherwise they 
# don't work. 
#
# %B - starts bold text
# %b - ends bold text
#
# %F{color} - change text color to 'color'
# $(shuf -i 1-255 -n 1) - gets a number between 0 - 255 to use as the text color
# for the username.
#
# %2~ - Displays the current directory and its parent
#
# %# - Display either '%' or '#' depending on if you are executing with regular 
# or super user permissions.
#
# %(?..[%B%F{red}%?%F{clear}%b] ) - Displays the text only if the value from $?
# is not 0. 
#
# NOTE: If further explanation is required search up 'zsh prompt expansion'
#
# Prompt
export PROMPT='%B%F{$((($RANDOM % 255)))}%S %s %n%F{white}%b%B[%2~]%b${vcs_info_msg_0_}%# '
export RPROMPT='%(?..[%B%F{red}%?%F{white}%b])'

export TERM=xterm-256color
export PAGER=less
export EDITOR=nvim
export DOTFILES="~/projects/minimaleffort/dotfiles"

# Aliases
alias zshrc="vim ~/.zshrc"
alias vimrc="vim ~/.config/nvim/init.vim"
alias gdbinit="vim ~/.gdbinit"

alias sourcezsh="source ~/.zshrc"
alias venv="source .v/bin/activate"

alias dotfiles="cd ${DOTFILES}"

alias c="clear"
alias cl="clear"
alias cle="clear"
alias clea="clear"
alias cc="clear && printf '\e[3J'"
alias celar="clear" 

if [[ "$(uname)" = "Darwin" ]]
then
    alias ls="gls -1c --color -Fv"
    alias sed="gsed"
else
    alias ls="ls -1c --color -Fv"
    export PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin:/usr/games:/usr/local/games:/snap/bin:/snap/bin:/home/minimaleffort/.local/bin
fi

alias l="ls"
alias ll="ls -l"
alias la="ls -A"
alias lla="ls -la"
alias rls="ls"
alias sl="ls"

alias v="nvim"
alias vi="nvim"
alias vim="nvim"

alias gr="grep -inRI --color"

alias g="git"
alias gst="git status"
alias ga="git add"
alias gc="git commit"
alias gl="git pull"
alias gp="git push"
alias gd="git diff"

alias p="python3"
alias ctf='docker start ctf && docker attach --detach-keys="ctrl-@" ctf'

bindkey -v
bindkey ^R history-incremental-search-backward
bindkey ^P up-line-or-history
bindkey ^N down-line-or-history
bindkey -M viins 'jk' vi-cmd-mode 

# Fixes inability to delete characters in zsh vim insert mode. 
bindkey "^H" backward-delete-char
bindkey "^?" backward-delete-char

export LS_COLORS='no=00;38;5;15:fi=00:rs=0:di=1;95:ln=01;38;5;111:mh=00:pi=48;5;230;38;5;136;01:so=48;5;230;38;5;136;01:bd=;4;230;38;5;142;01:cd=;1;230;38;5;94;01:or=38;5;009;48;5;052:su=48;5;160;38;5;230:sg=48;5;136;38;5;230:ca=30;41:st=48;5;33;38;5;230:ow=38;5;110:tw=48;5;64;38;5;230:ex=0;38;5;154:*.s=01;38;5;123:*.c=01;38;5;148:*.h=01;38;5;150:*.cpp=01;38;5;064:*.ru=01;38;5;088:*.js=01;38;5;003:*.sh=01;38;5;067:*Makefile=0;38;5;243:*Rakefile=0;38;5;124:*Gemfile=0;38;5;3:*Gemfile.lock=0;38;5;239:*.gemspec=0;38;5;3:*Procfile=0;38;5;244:*Gopkg.toml=0;38;5;3:*Gopkg.lock=0;38;5;239:*.gitignore=0;38;5;243:*.gitattributes=0;38;5;243:*.json=01;38;5;3:*.yml=01;38;5;3:*.yaml=01;38;5;3:*.xml=01;38;5;3:*.csv=01;38;5;3:*.pb=01;38;5;201:*.proto=01;38;5;201:*.bson=01;38;5;201:*.txt=01;38;5;15:*.tex=01;38;5;15:*.nfo=01;38;5;5:*.rdf=01;38;5;5:*.docx=01;38;5;5:*.pdf=01;38;5;5:*.markdown=01;38;5;5:*.md=01;38;5;5:*README=01;38;5;200:*README.md=01;38;5;200:*README.txt=01;38;5;200:*readme.txt=01;38;5;200:*LICENSE=01;38;5;165:*LICENSE.txt=01;38;5;165:*AUTHORS=01;38;5;165:*COPYRIGHT=01;38;5;165:*CONTRIBUTORS=01;38;5;165:*CONTRIBUTING.md=01;38;5;165:*PATENTS=01;38;5;165:*.bak=00;38;5;239:*.swp=00;38;5;239:*.tmp=00;38;5;239:*.temp=00;38;5;239:*.o=00;38;5;239:*.pyc=00;38;5;239:*.iso=01;38;5;209:*.dmg=01;38;5;209:*.zip=01;38;5;61:*.tar=00;38;5;61:*.tgz=01;38;5;61:*.lzh=01;38;5;61:*.z=01;38;5;61:*.Z=01;38;5;61:*.7z=01;38;5;61:*.gz=01;38;5;61:*.bz2=01;38;5;61:*.bz=01;38;5;61:*.deb=01;38;5;61:*.rpm=01;38;5;61:*.jar=01;38;5;61:*.rar=01;38;5;61:*.apk=01;38;5;61:*.gem=01;38;5;61:';


# The following lines were added by compinstall

zstyle ':completion:*' completer _complete _ignored _approximate
zstyle ':completion:*' max-errors 0
zstyle :compinstall filename '/Users/emmanuelchristianos/.zshrc'

autoload -Uz compinit
compinit
# End of lines added by compinstall
