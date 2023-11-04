#!/bin/bash
#
# Install and setup packages and configuration files
# Author: Emmanuel Christianos


CYAN="\x1b\x5b1;96m"
RED="\x1b\x5b1;91m"
GREEN="\x1b\x5b1;92m"
YELLOW="\x1b\x5b1;93m"
MAGENTA="\x1b\x5b1;95m"
BRIGHT_BLACK="\x1b\x5b1;3;90m"
BLUE="\x1b\x5b1;3;94m"
RES="\x1b\x5b0m"

# \x08 is BS 'Backspace' character. Used to remove ^C from output.
trap 'echo -e "\x08\x08Signal ${RED}SIGINT${RES} Caught.. Exiting" && exit 1' SIGINT

function print_info() {
    echo -e "[${CYAN}INFO${RES}] $@"
}

function print_warn() {
    echo -e "[${YELLOW}WARN${RES}] $@"
}

function print_err() {
    echo -e "[${RED}ERROR${RES}] $@"
}

function print_section() {
    echo -e "[${GREEN}SECTION${RES}] ----- ${GREEN}${@}${RES} -----"
}

function minimise_path() {
    sed s@${HOME}@\~@g <<< "$1"
}

function style_path() {
    echo -e ${BRIGHT_BLACK}$(minimise_path "$@")${RES}
}

function emphasize_text() {
    echo -e "${BLUE}$@${RES}"
}

function highlight_text() {
    echo -e "${MAGENTA}$@${RES}"
}


function dotfiles_bannner() {

    echo -e "
           ██╗██████╗  ██████╗ ████████╗███████╗██╗██╗     ███████╗███████╗
          ██╔╝██╔══██╗██╔═══██╗╚══██╔══╝██╔════╝██║██║     ██╔════╝██╔════╝
         ██╔╝ ██║  ██║██║   ██║   ██║   █████╗  ██║██║     █████╗  ███████╗
        ██╔╝  ██║  ██║██║   ██║   ██║   ██╔══╝  ██║██║     ██╔══╝  ╚════██║
    ██╗██╔╝   ██████╔╝╚██████╔╝   ██║   ██║     ██║███████╗███████╗███████║
    ╚═╝╚═╝    ╚═════╝  ╚═════╝    ╚═╝   ╚═╝     ╚═╝╚══════╝╚══════╝╚══════╝\x0a"
}


function clone_repos() {

    arr=("$@")
    for repo_url in "$@"; do
        # We want to obtain repo name which will always be .../<name_here>.git
        # since names can't have forward slashes in them we can split the URL
        # by slashes using cut however, we don't know how many fields there are
        # so we reverse the URL first, making the name be the first field and
        # we split on '/', get the first element which will be tig.<name_in_rev>
        # we split again but on '.' and take the second field i.e. the name and
        # reverse the name back to normal text.
        repo_name="$(echo "$repo_url" | rev | cut -d'/' -f1 | cut -d. -f 2 | rev)"

        if sudo test -d "/opt/${repo_name}"; then
            print_warn "$(highlight_text ${repo_name}) already exists. $(highlight_text Skipping..)"
        else
            print_info "Attempting to clone ${repo_name} into /opt/${repo_name}"
            if sudo git clone -q $repo_url "/opt/${repo_name}"; then
                print_info "Successfully cloned ${repo_name}"

                print_info "Attempting to chown /opt/${repo_name} to $USER ownership"
                if sudo chown -R $USER: "/opt/${repo_name}"; then
                    print_info "Successfully updated ownership"
                else
                    print_err "Failed to updated ownership. Aborting"
                    exit 1
                fi
            else
                    print_err "Failed to clone ${repo_name} repo. Aborting"
                    exit 1
            fi
        fi
    done
}

function create_syms() {
    arr=("$@")

    for sym in "$@"; do
        symarr=($sym)

        print_info "Attempting to create symlink,"\
            "$(style_path ${symarr[1]}) $(style_path '->') $(style_path ${symarr[0]})"

        if sudo [ -f "${symarr[1]}" ] && sudo [ ! -L "${symarr[1]}" ]; then

            print_warn "....$(style_path ${symarr[1]}) already exists but is"\
                       "not a symlink. Attempting to back it up now"

            # Attempting backup of non symlink configuration files
            if mv "${symarr[1]}" "${symarr[1]}.dotfiles.bak" &>/dev/null; then
                print_info "....$(style_path ${symarr[1]}) Successfully backed up to"\
                           "$(style_path ${symarr[1]}.dotfiles.bak)"
            elif sudo mv "${symarr[1]}" "${symarr[1]}.dotfiles.bak" &>/dev/null; then
                print_warn "....$(style_path ${symarr[1]}) Successfully backed up to"\
                    "$(style_path ${symarr[1]}.dotfiles.bak). $(highlight_text Required sudo)"
            else
                print_warn "....Unable to backup $(syle_path ${symarr[1]})"
            fi
        fi

        # Attempting to remove existing destination file
        if sudo test -e ${symarr[1]} || sudo test -h ${symarr[1]}; then
            print_info "....Attempting to remove old $(style_path ${symarr[1]})"
            if rm "${symarr[1]}" &>/dev/null; then
                print_info "....Successfully removed $(style_path ${symarr[1]})"
            elif sudo rm "${symarr[1]}" &>/dev/null; then
                print_warn "....Successfully removed "\
                    "$(style_path ${symarr[1]}). $(highlight_text Required sudo)"
            else
                print_err "....Failed to removed $(style_path ${symarr[1]})"
            fi
        fi

        if ln -s "${symarr[0]}" "${symarr[1]}" &>/dev/null; then
            print_info "....Successfully created symlink"
        elif sudo ln -s "${symarr[0]}" "${symarr[1]}" &>/dev/null; then
            print_warn "....Successfully created symlink. $(highlight_text Required sudo)"
        else
            print_err "....Failed to create symlink"
            exit 1
        fi
    done
}

# Given a list of directories create them.
function create_dirs() {
    arr=("$@")

    for dir in ${arr[@]}; do

        if sudo test -d "${dir}"; then
            print_warn "$(style_path ${dir}) already exists. $(highlight_text Skipping..)"
        else
            print_info "Attempting to create $(style_path ${dir})"

            if mkdir -p "${dir}"; then
                print_info "Created $(style_path ${dir})"
            elif sudo mkdir -p "${dir}" &>/dev/null; then
                print_warn "Created $(style_path ${dir}).. $(highlight_text Required sudo)"
            else
                print_err "Unable to create $(style_path ${dir}).."
                exit 1
            fi
        fi
    done
}

# Given a dependency name, check if it is installed on the system
function check_installed() {

     if which $1 &>/dev/null; then
        return 0
    else
        if [ "${PCKMAN}" = "brew" ]; then
            if $PCKMAN list -1 2>/dev/null | grep -E "^$1$" &>/dev/null; then
                return 0
            else
                return 1
            fi
        else
            if $PCKMAN list --installed 2>/dev/null | grep -E "^$1/" &>/dev/null; then
                return 0
            else
                return 1
            fi
        fi
    fi
}

# Given a list of dependencies, install them using: PCKMAN, OPTIONS
function install_deps() {
    arr=("$@")

    for dep in ${arr[@]}; do
        if check_installed "${dep}"; then
            print_info "$(highlight_text ${dep}) is already installed. $(highlight_text Skipping..)"
            continue
        fi
        print_info "Attempting to install ${dep}"
        if $PCKMAN install $OPTIONS ${dep} &>/dev/null; then
            print_info "Successfully installed $(highlight_text ${dep})"
        else
            if check_installed "${dep}"; then
                print_warn "Non terminal issue encountered while installing"\
                           "$(highlight_text ${dep}), it was still abled to be"\
                           " installed"
            else
                print_err "Failed to install $(highlight_text ${dep}), check "\
                          "the output. Exiting.."
            fi
        fi
    done
}

function uninstall_conflicts() {
    arr=("$@")

    for conflict in ${arr[@]}; do
        if ! check_installed "${conflict}"; then
            print_info "$(highlight_text ${conflict}) is not installed. $(highlight_text Skipping..)"
            continue
        fi

        print_info "Attempting to uninstall ${conflict}"

        if $PCKMAN remove ${conflict} -y &>/dev/null; then
            print_info "Successfully removed $(highlight_text ${conflict})"
        else
            if check_installed "${conflict}"; then
                print_err "Failed to remove conflict. $(emphasize_text Aborting..)"
                exit 1
            else
                print_warn "Successfully removed $(highlight_text ${conflict}) with warning from ${PCKMAN}"
            fi
        fi
    done
}

function main() {

    dotfiles_bannner

    ###########################################################################
    #                                                                         #
    #        Determining Operating System and Setting Relevant Envvars        #
    #                                                                         #
    ###########################################################################

    print_section "Determining OS"

    if test "$(uname)" = "Darwin"; then
        OS="MacOS"
        PCKMAN="brew"
        if test "$(uname -m)" = "arm64"; then
            ARM="arm64"
        fi
        MV=gmv
    else
        OS="Linux"
        PCKMAN="sudo apt"
        OPTIONS="-y"
        MV=mv
    fi

    print_info "OS is: $(highlight_text ${OS})"
    print_info "Using $(highlight_text ${PCKMAN}) package manager"

    ###########################################################################
    #                                                                         #
    #                 Configuring Package Manager On MacOS                    #
    #                                                                         #
    ###########################################################################

    if [ "$OS" = "MacOS" ] && [ -z "$(which  brew)" ]; then
        print_section "Installing Package Manager"
        print_info "Homebrew not installed, attempting to install now"
        local brewurl="https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh"
        if /bin/bash -c "$(curl -fsSL $brewurl)"; then
            print_err "Failed to install Homebrew.. Exiting"
            exit 1
        else
            print_info "Successfully installed Homebrew"
        fi
    fi

    ###########################################################################
    #                                                                         #
    #              Uninstalling Conflicting Software Packages                 #
    #                                                                         #
    ###########################################################################

    print_section "Uninstalling Conflicts"
    local conflicts_mac_only=()
    local conflicts_linux_only=()
    local conflicts_agnostic=("vim")

    if test -n "$conflicts_agnostic"; then
        print_info "$(emphasize_text Uninstalling Platform Agnostic Conflicts)"
        uninstall_conflicts ${conflicts_agnostic[@]}
    fi

    if [ "$OS" = "MacOS" ] && [ -n "$conflicts_mac_only" ]; then
        print_info "$(emphasize_text Uninstalling Mac Only Conflicts)"
        uninstall_conflicts ${conflicts_mac_only[@]}
    elif [ "$OS" = "Linux" ] && [ -n "$conflicts_linux_only" ]; then
        print_info "$(emphasize_text Uninstalling Linux Only Conflicts)"
        uninstall_conflicts ${conflicts_linux_only[@]}
    fi

    ###########################################################################
    #                                                                         #
    #                   Installing Software Dependencies                      #
    #                                                                         #
    ###########################################################################

    print_section "Installing Dependencies"

    local deps_mac_only=("coreutils" "binutils" "gnu-sed")
    local deps_linux_only=("i3" "rofi")
    local deps_agnostic=("curl" "zsh" "neovim" "pip" "gpg" "tar")

    if test -n "$deps_agnostic"; then
        print_info "$(emphasize_text Installing Platform Agnostic Dependencies)"
        install_deps ${deps_agnostic[@]}
    fi

    if [ "$OS" = "MacOS" ] && [ -n "$deps_mac_only" ]; then
        print_info "$(emphasize_text Installing Mac Only Dependencies)"
        install_deps ${deps_mac_only[@]}
    elif [ "$OS" = "Linux" ] && [ -n "$deps_linux_only" ]; then
        print_info "$(emphasize_text Installing Linux Only Dependencies)"
        install_deps ${deps_linux_only[@]}
    fi

    ###########################################################################
    #                                                                         #
    #                   Installing Required Repositories                      #
    #                                                                         #
    ###########################################################################

    # Installing Github Repos to be installed in /opt
    print_section "Cloning Repositories"
    local repos_mac_only=()
    local repos_arm_only=()
    local repos_intel_only=()
    local repos_linux_only=()
    local repos_agnostic=()

    if test -n "$repos_agnostic"; then
        print_info "$(emphasize_text Cloning Platform Agnostic Repositories)"
        clone_repos "${repos_agnostic[@]}"
    fi

    if test "$OS" = "MacOS"; then
        if test -n "$repos_mac_only"; then
            print_info "$(emphasize_text Cloning Mac Only Repositories)"
            clone_repos "${repos_mac_only[@]}"
        fi

        if [ -n "$ARM" ] && [ -n "$repos_arm_only" ]; then
            print_info "$(emphasize_text Cloning ARM Mac Only Repositories)"
            clone_repos "${repos_arm_only[@]}"
        elif [ -z "$ARM" ] && [ -n "$repos_intel_only" ]; then
            print_info "$(emphasize_text Cloning Intel Mac Only Repositories)"
            clone_repos "${repos_intel_only[@]}"
        fi

    else
        if test -n "$repos_linux_only"; then
            print_info "$(emphasize_text Cloning Linux Only Repositories)"
            clone_repos "${repos_linux_only[@]}"
        fi
    fi

    ###########################################################################
    #                                                                         #
    #               Configuring DOTFILES Environment Variable                 #
    #                                                                         #
    ###########################################################################

    print_section "Setting up DOTFILES Environment Variable"

    export DOTFILES="$(pwd)"
    print_info "DOTFILES=$(style_path ${DOTFILES})"
    print_info "Attempting to update DOTFILES variable in zshrc"

    if sed -E -i.dotfiles.bak s@DOTFILES=.\*@DOTFILES=\"$(minimise_path ${DOTFILES})\"@g "${DOTFILES}/zshrc"; then
        print_info "Successfully updated DOTFILES environment variable in zshrc"
    else
        print_err "Failed to updated DOTFILES environment variable in zshrc"
        exit 1
    fi

    ###########################################################################
    #                                                                         #
    #              Creating Required Configuration Directories                #
    #                                                                         #
    ###########################################################################

    print_section "Creating Directories"

    local dirs_mac_only=()
    local dirs_linux_only=("/root/.config/nvim/"
                           "/root/.local/share/nvim/site/autoload/"
                           "${HOME}/.config/i3"
                           "${HOME}/.config/rofi")

    local dirs_agnostic=("${HOME}/.config/nvim"
                         "${HOME}/projects/minimaleffort"
                         "${HOME}/projects/private-git")

    if test -n "$dirs_agnostic"; then
        print_info "$(emphasize_text Creating Platform Agnostic Directories)"
        create_dirs ${dirs_agnostic[@]}
    fi

    if [ "$OS" = "MacOS" ] && [ -n "$dirs_mac_only" ]; then
        print_info "$(emphasize_text Creating Mac Only Directories)"
        create_dirs "${dirs_mac_only[@]}"
    elif [ "$OS" = "Linux" ] && [ -n "$dirs_linux_only" ]; then
        print_info "$(emphasize_text Creating Linux Only Directories)"
        create_dirs "${dirs_linux_only[@]}"
    fi

    ###########################################################################
    #                                                                         #
    #                Creating Symlinks To Configuration Files                 #
    #                                                                         #
    ###########################################################################

    print_section "Creating Symlinks"

    local syms_mac_only=("/usr/local/bin/nvim /usr/local/bin/vim")
    local syms_linux_only=("${DOTFILES}/init.vim /root/.config/nvim/init.vim"
                           "${HOME}/.local/share/nvim/site/autoload/plug.vim /root/.local/share/nvim/site/autoload/plug.vim"
                           "${DOTFILES}/i3_config ${HOME}/.config/i3/config"
                           "${DOTFILES}/config.rasi ${HOME}/.config/rofi/config.rasi"
                           "${DOTFILES}/xmodmapmappings ${HOME}/.config/i3/xmodmapmappings"
                           "/usr/bin/nvim /usr/bin/vim")

    local syms_agnostic=("${DOTFILES}/zshrc ${HOME}/.zshrc"
                         "${DOTFILES}/init.vim ${HOME}/.config/nvim/init.vim"
                         "${DOTFILES}/gdbinit ${HOME}/.gdbinit")


    # Double quotes needed to prevent splitting of source and dest parts of string
    if test -n "$syms_agnostic"; then
        print_info "$(emphasize_text Creating Platform Agnostic Symlinks)"
        create_syms "${syms_agnostic[@]}"
    fi

    if [ "$OS" = "MacOS" ] && [ -n "$syms_mac_only" ]; then
        print_info "$(emphasize_text Creating Mac Only Symlinks)"
        create_syms "${syms_mac_only[@]}"
    elif [ "$OS" = "Linux" ] && [ -n "$syms_linux_only" ]; then
        print_info "$(emphasize_text Creating Linux Only Symlinks)"
        create_syms "${syms_linux_only[@]}"
    fi

    print_section "Executing Custom Commands"

    ###########################################################################
    #                                                                         #
    #                     Creating Local Config Script                        #
    #                                                                         #
    ###########################################################################

    print_info "$(emphasize_text Creating local config script at $(style_path ${HOME}/.dotfiles_local_config))"
    if [ ! -f ~/.dotfiles_local_config ]; then
        touch ~/.dotfiles_local_config && chmod +x ~/.dotfiles_local_config
    fi

    ###########################################################################
    #                                                                         #
    #                    Installing Vim Plugin Manager                        #
    #                                                                         #
    ###########################################################################

    if [ -f ~/.local/share/nvim/site/autoload/plug.vim ]; then
        print_info "$(highlight_text Vim-Plug) already installed. $(highlight_text Skipping..)"
    else
        sh -c 'curl -fLo "${XDG_DATA_HOME:-$HOME/.local/share}"/nvim/site/autoload/plug.vim --create-dirs \
            https://raw.githubusercontent.com/junegunn/vim-plug/master/plug.vim' &>/dev/null

        if [ -f ~/.local/share/nvim/site/autoload/plug.vim ]; then
            print_info "Successfully installed $(highlight_text Vim-Plug)"
        else
            print_err "Failed to install $(highlight_text Vim-Plug)"
            exit 1
        fi
    fi

    ###########################################################################
    #                                                                         #
    #                 Setting Up Encrypted Git Config File                    #
    #                                                                         #
    ###########################################################################

    print_info "$(emphasize_text Setting up .gitconfigs)"
    print_info "Enter Password To Decrypt gitconfig.enc"
    gpg --output gitconfig.tar -d gitconfig.enc &>/dev/null
    if [ $? -ne 0 ]; then
        print_err "Failed To Decrypt gitconfig.enc File"
        exit 1
    fi

    tar xvf gitconfig.tar &>/dev/null
    if [ $? -ne 0 ]; then
        print_err "Failed To Decompress gitconfig.tar File"
        exit 1
    fi

    rm -rf gitconfig.tar
    if [ $? -ne 0 ]; then
        print_warn "Failed To Remove Decrypted gitconfig.tar. You May Want To Manually Remove It"
    fi

    print_info "Copied $(style_path gitconfig/.global-gitconfig) to $(style_path ${HOME}/.gitconfig)"
    ${MV} --backup=numbered gitconfig/.global-gitconfig ${HOME}/.gitconfig

    print_info "Copied $(style_path gitconfig/.private-gitconfig) to $(style_path ${HOME}/projects/private-git/.gitconfig)"
    ${MV} --backup=numbered  gitconfig/.private-gitconfig ${HOME}/projects/private-git/.gitconfig &>/dev/null

    print_info "Copied $(style_path gitconfig/.minimaleffort-gitconfig) to $(style_path ${HOME}/projects/minimaleffort/.gitconfig)"
    ${MV} --backup=numbered  gitconfig/.minimaleffort-gitconfig ${HOME}/projects/minimaleffort/.gitconfig &>/dev/null

    print_info "Copied $(style_path gitconfig/private-git) to $(style_path ${HOME}/.ssh/private-git)"
    ${MV} --backup=numbered gitconfig/private-git ${HOME}/.ssh/ &>/dev/null

    print_info "Copied $(style_path gitconfig/minimaleffort) to $(style_path ${HOME}/.ssh/minimaleffort)"
    ${MV} --backup=numbered gitconfig/minimaleffort ${HOME}/.ssh/ &>/dev/null

    rm -rf gitconfig
    if [ $? -ne 0 ]; then
        print_warn "Failed To Remove Decrypted And Decompressed gitconfig/. You May Want To Manually Remove It"
    fi

    print_info "$(emphasize_text Starting ssh-agent And Adding Keys)"
    eval $(ssh-agent -s) &>/dev/null

    print_info "Adding $(style_path ~/.ssh/minimaleffort/minimaleffort.key) to ssh-agent"
    ssh-add ~/.ssh/minimaleffort/minimaleffort.key &>/dev/null

    print_info "Adding $(style_path ~/.ssh/private-git/private-git.key) to ssh-agent"
    ssh-add ~/.ssh/private-git/private-git.key &>/dev/null

    ###########################################################################
    #                                                                         #
    #                      Installing Neovim Plugins                          #
    #                                                                         #
    ###########################################################################

    print_info "$(emphasize_text Installing Neovim Plugins)"
    nvim --headless +PlugInstall +q +q &>/dev/null
    if [ $? -ne 0 ]; then
        print_warn "Failed To Install $(highlight_text Neovim Plugins)"
    else
        print_info "Installed $(highlight_text Neovim Plugins)"
    fi

    ###########################################################################
    #                                                                         #
    #          Converting DOTFILES repo To Use SSH Instead Of HTTPS           #
    #                                                                         #
    ###########################################################################

    print_info "$(emphasize_text Switching dotfiles repo from https to ssh)"
    git config --local remote.origin.url git@github.com:MinimalEffort07/dotfiles.git
    print_info "Edited dotfile repo's $(highlight_text gitconfig)."

    ###########################################################################
    #                                                                         #
    #                     Setting Up Screen Resolution                        #
    #                                                                         #
    ###########################################################################

    if [ ! -f ~/.xrandr_preferences.sh ]; then
        print_info "$(emphasize_text Creating xrandr preferences)"

        xrandr_output=$(xrandr | grep -Eo "^.* connected" | cut -d' ' -f1)
        xrandr | grep -Eo "^ *[0-9]+x[0-9]+" | head -n 15
        print_info "Choose a resolution from list above:"

        read
        echo -e "#!/bin/zsh\nxrandr --output ${xrandr_output} --mode ${REPLY}" > ~/.xrandr_preferences.sh
        print_info "Created $(style_path ~/.xrandr_preferences) to be run at login"
    fi

    ###########################################################################
    #                                                                         #
    #                    Remapping Caps Lock To Control                       #
    #                                                                         #
    ###########################################################################

    print_info "$(emphasize_text Changing Caps_Lock to Control)"
    if grep XKBOPTIONS=\"\" /etc/default/keyboard &>/dev/null; then
        sudo sed -i s/XKBOPTIONS=\"/XKBOPTIONS=\"ctrl:nocaps/g /etc/default/keyboard
        print_info "Edited $(style_path /etc/default/keyboard)'s XKBOPTIONS and added option $(highlight_text ctrl:nocaps), restart to take effect"
    fi
}

main
