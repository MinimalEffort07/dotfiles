#!/bin/bash
#
# Install and setup packages and configuration files
# Author: Emmanuel Christianos

CYAN="\x1b\x5b1m\x1b\x5b36m"
RED="\x1b\x5b1m\x1b\x5b31m"
GREEN="\x1b\x5b1m\x1b\x5b32m"
YELLOW="\x1b\x5b1m\x1b\x5b33m"
GRAY="\x1b\x5b1m\x1b\x5b37m"
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
    echo -e "[${GREEN}SECTION${RES}] $@"
}

function style_path() {
    echo -e "${GREEN}$@${RES}"
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

function custom_command() {

    arr=("$@")
    for custom_command in "$@"; do
        echo $custom_command
        print_info "Attempting to run ${custom_command}"
        if $custom_command; then
            print_info "Custom command succeeded"
        else
            print_err "Custom command failed. Aborting"
        fi
    done
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

        if $ADMIN test -d "/opt/${repo_name}"; then
            print_warn "${repo_name} already exists"
        else
            print_info "Attempting to clone ${repo_name} into /opt/${repo_name}"
            if $ADMIN git clone -q $repo_url "/opt/${repo_name}"; then
                print_info "Successfully cloned ${repo_name}"

                print_info "Attempting to chown /opt/${repo_name} to $USER ownership"
                if $ADMIN chown -R $USER:$USER "/opt/${repo_name}"; then
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

        if $ADMIN test -f "${symarr[1]}"j; then

            print_info "$(style_path ${symarr[1]}) already exists but is not a symlink. "\
                       "Attempting to back it up now"
                                   
            # Existing File, back it up
            if $ADMIN test -f ".${symarr[1]}.dotfiles.bak"; then
                print_info "Found existing backup. Attempting to delete it."
                if rm ".${symarr[1]}.dotfiles.bak"; then
                    print_info "Deleted existing backup"
                elif $ADMIN rm ".${symarr[1]}.dotfiles.bak 2>/dev/null"; then
                    print_warn "Deleted existing backup. Required sudo"
                else 
                    print_warn "Failed to delete existing backup. "\
                               "Not serious issue, you may want to manually "\
                               "delete the backup $(style_path .${symarr[1]}.dotfiles.bak)"
                fi
            fi
            
            # Attempting backup
            if mv "${symarr[1]}" ".${symarr[1]}.dotfiles.bak"; then 
                print_info "$(style_path ${symarr[1]}) Successfully backed up to "\
                           "${symarr[1]}.dotfiles.back"
            elif $ADMIN mv "${symarr[1]}" ".${symarr[1]}.dotfiles.bak" 2>/dev/null; then
                print_warn "${symarr[1]} Successfully backed up to "\
                           "${symarr[1]}.dotfiles.back. Required sudo"
            else
                print_err "Unable to backup ${symarr[1]}"
                exit 1
            fi
        fi
        
        # Attempting to remove existing destination file
        if $ADMIN test -e "${symarr[1]}"; then
            print_info "Attempting to remove old ${symarr[1]}"
            if rm "${symarr[1]}" 2>/dev/null; then
                print_info "Successfully removed ${symarr[1]}"
            elif $ADMIN rm "${symarr[1]}" 2>/dev/null; then
                print_warn "Successfully removed ${symarr[1]}. Required sudo"
            else
                print_err "Failed to removed ${symarr[1]}"
            fi
        fi

        print_info "Attempting to create symlink ${symarr[1]} -> ${symarr[0]}"

        if ln -s "${symarr[0]}" "${symarr[1]}" 2>/dev/null; then
            print_info "Successfully created symlink"
        elif $ADMIN ln -s "${symarr[0]}" "${symarr[1]}" 2>/dev/null; then
            print_warn "Successfully created symlink. Required sudo"
        else 
            print_err "Failed to create symlink"
        fi
    done
}

# Given a list of directories create them.
function create_dirs() {
    arr=("$@")

    for dir in ${arr[@]}; do

        if $ADMIN test -d "${dir}"; then
            print_info "${dir} already exists"
        else
            print_info "Attempting to create ${dir}"

            if mkdir -p "${dir}"; then
                print_info "Created ${dir}"
            elif $ADMIN mkdir -p "${dir}" 2>/dev/null; then
                print_warn "Created ${dir}.. Required sudo"
            else
                print_info "Unable to create ${dir}.."
            fi
        fi
    done
}

# Given a dependency name, check if it is installed on the system
function check_installed() {

    if test -n "$(${PCKMAN} list 2>/dev/null) | grep "$1")"; then
        return 0
    else
        if test -n "$(which $1)"; then
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
        if $ADMIN$PCKMAN install $OPTIONS ${dep} 2>/dev/null; then
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

    dotfiles_bannner

    print_section "Determining OS"

    if test "$(uname)" = "Darwin"; then 
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

    if test "$OS" = "Darwin" && -z "$(which  brew)"; then
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

    if test "$OS" = "Darwin"; then
        install_deps ${deps_mac_only[@]}
    else
        install_deps ${deps_linux_only[@]}
    fi

    print_section "Creating Directories"

    local dirs_mac_only=()
    local dirs_linux_only=("/root/.config/nvim/" "${HOME}/.config/i3")
    local dirs_agnostic=("${HOME}/.config/nvim")

    create_dirs ${dirs_agnostic[@]}

    if test "$OS" = "Darwin"; then
        create_dirs "${dirs_mac_only[@]}"
    else
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
    create_syms "${syms_agnostic[@]}"

    if test "$OS" = "Darwin"; then
        create_syms "${syms_mac_only[@]}"
    else
        create_syms "${syms_linux_only[@]}"
    fi

    # Installing Github Repos to be installed in /opt
    print_section "Cloning Repositories"
    local repos_mac_only=()
    local repos_linux_only=()
    local repos_agnostic=("https://github.com/pwndbg/pwndbg.git")

    clone_repos "${repos_agnostic[@]}"

    if test "$OS" = "Darwin"; then
        clone_repos "${repos_mac_only[@]}"
    else
        clone_repos "${repos_linux_only[@]}"
    fi

    print_section "Executing Custom Commands"

    local custom_com_mac_only=()
    local custom_com_linux_only=()
    local custom_com_agnostic=("ls")

    custom_command "${custom_com_agnostic[@]}"

    if test "$OS" = "Darwin"; then
        custom_command "${custom_com_mac_only[@]}"
    else
        custom_command "${custom_com_linux_only[@]}"
    fi
}

main
