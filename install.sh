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
MODE="install"

# Identity applied to the global git config, taken from this repository's commit
# history so a fresh machine commits under the same name as every other one.
GIT_NAME="MinimalEffort07"
GIT_EMAIL="90430937+MinimalEffort07@users.noreply.github.com"

# The remote of this repository that is switched from HTTPS to SSH on install
# and back again on clean.
GIT_REMOTE="origin"

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

# The login shell recorded for the user. Deliberately not $SHELL, which is
# inherited from whatever started this process and so still reports the old
# shell for the rest of the session after chsh has run.
function login_shell() {

    # id rather than $USER, which is not guaranteed to be exported and would
    # take the whole script down under set -u
    local user="$(id -un)"

    if command -v getent &>/dev/null; then
        getent passwd "${user}" | cut -d: -f7
    elif command -v dscl &>/dev/null; then
        dscl . -read "/Users/${user}" UserShell 2>/dev/null | awk '{ print $2 }'
    else
        echo "${SHELL:-}"
    fi
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

        # Already pointing where we want it. Left alone rather than recreated
        # so a re-run cannot lose the destination in the window between the rm
        # and the ln below
        if sudo test -h "${symarr[1]}" &&
           [ "$(sudo readlink "${symarr[1]}")" = "${symarr[0]}" ]; then
            print_info "....Symlink already exists. $(highlight_text Skipping..)"
            continue
        fi

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

# Put back whatever create_syms displaced. It backs a real file up with
# --backup=numbered, which renames any previous backup out to .~N~ and leaves
# the most recent one under the plain .dotfiles.bak name, so that is the one to
# restore. Earlier backups are left where they are rather than guessed at.
function restore_backup() {

    local dst="$1"
    local bak="${dst}.dotfiles.bak"

    sudo test -e "${bak}" || return 0

    if sudo test -e "${dst}"; then
        print_warn "....$(style_path ${dst}) still exists, refusing to overwrite"\
                   "it with $(style_path ${bak})"
        return 0
    fi

    print_info "....Attempting to restore $(style_path ${bak})"

    if ${MV} "${bak}" "${dst}" &>/dev/null; then
        print_info "....Successfully restored $(style_path ${dst})"
    elif sudo ${MV} "${bak}" "${dst}" &>/dev/null; then
        print_warn "....Successfully restored $(style_path ${dst}). $(highlight_text Required sudo)"
    else
        print_warn "....Failed to restore $(style_path ${bak})"
    fi
}

# Undo create_syms, taking the same "source destination" pairs. A destination
# is only removed when it is still a symlink to the source we gave it, so a
# link the user has since repointed, or a real file that replaced it, is left
# untouched.
function remove_syms() {

    for sym in "$@"; do
        symarr=($sym)

        if sudo test -h "${symarr[1]}"; then

            local target="$(sudo readlink "${symarr[1]}")"

            if [ "${target}" != "${symarr[0]}" ]; then
                print_warn "$(style_path ${symarr[1]}) points at $(style_path ${target}),"\
                           "not $(style_path ${symarr[0]}). $(highlight_text Skipping..)"
                continue
            fi

            print_info "Attempting to remove symlink $(style_path ${symarr[1]})"

            if rm "${symarr[1]}" &>/dev/null; then
                print_info "....Successfully removed $(style_path ${symarr[1]})"
            elif sudo rm "${symarr[1]}" &>/dev/null; then
                print_warn "....Successfully removed $(style_path ${symarr[1]}). $(highlight_text Required sudo)"
            else
                print_err "....Failed to remove $(style_path ${symarr[1]})"
                continue
            fi

        elif sudo test -e "${symarr[1]}"; then
            print_warn "$(style_path ${symarr[1]}) is not a symlink. $(highlight_text Skipping..)"
            continue
        else
            print_info "$(style_path ${symarr[1]}) does not exist. $(highlight_text Skipping..)"
        fi

        restore_backup "${symarr[1]}"
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

# Undo create_dirs. Only empty directories go, anything the user has since put
# in one is theirs to keep, and rmdir refusing is exactly that signal.
function remove_dirs() {

    for dir in "$@"; do

        if ! sudo test -d "${dir}"; then
            print_info "$(style_path ${dir}) does not exist. $(highlight_text Skipping..)"
            continue
        fi

        print_info "Attempting to remove $(style_path ${dir})"

        if rmdir "${dir}" &>/dev/null; then
            print_info "....Successfully removed $(style_path ${dir})"
        elif sudo rmdir "${dir}" &>/dev/null; then
            print_warn "....Successfully removed $(style_path ${dir}). $(highlight_text Required sudo)"
        else
            print_warn "....$(style_path ${dir}) is not empty. $(highlight_text Skipping..)"
        fi
    done
}

# True when the package manager reports the package $1 as installed. This is
# the only honest check for conflicts: a command sitting on PATH says nothing
# about whether the package manager can remove it.
function check_pkg_installed() {

    if [ "${PCKMAN}" = "brew" ]; then
        $PCKMAN list -1 2>/dev/null | grep -qE "^$1$"
    else
        $PCKMAN list --installed 2>/dev/null | grep -qE "^$1/"
    fi
}

# True when a dependency is already satisfied, by the package manager or by the
# command simply being on PATH.
#
# Entries may be written as "package:command" for the cases where the two names
# differ, since the package name is not usable as a command (the neovim package
# ships nvim, python3-pip ships pip3). That also lets a hand installed binary
# count as satisfying the dependency, so a tarball nvim in /usr/local/bin is
# not quietly shadowed by the distro one. A bare entry uses one name for both.
function check_installed() {

    local pkg="${1%%:*}"
    local cmd="${1#*:}"

    command -v "${cmd}" &>/dev/null || check_pkg_installed "${pkg}"
}

# Given a list of dependencies, install them using: PCKMAN, OPTIONS
function install_deps() {

    for dep in "$@"; do
        # Entries may be "package:command", only the package half is installable
        local pkg="${dep%%:*}"

        if check_installed "${dep}"; then
            print_info "$(highlight_text ${pkg}) is already installed. $(highlight_text Skipping..)"
            continue
        fi
        print_info "Attempting to install ${pkg}"
        if $PCKMAN install $OPTIONS "${pkg}" &>/dev/null; then
            print_info "Successfully installed $(highlight_text ${pkg})"
        else
            if check_installed "${dep}"; then
                print_warn "Non terminal issue encountered while installing"\
                           "$(highlight_text ${pkg}), it was still abled to be"\
                           " installed"
            else
                print_err "Failed to install $(highlight_text ${pkg}), check "\
                          "the output. Exiting.."
                exit 1
            fi
        fi
    done
}

function uninstall_conflicts() {

    for conflict in "$@"; do
        # Deliberately a package check and not check_installed: /usr/bin/vim
        # exists as an alternatives symlink to nvim, so a command check would
        # claim the vim package is present and then abort when the package
        # manager, rightly, refuses to remove something it never installed.
        local pkg="${conflict%%:*}"

        if ! check_pkg_installed "${pkg}"; then
            print_info "$(highlight_text ${pkg}) is not installed. $(highlight_text Skipping..)"
            continue
        fi

        print_info "Attempting to uninstall ${pkg}"

        if $PCKMAN remove $OPTIONS "${pkg}" &>/dev/null; then
            print_info "Successfully removed $(highlight_text ${pkg})"
        else
            if check_pkg_installed "${pkg}"; then
                print_err "Failed to remove conflict. $(emphasize_text Aborting..)"
                exit 1
            else
                print_warn "Successfully removed $(highlight_text ${pkg}) with warning from ${PCKMAN}"
            fi
        fi
    done
}

# Point the given command names at nvim using the alternatives system.
#
# Alternatives are keyed on the target path, not on who registered them, so a
# registration made against a since removed nvim (the distro package replaced
# by a tarball build, say) survives as a candidate pointing at nothing, and
# removing that package takes our registration with it. Every stale candidate
# is therefore dropped before the current path is installed.
function setup_editor_alternatives() {

    local nvim_path
    nvim_path="$(command -v nvim || true)"

    if [ ! -x "${nvim_path}" ]; then
        print_warn "nvim not found on PATH, unable to set up editor alternatives"
        return 1
    fi

    for name in "$@"; do
        print_info "Attempting to point $(highlight_text ${name}) at $(style_path ${nvim_path})"

        # --query prints one "Alternative: <path>" line per registered
        # candidate. It only reads the admin directory, so it needs no sudo.
        local candidate
        while read -r candidate; do
            [ -x "${candidate}" ] && continue
            print_info "....Dropping stale candidate $(style_path ${candidate})"
            sudo update-alternatives --remove "${name}" "${candidate}" &>/dev/null || true
        done < <(update-alternatives --query "${name}" 2>/dev/null |
                 awk '/^Alternative: /{ print $2 }')

        # Keep stderr, discard stdout, so a failure can say why it failed.
        local err
        if err="$(sudo update-alternatives --install "/usr/bin/${name}" "${name}" "${nvim_path}" 60 2>&1 >/dev/null)" &&
           err="$(sudo update-alternatives --set "${name}" "${nvim_path}" 2>&1 >/dev/null)"; then
            print_info "....Successfully pointed $(highlight_text ${name}) at nvim"
        else
            print_warn "....Failed to point $(highlight_text ${name}) at nvim: ${err}"
        fi
    done
}

# Copy the array named $1 into the array named $2. Namerefs (local -n) need
# bash 4.3+ but macOS ships bash 3.2, so indirection is done with eval. The
# ${...+...} guard keeps set -u happy when the source array is empty.
function copy_array() {
    eval "$2=(\${$1[@]+\"\${$1[@]}\"})"
}

# Undo setup_editor_alternatives by dropping every nvim candidate from the
# named groups. One rule covers both cases: a group the installer invented
# outright (v) loses its only candidate and update-alternatives tears the whole
# group down, link included, while a group the distro also owns (vi, vim) is
# left with the packaged vim to fall back onto.
function remove_editor_alternatives() {

    for name in "$@"; do
        print_info "Attempting to unregister $(highlight_text ${name}) from update-alternatives"

        local candidate found=0
        while read -r candidate; do

            # Match on the binary name, not on a path, so a candidate left by
            # an nvim that has since moved is cleaned up too
            [ "$(basename "${candidate}")" = "nvim" ] || continue
            found=1

            local err
            if err="$(sudo update-alternatives --remove "${name}" "${candidate}" 2>&1 >/dev/null)"; then
                print_info "....Dropped candidate $(style_path ${candidate})"
            else
                print_warn "....Failed to drop candidate $(style_path ${candidate}): ${err}"
            fi

        done < <(update-alternatives --query "${name}" 2>/dev/null |
                 awk '/^Alternative: /{ print $2 }')

        if [ "${found}" -eq 0 ]; then
            print_info "....No nvim candidates registered. $(highlight_text Skipping..)"
        fi

        # A group whose candidates have all gone takes its link with it, but a
        # link left dangling by an nvim removed from under it does not belong
        # to any group any more and has to be unpicked by hand
        if ! update-alternatives --query "${name}" &>/dev/null &&
           [ -L "/usr/bin/${name}" ] && [ ! -e "/usr/bin/${name}" ]; then
            print_info "....Attempting to remove dangling link $(style_path /usr/bin/${name})"
            if sudo rm "/usr/bin/${name}" &>/dev/null; then
                print_info "....Successfully removed $(style_path /usr/bin/${name})"
            else
                print_warn "....Failed to remove $(style_path /usr/bin/${name})"
            fi
        fi
    done
}

# Set one global git config key, leaving a value that is already there alone.
# Overwriting silently would be the wrong call on a machine that also has work
# repositories on it, so a value we did not set is reported and kept.
function set_git_config() {

    local key="$1"
    local value="$2"
    local current

    current="$(git config --global --get "${key}" 2>/dev/null || true)"

    if [ "${current}" = "${value}" ]; then
        print_info "Global $(highlight_text ${key}) is already"\
                   "$(highlight_text ${value}). $(highlight_text Skipping..)"
        return 0
    fi

    if [ -n "${current}" ]; then
        print_warn "Global $(highlight_text ${key}) is already set to"\
                   "$(highlight_text ${current}). $(highlight_text Leaving it alone..)"
        return 0
    fi

    print_info "Attempting to set global $(highlight_text ${key}) to $(highlight_text ${value})"

    if git config --global "${key}" "${value}" &>/dev/null; then
        print_info "....Successfully set $(highlight_text ${key})"
    else
        print_warn "....Failed to set $(highlight_text ${key})"
    fi
}

# Undo set_git_config, but only where the value is still the one we set, so an
# identity changed since installing is left in place.
function unset_git_config() {

    local key="$1"
    local value="$2"
    local current

    current="$(git config --global --get "${key}" 2>/dev/null || true)"

    if [ -z "${current}" ]; then
        print_info "Global $(highlight_text ${key}) is not set. $(highlight_text Skipping..)"
        return 0
    fi

    if [ "${current}" != "${value}" ]; then
        print_warn "Global $(highlight_text ${key}) is $(highlight_text ${current}),"\
                   "not ours. $(highlight_text Skipping..)"
        return 0
    fi

    print_info "Attempting to unset global $(highlight_text ${key})"

    if git config --global --unset "${key}" &>/dev/null; then
        print_info "....Successfully unset $(highlight_text ${key})"
    else
        print_warn "....Failed to unset $(highlight_text ${key})"
    fi
}

# Apply GIT_NAME and GIT_EMAIL to the global git config.
function setup_git_identity() {

    if ! command -v git &>/dev/null; then
        print_warn "git not found on PATH, unable to set up the git identity"
        return 1
    fi

    set_git_config user.name "${GIT_NAME}"
    set_git_config user.email "${GIT_EMAIL}"
}

# Undo setup_git_identity.
function remove_git_identity() {

    if ! command -v git &>/dev/null; then
        print_warn "git not found on PATH, unable to remove the git identity"
        return 1
    fi

    unset_git_config user.name "${GIT_NAME}"
    unset_git_config user.email "${GIT_EMAIL}"
}

# https://host/owner/repo.git -> git@host:owner/repo.git. Echoes the URL
# unchanged when it does not match, so the caller can tell the rewrite failed.
function https_to_ssh_url() {
    sed -E 's|^https://([^/]+)/(.+)$|git@\1:\2|' <<< "$1"
}

# git@host:owner/repo.git -> https://host/owner/repo.git, the inverse of the
# above and subject to the same convention on no match.
function ssh_to_https_url() {
    sed -E 's|^git@([^:]+):(.+)$|https://\1/\2|' <<< "$1"
}

# Echo this repository's GIT_REMOTE URL, or nothing at all when git is missing,
# DOTFILES is not a checkout, or there is no such remote. Every case is reported
# by the caller rather than here, so the two callers can word it themselves.
function remote_url() {

    if ! command -v git &>/dev/null; then
        return 1
    fi

    if ! git -C "${DOTFILES}" rev-parse --is-inside-work-tree &>/dev/null; then
        return 1
    fi

    git -C "${DOTFILES}" remote get-url "${GIT_REMOTE}" 2>/dev/null || return 1
}

# Point GIT_REMOTE at its SSH URL, so pushes from this checkout authenticate
# with the machine's key instead of prompting for a password (or a token) over
# HTTPS. A remote that is already SSH, or that is on neither scheme we know how
# to rewrite, is left alone.
function setup_ssh_remote() {

    local current ssh_url

    if ! current="$(remote_url)"; then
        print_warn "No $(highlight_text ${GIT_REMOTE}) remote found in"\
                   "$(style_path ${DOTFILES}). $(highlight_text Skipping..)"
        return 0
    fi

    case "${current}" in
        git@*|ssh://*)
            print_info "$(highlight_text ${GIT_REMOTE}) is already SSH"\
                       "($(highlight_text ${current})). $(highlight_text Skipping..)"
            return 0
            ;;
        https://*)
            ;;
        *)
            print_warn "$(highlight_text ${GIT_REMOTE}) is $(highlight_text ${current}),"\
                       "which is neither HTTPS nor SSH. $(highlight_text Leaving it alone..)"
            return 0
            ;;
    esac

    ssh_url="$(https_to_ssh_url "${current}")"

    if [ "${ssh_url}" = "${current}" ]; then
        print_warn "Unable to derive an SSH URL from $(highlight_text ${current})."\
                   "$(highlight_text Leaving it alone..)"
        return 0
    fi

    print_info "Attempting to point $(highlight_text ${GIT_REMOTE}) at $(highlight_text ${ssh_url})"

    if git -C "${DOTFILES}" remote set-url "${GIT_REMOTE}" "${ssh_url}" &>/dev/null; then
        print_info "....Successfully switched $(highlight_text ${GIT_REMOTE}) to SSH"
    else
        print_warn "....Failed to switch $(highlight_text ${GIT_REMOTE}) to SSH"
    fi
}

# Undo setup_ssh_remote by putting GIT_REMOTE back on HTTPS. An SSH remote is
# indistinguishable from one the user configured themselves, so unlike the git
# identity this cannot check that the value is ours; it is reversing a rewrite
# that install always makes, and the URL still names the same repository.
function remove_ssh_remote() {

    local current https_url

    if ! current="$(remote_url)"; then
        print_warn "No $(highlight_text ${GIT_REMOTE}) remote found in"\
                   "$(style_path ${DOTFILES}). $(highlight_text Skipping..)"
        return 0
    fi

    if [ "${current#git@}" = "${current}" ]; then
        print_info "$(highlight_text ${GIT_REMOTE}) is $(highlight_text ${current}),"\
                   "not one we rewrote. $(highlight_text Skipping..)"
        return 0
    fi

    https_url="$(ssh_to_https_url "${current}")"

    if [ "${https_url}" = "${current}" ]; then
        print_warn "Unable to derive an HTTPS URL from $(highlight_text ${current})."\
                   "$(highlight_text Leaving it alone..)"
        return 0
    fi

    print_info "Attempting to point $(highlight_text ${GIT_REMOTE}) back at $(highlight_text ${https_url})"

    if git -C "${DOTFILES}" remote set-url "${GIT_REMOTE}" "${https_url}" &>/dev/null; then
        print_info "....Successfully switched $(highlight_text ${GIT_REMOTE}) to HTTPS"
    else
        print_warn "....Failed to switch $(highlight_text ${GIT_REMOTE}) to HTTPS"
    fi
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

# The directories and symlinks the installer owns. Both the install and the
# clean paths read these, so they are declared once here rather than inline,
# otherwise clean drifts out of step with install the first time a config file
# is added. DOTFILES has to be set before this is called.
function declare_file_targets() {

    dirs_mac_only=()
    dirs_linux_only=()
    dirs_linux_desktop=("${HOME}/.config/i3"
                        "/etc/i3"
                        "${HOME}/.config/rofi")

    # ~/.config is where the nvim symlink goes, and a fresh machine that has
    # never run a program which uses it will not have one
    dirs_agnostic=("${HOME}/.config"
                   "${HOME}/projects/minimaleffort")

    # Each entry is a space separated "source destination" pair, split inside
    # create_syms. Double quotes here prevent premature splitting.
    syms_mac_only=("/usr/local/bin/nvim /usr/local/bin/vim")
    syms_linux_only=("${DOTFILES}/nvim ${HOME}/.config/nvim")
    syms_linux_desktop=("${DOTFILES}/i3_config ${HOME}/.config/i3/config"
                        "${DOTFILES}/i3_config /etc/i3/config"
                        "${DOTFILES}/config.rasi ${HOME}/.config/rofi/config.rasi"
                        "${DOTFILES}/xmodmapmappings ${HOME}/.config/i3/xmodmapmappings")

    syms_agnostic=("${DOTFILES}/zshrc ${HOME}/.zshrc"
                   "${DOTFILES}/gdbinit ${HOME}/.gdbinit")
}

# Remove the files and configuration the installer put on the system, in the
# reverse order it created them. Deliberately not undone: installed packages,
# repositories cloned into /opt, and the login shell, all of which are shared
# system state that the user may well want regardless of these dotfiles.
function clean_dotfiles() {

    print_section "Removing Symlinks"

    run_platform_step "Removing" "Symlinks" remove_syms \
        syms_mac_only syms_linux_only syms_agnostic

    run_desktop_step "Removing" "Symlinks" remove_syms syms_linux_desktop

    print_section "Removing Directories"

    run_platform_step "Removing" "Directories" remove_dirs \
        dirs_mac_only dirs_linux_only dirs_agnostic

    run_desktop_step "Removing" "Directories" remove_dirs dirs_linux_desktop

    print_section "Removing Configuration"

    if [ "$OS" = "Linux" ]; then
        print_info "$(emphasize_text Unpointing v, vi and vim from nvim via update-alternatives)"
        remove_editor_alternatives v vi vim

        print_info "$(emphasize_text Removing root nvim config at $(style_path /root/.config/nvim))"
        if ! sudo test -e /root/.config/nvim; then
            print_info "....$(style_path /root/.config/nvim) does not exist. $(highlight_text Skipping..)"
        elif sudo rm -rf /root/.config/nvim &>/dev/null; then
            print_info "....Successfully removed $(style_path /root/.config/nvim)"
        else
            print_warn "....Failed to remove $(style_path /root/.config/nvim)"
        fi
    fi

    print_info "$(emphasize_text Removing the global git identity)"
    remove_git_identity

    print_info "$(emphasize_text Pointing the ${GIT_REMOTE} remote back at HTTPS)"
    remove_ssh_remote

    # The zshrc backup is made by the DOTFILES sed, not by create_syms, so it
    # lives in the repo rather than beside a symlink destination
    remove_files "${DOTFILES}/zshrc.dotfiles.bak" \
                 "${HOME}/.dotfiles_local_config" \
                 "${HOME}/.xrandr_preferences.sh"
}

# Remove the given files if they are present.
function remove_files() {

    for file in "$@"; do

        if [ ! -e "${file}" ]; then
            print_info "$(style_path ${file}) does not exist. $(highlight_text Skipping..)"
            continue
        fi

        print_info "Attempting to remove $(style_path ${file})"

        if rm "${file}" &>/dev/null; then
            print_info "....Successfully removed $(style_path ${file})"
        elif sudo rm "${file}" &>/dev/null; then
            print_warn "....Successfully removed $(style_path ${file}). $(highlight_text Required sudo)"
        else
            print_warn "....Failed to remove $(style_path ${file})"
        fi
    done
}

function usage() {

    echo "Usage: $0 [install|clean] [--headless]"
    echo
    echo "  install    install packages and link configuration (the default)"
    echo "  clean      remove the files and configuration install created,"
    echo "             restoring any backups it took. Leaves installed"
    echo "             packages, /opt repositories and the login shell alone."
    echo
    echo "  --headless skip the linux desktop only steps"
}

function main() {

    ###########################################################################
    #                                                                         #
    #                        Parsing Script Arguments                         #
    #                                                                         #
    ###########################################################################

    for arg in "$@"; do
        case "${arg}" in
            install|clean)
                MODE="${arg}"
                ;;
            --headless)
                HEADLESS=1
                ;;
            -h|--help)
                usage
                exit 0
                ;;
            *)
                print_err "Unknown argument: $(highlight_text ${arg})"
                usage
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

    # Set here rather than in the section below because both modes need it, and
    # clean must not fall through to that section's edit of zshrc
    export DOTFILES="$(pwd)"
    declare_file_targets

    ###########################################################################
    #                                                                         #
    #                Removing Files And Configuration (clean)                 #
    #                                                                         #
    ###########################################################################

    if [ "${MODE}" = "clean" ]; then
        clean_dotfiles
        exit 0
    fi

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

    # "package:command" where the installed binary is not named after the
    # package, see check_installed
    local deps_mac_only=("coreutils" "binutils" "gnu-sed" "go" "python")
    local deps_linux_only=("uv" "golang:go")
    local deps_linux_desktop=("i3" "rofi")
    local deps_agnostic=("curl" "zsh" "neovim:nvim" "gpg" "tar")

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

    print_info "DOTFILES=$(style_path ${DOTFILES})"
    print_info "Attempting to update DOTFILES variable in zshrc"

    # Skipped when it already reads correctly, otherwise every re-run would
    # clobber zshrc.dotfiles.bak with an already rewritten zshrc, losing the
    # only copy of the original
    if grep -qF "DOTFILES=\"$(minimise_path ${DOTFILES})\"" "${DOTFILES}/zshrc"; then
        print_info "zshrc already points at $(style_path ${DOTFILES}). $(highlight_text Skipping..)"
    elif sed -E -i.dotfiles.bak s@DOTFILES=.\*@DOTFILES=\"$(minimise_path ${DOTFILES})\"@g "${DOTFILES}/zshrc"; then
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

    run_platform_step "Creating" "Directories" create_dirs \
        dirs_mac_only dirs_linux_only dirs_agnostic

    run_desktop_step "Creating" "Directories" create_dirs dirs_linux_desktop

    ###########################################################################
    #                                                                         #
    #                Creating Symlinks To Configuration Files                 #
    #                                                                         #
    ###########################################################################

    print_section "Creating Symlinks"

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
    #                    Configuring Global Git Identity                      #
    #                                                                         #
    ###########################################################################

    print_info "$(emphasize_text Setting the global git identity)"
    setup_git_identity

    ###########################################################################
    #                                                                         #
    #                Switching This Repository's Remote To SSH                #
    #                                                                         #
    ###########################################################################

    print_info "$(emphasize_text Pointing the ${GIT_REMOTE} remote at SSH)"
    setup_ssh_remote

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

    local zsh_path
    zsh_path="$(command -v zsh || true)"

    if [ ! -x "${zsh_path}" ]; then
        print_err "zsh not found on PATH, unable to change the default shell. Aborting"
        exit 1
    # chsh authenticates even when the shell is already what was asked for, so
    # an unguarded call turns every re-run into a password prompt that aborts
    # the script when declined
    elif [ "$(login_shell)" = "${zsh_path}" ]; then
        print_info "Default shell is already $(highlight_text ${zsh_path}). $(highlight_text Skipping..)"
    elif chsh -s "${zsh_path}"; then
        print_info "Successfully changed default shell to $(highlight_text zsh)"
    else
        print_err "Failed to change default shell to $(highlight_text zsh). Aborting"
        exit 1
    fi

}

main "$@"
