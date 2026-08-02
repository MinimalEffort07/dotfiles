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

set -u

# Defaults for variables that are only set on some platforms or by flags.
# Required because of set -u.
OPTIONS=""
ARM=""
HEADLESS=0

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
            if sudo git clone -q "$repo_url" "/opt/${repo_name}"; then
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

    for sym in "$@"; do
        symarr=($sym)

        print_info "Attempting to create symlink,"\
            "$(style_path ${symarr[1]}) $(style_path '->') $(style_path ${symarr[0]})"

        if sudo [ -e "${symarr[1]}" ] && sudo [ ! -L "${symarr[1]}" ]; then

            print_warn "....$(style_path ${symarr[1]}) already exists but is"\
                       "not a symlink. Attempting to back it up now"

            # Numbered backups so repeated runs never overwrite an earlier backup
            if ${MV} --backup=numbered "${symarr[1]}" "${symarr[1]}.dotfiles.bak" &>/dev/null; then
                print_info "....$(style_path ${symarr[1]}) Successfully backed up to"\
                           "$(style_path ${symarr[1]}.dotfiles.bak)"
            elif sudo ${MV} --backup=numbered "${symarr[1]}" "${symarr[1]}.dotfiles.bak" &>/dev/null; then
                print_warn "....$(style_path ${symarr[1]}) Successfully backed up to"\
                    "$(style_path ${symarr[1]}.dotfiles.bak). $(highlight_text Required sudo)"
            else
                # Never delete a file that could not be backed up
                print_err "....Unable to backup $(style_path ${symarr[1]}). $(emphasize_text Aborting..)"
                exit 1
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
                print_err "....Failed to remove $(style_path ${symarr[1]}). $(emphasize_text Aborting..)"
                exit 1
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

    for dir in "$@"; do

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

    for dep in "$@"; do
        if check_installed "${dep}"; then
            print_info "$(highlight_text ${dep}) is already installed. $(highlight_text Skipping..)"
            continue
        fi
        print_info "Attempting to install ${dep}"
        if $PCKMAN install $OPTIONS "${dep}" &>/dev/null; then
            print_info "Successfully installed $(highlight_text ${dep})"
        else
            if check_installed "${dep}"; then
                print_warn "Non terminal issue encountered while installing"\
                           "$(highlight_text ${dep}), it was still abled to be"\
                           " installed"
            else
                print_err "Failed to install $(highlight_text ${dep}), check "\
                          "the output. Exiting.."
                exit 1
            fi
        fi
    done
}

function uninstall_conflicts() {

    for conflict in "$@"; do
        if ! check_installed "${conflict}"; then
            print_info "$(highlight_text ${conflict}) is not installed. $(highlight_text Skipping..)"
            continue
        fi

        print_info "Attempting to uninstall ${conflict}"

        if $PCKMAN remove $OPTIONS "${conflict}" &>/dev/null; then
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

# Point the given command names at nvim using the alternatives system
function setup_editor_alternatives() {

    local nvim_path="$(which nvim)"

    if [ -z "${nvim_path}" ]; then
        print_warn "nvim not found, unable to set up editor alternatives"
        return 1
    fi

    for name in "$@"; do
        print_info "Attempting to point $(highlight_text ${name}) at $(style_path ${nvim_path})"

        if sudo update-alternatives --install "/usr/bin/${name}" "${name}" "${nvim_path}" 60 &>/dev/null &&
           sudo update-alternatives --set "${name}" "${nvim_path}" &>/dev/null; then
            print_info "....Successfully pointed $(highlight_text ${name}) at nvim"
        else
            print_warn "....Failed to point $(highlight_text ${name}) at nvim"
        fi
    done
}

# Copy the array named $1 into the array named $2. Namerefs (local -n) need
# bash 4.3+ but macOS ships bash 3.2, so indirection is done with eval. The
# ${...+...} guard keeps set -u happy when the source array is empty.
function copy_array() {
    eval "$2=(\${$1[@]+\"\${$1[@]}\"})"
}

# Dispatch a step over the platform agnostic array and the array matching the
# current OS. Takes a verb ("Installing"), a noun ("Dependencies"), a function
# name and the NAMES of the mac only, linux only and agnostic arrays.
function run_platform_step() {

    local verb="$1"
    local noun="$2"
    local func="$3"
    local mac_arr linux_arr agnostic_arr
    copy_array "$4" mac_arr
    copy_array "$5" linux_arr
    copy_array "$6" agnostic_arr

    if [ ${#agnostic_arr[@]} -gt 0 ]; then
        print_info "$(emphasize_text ${verb} Platform Agnostic ${noun})"
        "${func}" "${agnostic_arr[@]}"
    fi

    if [ "$OS" = "MacOS" ] && [ ${#mac_arr[@]} -gt 0 ]; then
        print_info "$(emphasize_text ${verb} Mac Only ${noun})"
        "${func}" "${mac_arr[@]}"
    elif [ "$OS" = "Linux" ] && [ ${#linux_arr[@]} -gt 0 ]; then
        print_info "$(emphasize_text ${verb} Linux Only ${noun})"
        "${func}" "${linux_arr[@]}"
    fi
}

# Dispatch a step over a linux desktop only array, skipping it entirely when
# running with --headless. Takes a verb, a noun, a function name and the NAME
# of the desktop only array.
function run_desktop_step() {

    local verb="$1"
    local noun="$2"
    local func="$3"
    local desktop_arr
    copy_array "$4" desktop_arr

    if [ "$OS" != "Linux" ] || [ ${#desktop_arr[@]} -eq 0 ]; then
        return 0
    fi

    if [ "${HEADLESS}" -eq 1 ]; then
        print_info "Skipping (headless) $(emphasize_text Linux Desktop Only ${noun})"
    else
        print_info "$(emphasize_text ${verb} Linux Desktop Only ${noun})"
        "${func}" "${desktop_arr[@]}"
    fi
}

function main() {

    ###########################################################################
    #                                                                         #
    #                        Parsing Script Arguments                         #
    #                                                                         #
    ###########################################################################

    for arg in "$@"; do
        case "${arg}" in
            --headless)
                HEADLESS=1
                ;;
            *)
                print_err "Unknown argument: $(highlight_text ${arg})"
                echo "Usage: $0 [--headless]"
                exit 1
                ;;
        esac
    done

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
            print_info "Successfully installed Homebrew"
        else
            print_err "Failed to install Homebrew.. Exiting"
            exit 1
        fi
    fi

    ###########################################################################
    #                                                                         #
    #              Uninstalling Conflicting Software Packages                 #
    #                                                                         #
    ###########################################################################

    print_section "Uninstalling Conflicts"

    local conflicts_mac_only=("vim")
    local conflicts_linux_only=()
    local conflicts_agnostic=()

    run_platform_step "Uninstalling" "Conflicts" uninstall_conflicts \
        conflicts_mac_only conflicts_linux_only conflicts_agnostic

    ###########################################################################
    #                                                                         #
    #                   Installing Software Dependencies                      #
    #                                                                         #
    ###########################################################################

    print_section "Installing Dependencies"

    local deps_mac_only=("coreutils" "binutils" "gnu-sed" "go" "python")
    local deps_linux_only=("python3-pip" "golang")
    local deps_linux_desktop=("i3" "rofi")
    local deps_agnostic=("curl" "zsh" "neovim" "gpg" "tar")

    run_platform_step "Installing" "Dependencies" install_deps \
        deps_mac_only deps_linux_only deps_agnostic

    run_desktop_step "Installing" "Dependencies" install_deps deps_linux_desktop

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

    run_platform_step "Cloning" "Repositories" clone_repos \
        repos_mac_only repos_linux_only repos_agnostic

    if [ "$OS" = "MacOS" ]; then
        if [ -n "$ARM" ] && [ ${#repos_arm_only[@]} -gt 0 ]; then
            print_info "$(emphasize_text Cloning ARM Mac Only Repositories)"
            clone_repos "${repos_arm_only[@]}"
        elif [ -z "$ARM" ] && [ ${#repos_intel_only[@]} -gt 0 ]; then
            print_info "$(emphasize_text Cloning Intel Mac Only Repositories)"
            clone_repos "${repos_intel_only[@]}"
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
    local dirs_linux_only=()
    local dirs_linux_desktop=("${HOME}/.config/i3"
                              "/etc/i3"
                              "${HOME}/.config/rofi")

    local dirs_agnostic=("${HOME}/projects/minimaleffort")

    run_platform_step "Creating" "Directories" create_dirs \
        dirs_mac_only dirs_linux_only dirs_agnostic

    run_desktop_step "Creating" "Directories" create_dirs dirs_linux_desktop

    ###########################################################################
    #                                                                         #
    #                Creating Symlinks To Configuration Files                 #
    #                                                                         #
    ###########################################################################

    print_section "Creating Symlinks"

    # Each entry is a space separated "source destination" pair, split inside
    # create_syms. Double quotes here prevent premature splitting.
    local syms_mac_only=("/usr/local/bin/nvim /usr/local/bin/vim")
    local syms_linux_only=("${DOTFILES}/nvim ${HOME}/.config/nvim")
    local syms_linux_desktop=("${DOTFILES}/i3_config ${HOME}/.config/i3/config"
                              "${DOTFILES}/i3_config /etc/i3/config"
                              "${DOTFILES}/config.rasi ${HOME}/.config/rofi/config.rasi"
                              "${DOTFILES}/xmodmapmappings ${HOME}/.config/i3/xmodmapmappings")

    local syms_agnostic=("${DOTFILES}/zshrc ${HOME}/.zshrc"
                         "${DOTFILES}/gdbinit ${HOME}/.gdbinit")

    run_platform_step "Creating" "Symlinks" create_syms \
        syms_mac_only syms_linux_only syms_agnostic

    run_desktop_step "Creating" "Symlinks" create_syms syms_linux_desktop

    print_section "Executing Custom Commands"

    ###########################################################################
    #                                                                         #
    #                     Setting Up Editor Alternatives                      #
    #                                                                         #
    ###########################################################################

    if [ "$OS" = "Linux" ]; then
        print_info "$(emphasize_text Pointing v, vi and vim at nvim via update-alternatives)"
        setup_editor_alternatives v vi vim
    fi

    ###########################################################################
    #                                                                         #
    #                    Copying Nvim Config For Root User                    #
    #                                                                         #
    ###########################################################################

    if [ "$OS" = "Linux" ]; then
        print_info "$(emphasize_text Copying nvim config to $(style_path /root/.config/nvim))"

        if ! sudo mkdir -p /root/.config &>/dev/null; then
            print_warn "Failed to create $(style_path /root/.config), skipping root nvim config"
        elif which rsync &>/dev/null; then
            if sudo rsync -a --delete "${DOTFILES}/nvim/" /root/.config/nvim/ &>/dev/null; then
                print_info "Successfully copied nvim config for root"
            else
                print_warn "Failed to copy nvim config for root"
            fi
        else
            if sudo cp -rT "${DOTFILES}/nvim" /root/.config/nvim &>/dev/null; then
                print_info "Successfully copied nvim config for root. $(highlight_text rsync unavailable, used cp)"
            else
                print_warn "Failed to copy nvim config for root"
            fi
        fi
    fi

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
    #                     Setting Up Screen Resolution                        #
    #                                                                         #
    ###########################################################################

    if [ "$OS" != "Linux" ]; then
        : # xrandr preferences are a linux desktop concern only
    elif [ "${HEADLESS}" -eq 1 ]; then
        print_info "Skipping (headless) $(emphasize_text xrandr preferences)"
    elif [ ! -f ~/.xrandr_preferences.sh ]; then
        print_info "$(emphasize_text Creating xrandr preferences)"

        xrandr_output="$(xrandr --query 2>/dev/null | awk '/ connected/ {print $1; exit}')"
        if [ -n "${xrandr_output}" ]; then
            echo -e "#!/bin/zsh\nxrandr --output ${xrandr_output} --auto" > ~/.xrandr_preferences.sh
        else
            print_warn "Failed To Detect Primary $(highlight_text xrandr) Output. Falling Back To $(highlight_text xrandr --auto)"
            echo -e "#!/bin/zsh\nxrandr --auto" > ~/.xrandr_preferences.sh
        fi
        print_info "Created $(style_path ~/.xrandr_preferences) to be run at login"
        chmod +x ~/.xrandr_preferences.sh
        if ! ~/.xrandr_preferences.sh; then
            print_warn "Failed to apply $(highlight_text xrandr) preferences"
        fi
    fi

    ###########################################################################
    #                                                                         #
    #                    Remapping Caps Lock To Control                       #
    #                                                                         #
    ###########################################################################

    if [ "$OS" != "Linux" ]; then
        : # /etc/default/keyboard is a linux desktop concern only
    elif [ "${HEADLESS}" -eq 1 ]; then
        print_info "Skipping (headless) $(emphasize_text Caps_Lock remap)"
    else
        print_info "$(emphasize_text Changing Caps_Lock to Control)"
        if grep XKBOPTIONS=\"\" /etc/default/keyboard &>/dev/null; then
            if sudo sed -i s/XKBOPTIONS=\"/XKBOPTIONS=\"ctrl:nocaps/g /etc/default/keyboard; then
                print_info "Edited $(style_path /etc/default/keyboard)'s XKBOPTIONS and added option $(highlight_text ctrl:nocaps), restart to take effect"
            else
                print_warn "Failed to edit $(style_path /etc/default/keyboard)'s XKBOPTIONS"
            fi
        fi
    fi

    ###########################################################################
    #                                                                         #
    #                     Changing Default Shell To Zsh                       #
    #                                                                         #
    ###########################################################################

    print_info "$(emphasize_text Changing Default Shell To Zsh)"
    if chsh -s "$(which zsh)"; then
        print_info "Successfully changed default shell to $(highlight_text zsh)"
    else
        print_err "Failed to change default shell to $(highlight_text zsh). Aborting"
        exit 1
    fi

}

main "$@"
