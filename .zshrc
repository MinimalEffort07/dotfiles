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
zstyle ':vcs_info:git:*' formats '(%F{cyan}%b%F{clear})'

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
export PROMPT='%B%F{$((($RANDOM % 255)))}%n%F{clear}%b%B[%2~]${vcs_info_msg_0_}%b%# '
export RPROMPT='%(?..[%B%F{red}%?%F{clear}%b] )'
export DOTFILES="/Users/emmanuelchristianos/projects/minimaleffort/dotfiles"
# Aliases
alias zshrc="vim $HOME/.zshrc"
alias sourcezsh="source $HOME/.zshrc"
alias vimrc="vim $HOME/.vimrc"

alias venv="source .v/bin/activate"

alias c="clear"
alias cl="clear"
alias cle="clear"
alias clea="clear"
alias cc="clear && printf '\e[3J'"
alias celar="clear" 

alias ls="ls -1c --color -Fv"
alias l="ls"
alias la="ls -A"
alias rls="ls"
alias sl="ls"

alias v="nvim"
alias vi="nvim"
alias vim="nvim"

alias gr="grep -inRI --color"

alias gst="git status"
alias ga="git add"
alias gc="git commit"
alias gl="git pull"
alias gp="git push"

alias p="python3"
alias ctf='docker start ctf && docker attach --detach-keys="ctrl-@" ctf'

bindkey -v
bindkey ^R history-incremental-search-backward
bindkey ^P up-line-or-history
bindkey ^N down-line-or-history
bindkey -M viins 'jk' vi-cmd-mode 

LS_COLORS='rs=0:di=01;90:ln=01;36:mh=00:pi=40;33:so=01;35:do=01;35:bd=40;33;01:cd=40;33;01:or=40;31;01:mi=00:su=37;41:sg=30;43:ca=30;41:tw=30;42:ow=34;42:st=37;44:ex=01;32:*.tar=01;31:*.tgz=01;31:*.arc=01;31:*.arj=01;31:*.taz=01;31:*.lha=01;31:*.lz4=01;31:*.lzh=01;31:*.lzma=01;31:*.tlz=01;31:*.txz=01;31:*.tzo=01;31:*.t7z=01;31:*.zip=01;31:*.z=01;31:*.dz=01;31:*.gz=01;31:*.lrz=01;31:*.lz=01;31:*.lzo=01;31:*.xz=01;31:*.zst=01;31:*.tzst=01;31:*.bz2=01;31:*.bz=01;31:*.tbz=01;31:*.tbz2=01;31:*.tz=01;31:*.deb=01;31:*.rpm=01;31:*.jar=01;31:*.war=01;31:*.ear=01;31:*.sar=01;31:*.rar=01;31:*.alz=01;31:*.ace=01;31:*.zoo=01;31:*.cpio=01;31:*.7z=01;31:*.rz=01;31:*.cab=01;31:*.wim=01;31:*.swm=01;31:*.dwm=01;31:*.esd=01;31:*.jpg=01;35:*.jpeg=01;35:*.mjpg=01;35:*.mjpeg=01;35:*.gif=01;35:*.bmp=01;35:*.pbm=01;35:*.pgm=01;35:*.ppm=01;35:*.tga=01;35:*.xbm=01;35:*.xpm=01;35:*.tif=01;35:*.tiff=01;35:*.png=01;35:*.svg=01;35:*.svgz=01;35:*.mng=01;35:*.pcx=01;35:*.mov=01;35:*.mpg=01;35:*.mpeg=01;35:*.m2v=01;35:*.mkv=01;35:*.webm=01;35:*.webp=01;35:*.ogm=01;35:*.mp4=01;35:*.m4v=01;35:*.mp4v=01;35:*.vob=01;35:*.qt=01;35:*.nuv=01;35:*.wmv=01;35:*.asf=01;35:*.rm=01;35:*.rmvb=01;35:*.flc=01;35:*.avi=01;35:*.fli=01;35:*.flv=01;35:*.gl=01;35:*.dl=01;35:*.xcf=01;35:*.xwd=01;35:*.yuv=01;35:*.cgm=01;35:*.emf=01;35:*.ogv=01;35:*.ogx=01;35:*.aac=00;36:*.au=00;36:*.flac=00;36:*.m4a=00;36:*.mid=00;36:*.midi=00;36:*.mka=00;36:*.mp3=00;36:*.mpc=00;36:*.ogg=00;36:*.ra=00;36:*.wav=00;36:*.oga=00;36:*.opus=00;36:*.spx=00;36:*.xspf=00;36:';
export LS_COLORS
