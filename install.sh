#!/bin/bash
#
# Install and setup packages and configuration files
# Author: Emmanuel Christianos

CYAN="\x1b\x5b1m\x1b\x5b36m"
RED="\x1b\x5b1m\x1b\x5b31m"
GREEN="\x1b\x5b1m\x1b\x5b32m"
YELLOW="\x1b\x5b1m\x1b\x5b33m"
RES="\x1b\x5b0m"

print_info() {
    echo -e "[${CYAN}INFO${RES}] $@"
}

print_warn() {
    echo -e "[${YELLOW}WARN${RES}] $@"
}

print_err() {
    echo -e "[${RED}ERROR${RES}] $@"
}

print_section() {
    echo -e "[${GREEN}SECTION${RES}] $@"
}




echo -e "
       ██╗██████╗  ██████╗ ████████╗███████╗██╗██╗     ███████╗███████╗
      ██╔╝██╔══██╗██╔═══██╗╚══██╔══╝██╔════╝██║██║     ██╔════╝██╔════╝
     ██╔╝ ██║  ██║██║   ██║   ██║   █████╗  ██║██║     █████╗  ███████╗
    ██╔╝  ██║  ██║██║   ██║   ██║   ██╔══╝  ██║██║     ██╔══╝  ╚════██║
██╗██╔╝   ██████╔╝╚██████╔╝   ██║   ██║     ██║███████╗███████╗███████║
╚═╝╚═╝    ╚═════╝  ╚═════╝    ╚═╝   ╚═╝     ╚═╝╚══════╝╚══════╝╚══════╝\x0a"

# Given a dependency name, check if it is installed on the system
function check_installed() {

    if [[ -n "$(${PCKMAN} list) | grep "$1")" ]]; then
        return 0
    else
        if [[ -n "$(which $1)" ]]; then
            return 0
        else
            return 1
        fi
    fi
}

# Given a list of dependencies, install them using: PCKMAN, OPTIONS, ADMIN and CHECK
function install_deps() {
    arr=("$@")

    for dep in ${arr[@]}; do
        if check_installed "${dep}"; then
            print_info "${dep} is already installed"
            continue
        fi 
        print_info "Attempting to install ${dep}"
        if $ADMIN$PCKMAN install $OPTIONS ${dep}; then
            print_info "Successfully installed ${dep}"
        else
            if check_installed "${dep}"; then
                print_warn "Non terminal issue encountered while installing ${dep}" \
                            ", it was still abled to be installed"
            else
                print_err "Failed to install ${dep}, check the output. Exiting.."
            fi
        fi
    done
}

function main() {
    print_section "Determining OS"

    if [[ $(uname) -eq "Darwin" ]]; then 
        OS="MacOS"
        PCKMAN="brew"
    else
        OS="Linux"
        PCKMAN="apt"
        OPTIONS="-y"
        ADMIN="sudo"
    fi

    print_info "OS is: ${OS}"
    print_info "Using ${PCKMAN} package manager"

    print_section "Setting up DOTFILES Environment Variable"
export DOTFILES="$(pwd)"
    print_info "DOTFILES=${DOTFILES}"
    print_info "Attempting to update DOTFILES variable in zshrc"

    if sed -E -i.dotfiles.bak s@DOTFILES=.\*@DOTFILES=\"${DOTFILES}\"@g zshrc; then
        print_info "Successfully updated DOTFILES environment variable in zshrc"
    else
        print_err "Failed to updated DOTFILES environment variable in zshrc"
        exit 1
    fi 


    # Install Homebrew if on MacOS and It isn't already installed
    # -z True if length of string is 0.

    if [[ "$OS" -eq "Darwin" && -z "$(which  brew)" ]]; then
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

    local deps_mac_only=("coreutils")
    local deps_linux_only=("i3")
    local deps_agnostic=("curl" "zsh" "neovim" "pip")
    
    install_deps ${deps_agnostic[@]}

    if [[ "$OS" -eq "Darwin" ]]; then
        install_deps ${deps_mac_only[@]}
    else
        install_deps ${deps_linux_only[@]}
    fi

    local dirs_mac_only=("")
    local dirs_linux_only=("/root/.config/nvim/" "" )
    local dirs_agnostic=("curl" "zsh" "neovim" "pip")
}



main
