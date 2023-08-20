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
    sed s@${HOME}@~@g <<< "$1"
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
            print_warn "$(highlight_text ${repo_name}) already exists. Skipping"
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
                           "$(style_path ${symarr[1]}.dotfiles.back)"
            elif sudo mv "${symarr[1]}" "${symarr[1]}.dotfiles.bak" &>/dev/null; then
                print_warn "....$(style_path ${symarr[1]}) Successfully backed up to"\
                           "$(style_path ${symarr[1]}.dotfiles.back). Required sudo"
            else
                print_warn "....Unable to backup $(syle_path ${symarr[1]})"
            fi
        fi
        
        # Attempting to remove existing destination file
        if sudo test -e ${symarr[1]}; then
            print_info "....Attempting to remove old $(style_path ${symarr[1]})"
            if rm "${symarr[1]}" &>/dev/null; then
                print_info "....Successfully removed $(style_path ${symarr[1]})"
            elif sudo rm "${symarr[1]}" &>/dev/null; then
                print_warn "....Successfully removed "\
                           "$(style_path ${symarr[1]}). Required sudo"
            else
                print_err "....Failed to removed $(style_path ${symarr[1]})"
            fi
        fi

        if ln -s "${symarr[0]}" "${symarr[1]}" &>/dev/null; then
            print_info "....Successfully created symlink"
        elif sudo ln -s "${symarr[0]}" "${symarr[1]}" &>/dev/null; then
            print_warn "....Successfully created symlink. Required sudo"
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
            print_warn "$(style_path ${dir}) already exists. Skipping.."
        else
            print_info "Attempting to create $(style_path ${dir})"

            if mkdir -p "${dir}"; then
                print_info "Created $(style_path ${dir})"
            elif sudo mkdir -p "${dir}" &>/dev/null; then
                print_warn "Created $(style_path ${dir}).. Required sudo"
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
        if $PCKMAN list 2>/dev/null | grep $1 &>/dev/null; then
            return 0
        else
            return 1
        fi
    fi
}

# Given a list of dependencies, install them using: PCKMAN, OPTIONS
function install_deps() {
    arr=("$@")

    for dep in ${arr[@]}; do
        if check_installed "${dep}"; then
            print_info "$(highlight_text ${dep}) is already installed"
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

function main() {

    dotfiles_bannner

    print_section "Determining OS"

    if test "$(uname)" = "Darwin"; then 
        OS="MacOS"
        PCKMAN="brew"
        if test "$(uname -m)" = "arm64"; then
            ARM="arm64"
        fi
    else
        OS="Linux"
        PCKMAN="sudo apt"
        OPTIONS="-y"
    fi

    print_info "OS is: $(highlight_text ${OS})"
    print_info "Using $(highlight_text ${PCKMAN}) package manager"
    
    # Install Homebrew if on MacOS and It isn't already installed
    # -z True if length of string is 0.

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

    print_section "Installing Dependencies"

    local deps_mac_only=("coreutils" "binutils" "gnu-sed")
    local deps_linux_only=("i3")
    local deps_agnostic=("curl" "zsh" "neovim" "pip")
    
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

    print_section "Executing Custom Commands"
    print_section "Setting up DOTFILES Environment Variable"

    export DOTFILES="$(pwd)"
    print_info "DOTFILES=$(style_path ${DOTFILES})"
    print_info "Attempting to update DOTFILES variable in zshrc"

    if sed -E -i.dotfiles.bak s@DOTFILES=.\*@DOTFILES=\"${DOTFILES}\"@g "${DOTFILES}/zshrc"; then
        print_info "Successfully updated DOTFILES environment variable in zshrc"
    else
        print_err "Failed to updated DOTFILES environment variable in zshrc"
        exit 1
    fi 

    print_section "Creating Directories"

    local dirs_mac_only=()
    local dirs_linux_only=("/root/.config/nvim/" "${HOME}/.config/i3")
    local dirs_agnostic=("${HOME}/.config/nvim")

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

    print_section "Creating Symlinks"

    local syms_mac_only=()
    local syms_linux_only=("${DOTFILES}/init.vim /root/.config/nvim/init.vim"
                           "${DOTFILES}/i3_config ${HOME}/.config/i3/config")

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

}

main
