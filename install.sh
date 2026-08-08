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

# The zig used to build zls, decided by setup_zig.
ZIG_BIN=""

# Identity applied to the global git config, taken from this repository's commit
# history so a fresh machine commits under the same name as every other one.
GIT_NAME="MinimalEffort07"
GIT_EMAIL="90430937+MinimalEffort07@users.noreply.github.com"

# The remote of this repository that is switched from HTTPS to SSH on install
# and back again on clean.
GIT_REMOTE="origin"

# The virtual environment the python language servers are installed into. Kept
# out of the system python so that a distro upgrade cannot take them with it,
# and shared rather than per project so every checkout does not need its own
# copy of pyright.
VENV="${HOME}/.venv"

# The language servers configured in nvim/init.lua that are installable from
# PyPI, written "package:command" for the cases where the two names differ,
# same convention as check_installed.
#
# The rest of what init.lua enables is not uv's to install: lua_ls and zls are
# built from source below, neocmake ships its own release binaries,
# typescript-language-server and powershell_es come from npm and the
# PowerShellEditorServices bundle, and clangd comes from the distro's clang
# packages.
LSP_PIP_PACKAGES=("pyright:pyright-langserver")

# Where the language servers that have to be built from source are kept. Under
# HOME rather than /opt like clone_repos uses, because these are checkouts that
# get fetched, moved between tags and rebuilt over time, all of which is a good
# deal less awkward when the files are not root owned.
REPOS="${HOME}/repos"

# Where the built binaries are linked to, already on PATH from zshrc.
LOCAL_BIN="${HOME}/.local/bin"

# The links made into LOCAL_BIN, one "source destination" pair per line.
#
# Every other symlink this script owns is declared up front in
# declare_file_targets, which is what keeps clean in step with install. These
# cannot be: they are named after the version each binary reports, and which
# versions are on the machine is not known until install has looked. So they are
# written down as they are made and read back by clean instead.
LINK_MANIFEST="${HOME}/.dotfiles_links"

# lua_ls is not packaged for either platform, so it is built from its own
# bundled luamake. Left on its default branch rather than pinned: unlike zls it
# has no version relationship with anything else installed here.
LUA_LS_URL="https://github.com/LuaLS/lua-language-server.git"
LUA_LS_DIR="${REPOS}/lua-language-server"

# zls is pinned to the release matching ZIG_VERSION. It follows the compiler's
# breaking changes closely enough that master will not compile with anything
# other than the zig it was written against, and says so with a compile error.
#
# The pin is built in a worktree of its own rather than in the checkout, so a
# clone that was already there stays on whatever branch its owner left it on,
# with whatever they had built in it. Both builds are then linked as
# alternatives, see link_versioned_alternatives.
ZLS_URL="https://github.com/zigtools/zls.git"
ZLS_DIR="${REPOS}/zls"
ZLS_TAG="0.16.0"
ZLS_PIN_DIR="${REPOS}/zls-${ZLS_TAG}"

# zig 0.16 is not packaged either: apt carries zig0.14 and zig0.15 and a zig
# metapackage that depends on 0.14, so the compiler comes from the official
# tarball. Pinned by version and by the sha256 published alongside the release
# in ziglang.org/download/index.json, so a re-run cannot quietly build zls with
# a different compiler.
ZIG_VERSION="0.16.0"
ZIG_URL="https://ziglang.org/download/${ZIG_VERSION}"
ZIG_DIR="${REPOS}/zig-${ZIG_VERSION}"

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

# Echo $1 with every symlink along it resolved. Not readlink -f, which is a GNU
# extension the BSD readlink on macOS does not have, so the chain is walked here
# instead. The counter is a cycle guard: a link that points at itself would
# otherwise spin forever.
function resolve_path() {

    local path="$1"
    local target
    local hops=0

    while [ -h "${path}" ] && [ "${hops}" -lt 40 ]; do

        target="$(readlink "${path}")"

        # A relative link resolves against the directory the link itself is in
        case "${target}" in
            /*)
                path="${target}"
                ;;
            *)
                path="$(dirname "${path}")/${target}"
                ;;
        esac

        hops=$(( hops + 1 ))
    done

    echo "${path}"
}

# Record a "source destination" pair in LINK_MANIFEST as one this script made,
# ignoring a pair that is already written down. See LINK_MANIFEST for why these
# links are not declared with the rest.
function record_link() {

    local pair="$1"

    if [ -f "${LINK_MANIFEST}" ] && grep -qxF "${pair}" "${LINK_MANIFEST}"; then
        return 0
    fi

    echo "${pair}" >> "${LINK_MANIFEST}"
}

# create_syms for links whose name is only settled at install time, recording
# each one it makes so clean can find it again. Takes the same "source
# destination" pairs.
#
# A pair whose source is missing is reported and skipped rather than linked,
# because ln is perfectly happy to leave a dangling symlink behind for a build
# that never ran.
function create_recorded_syms() {

    local sym src dst

    for sym in "$@"; do
        symarr=($sym)
        src="${symarr[0]}"
        dst="${symarr[1]}"

        if [ ! -e "${src}" ]; then
            print_warn "$(style_path ${src}) does not exist, nothing to link to"\
                       "$(style_path ${dst}). $(highlight_text Skipping..)"
            continue
        fi

        # A link that already points here was not made by this run: it is either
        # one of ours from an earlier one, and so already in the manifest, or one
        # the user made themselves. Recording it in the second case would have
        # clean delete a link that was never ours to delete.
        if [ -h "${dst}" ] && [ "$(readlink "${dst}")" = "${src}" ]; then
            print_info "$(style_path ${dst}) already points at"\
                       "$(style_path ${src}). $(highlight_text Skipping..)"
            continue
        fi

        create_syms "${sym}"
        record_link "${sym}"
    done
}

# Undo the links written down in LINK_MANIFEST, then remove the manifest.
# remove_syms checks that each link still points where it was recorded, so a
# line for one that has since been repointed, replaced or removed by hand costs
# nothing but a skip.
function remove_recorded_links() {

    if [ ! -f "${LINK_MANIFEST}" ]; then
        print_info "$(style_path ${LINK_MANIFEST}) does not exist."\
                   "$(highlight_text Skipping..)"
        return 0
    fi

    local pair
    local pairs=()

    while read -r pair; do
        [ -n "${pair}" ] || continue
        pairs+=("${pair}")
    done < "${LINK_MANIFEST}"

    if [ ${#pairs[@]} -gt 0 ]; then
        remove_syms "${pairs[@]}"
    else
        print_info "$(style_path ${LINK_MANIFEST}) is empty. $(highlight_text Skipping..)"
    fi

    remove_files "${LINK_MANIFEST}"
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

# Install the python language servers into VENV, creating it first when it is
# not already there. An existing venv is reused rather than recreated, so
# anything else the user keeps in it survives a re-run of the installer.
function setup_lsp_venv() {

    if ! command -v uv &>/dev/null; then
        print_warn "uv not found on PATH, unable to install the language servers"
        return 1
    fi

    if [ -d "${VENV}" ]; then
        print_info "$(style_path ${VENV}) already exists. $(highlight_text Reusing it..)"
    else
        print_info "Attempting to create a virtual environment at $(style_path ${VENV})"

        if uv venv "${VENV}" &>/dev/null; then
            print_info "....Successfully created $(style_path ${VENV})"
        else
            print_err "....Failed to create $(style_path ${VENV})"
            return 1
        fi
    fi

    for lsp in "${LSP_PIP_PACKAGES[@]}"; do

        # Entries may be "package:command", only the package half is installable
        local pkg="${lsp%%:*}"
        local cmd="${lsp#*:}"

        # Deliberately a check for the binary in VENV and not on PATH: a
        # language server installed system wide elsewhere is not the one nvim
        # will be pointed at here
        if [ -x "${VENV}/bin/${cmd}" ]; then
            print_info "$(highlight_text ${pkg}) is already installed in"\
                       "$(style_path ${VENV}). $(highlight_text Skipping..)"
            continue
        fi

        print_info "Attempting to install $(highlight_text ${pkg}) into $(style_path ${VENV})"

        # --python rather than activating the venv, so the environment of the
        # rest of the script is left exactly as it was found
        if uv pip install --python "${VENV}" "${pkg}" &>/dev/null; then
            print_info "....Successfully installed $(highlight_text ${pkg})"
        else
            print_warn "....Failed to install $(highlight_text ${pkg})"
        fi
    done
}

# Echo the version the binary $1 reports when run with $2, or nothing when it
# will not run or prints nothing that looks like one. Loose about what else is
# on the line, so that a binary which prints its own name alongside the number
# is still read correctly.
function binary_version() {

    local bin="$1"
    local arg="$2"

    [ -n "${bin}" ] && [ -x "${bin}" ] || return 1

    "${bin}" "${arg}" 2>/dev/null |
        grep -oE '[0-9]+\.[0-9]+(\.[0-9]+)?(-[0-9A-Za-z.]+)?(\+[0-9A-Za-z.]+)?' |
        head -1
}

# Echo a plain integer for the version string $1, so two builds of the same thing
# can be put in order. Hand rolled because sort -V is a GNU extension and the
# BSD sort on macOS does not have it.
#
# major, minor and patch are packed a thousand apart. Below them sits the
# prerelease counter, with releases pinned above every counter value, because a
# prerelease is older than the release it is numbered for: zig numbers
# 0.17.0-dev towards 0.17.0, so what has to come out is
#
#   0.16.0 < 0.17.0-dev.44 < 0.17.0-dev.387 < 0.17.0
#
# The counter matters more than it looks. Two dev builds of the same version are
# otherwise indistinguishable, and a machine with a zig it built itself is very
# likely to have exactly that.
function version_rank() {

    local version="$1"
    local core pre major minor patch
    local counter=0
    local release=99999

    if [ -z "${version}" ]; then
        echo 0
        return 0
    fi

    case "${version}" in
        *-*)
            release=0
            pre="${version#*-}"

            # dev.387+31f157d80 -> 387. Build metadata after the plus names the
            # commit, not an ordering, so it is dropped.
            pre="${pre%%+*}"
            counter="$(printf '%s' "${pre}" | tr -dc '0-9')"

            case "${counter}" in ''|*[!0-9]*) counter=0 ;; esac

            # Base ten explicitly: a counter that arrived zero padded would
            # otherwise be read as octal, and 08 is not a valid octal number
            counter=$(( 10#${counter} ))

            # Kept below the value a release takes, so no prerelease can ever
            # outrank the release it is numbered for
            [ "${counter}" -lt 99999 ] || counter=99998
            ;;
    esac

    # Everything from the first dash or plus on is prerelease and build detail
    core="${version%%-*}"
    core="${core%%+*}"

    major="$(echo "${core}" | cut -d. -f1)"
    minor="$(echo "${core}" | cut -d. -f2)"
    patch="$(echo "${core}" | cut -d. -f3)"

    # A component that is missing or is not a number counts as zero rather than
    # taking the arithmetic below down with it
    case "${major}" in ''|*[!0-9]*) major=0 ;; esac
    case "${minor}" in ''|*[!0-9]*) minor=0 ;; esac
    case "${patch}" in ''|*[!0-9]*) patch=0 ;; esac

    echo $(( ((10#${major} * 1000 + 10#${minor}) * 1000 + 10#${patch}) * 100000
             + release + counter ))
}

# Link every candidate build of the command $1 into LOCAL_BIN under its own
# versioned name, and give the plain name to the newest of them.
#
# $2 is the argument that makes the binary print its version, zig wanting
# "version" where the rest want "--version", and the arguments after it are
# candidate paths, any of which may be empty or missing. This is what keeps a
# build that was already on the machine when the installer arrived: it becomes
# another candidate rather than something to overwrite, and if it is the newer
# of the two it keeps the plain name as well.
#
# Candidates are resolved through their symlinks and deduplicated, so a link
# this function made on an earlier run is not counted again as a build of its
# own, and the plain name never ends up pointing at itself.
function link_versioned_alternatives() {

    local name="$1"
    local version_arg="$2"
    shift 2

    local candidate version rank current
    local best="" best_rank=-1 best_version=""
    local seen=""
    local pairs=()

    for candidate in "$@"; do

        [ -n "${candidate}" ] && [ -x "${candidate}" ] || continue

        candidate="$(resolve_path "${candidate}")"

        case " ${seen} " in
            *" ${candidate} "*)
                continue
                ;;
        esac

        seen="${seen} ${candidate}"

        version="$(binary_version "${candidate}" "${version_arg}")"

        # A build that will not say what it is cannot be given a versioned name,
        # which is the whole point here, nor ranked against the others
        if [ -z "${version}" ]; then
            print_warn "$(style_path ${candidate}) does not report a version."\
                       "$(highlight_text Skipping..)"
            continue
        fi

        print_info "....Found $(highlight_text ${name} ${version}) at $(style_path ${candidate})"

        pairs+=("${candidate} ${LOCAL_BIN}/${name}-${version}")

        rank="$(version_rank "${version}")"

        if [ "${rank}" -gt "${best_rank}" ]; then
            best_rank="${rank}"
            best="${candidate}"
            best_version="${version}"
        fi
    done

    if [ ${#pairs[@]} -eq 0 ]; then
        print_warn "No runnable $(highlight_text ${name}) to link into"\
                   "$(style_path ${LOCAL_BIN}). $(highlight_text Skipping..)"
        return 1
    fi

    create_recorded_syms "${pairs[@]}"

    # PATH already landing on the newest build is the state this is trying to
    # reach, so there is nothing to do: claiming the plain name would only leave
    # clean a link to tidy that was never needed, and in the case where what
    # PATH finds is the user's own link, one that was never ours to tidy.
    current="$(command -v "${name}" 2>/dev/null || true)"

    if [ -n "${current}" ] && [ "$(resolve_path "${current}")" = "${best}" ]; then
        print_info "....$(highlight_text ${name}) on PATH is already"\
                   "$(highlight_text ${best_version}), the newest of these."\
                   "$(highlight_text Leaving it alone..)"
        return 0
    fi

    print_info "....Preferring $(highlight_text ${name} ${best_version}) for the plain name"

    create_recorded_syms "${best} ${LOCAL_BIN}/${name}"
}

# Clone $1 into $2 when it is not there, otherwise fetch into the checkout that
# already is. Deliberately not clone_repos: that one installs into /opt under
# sudo, which is right for something read once and never touched again, and
# wrong for a source tree that gets rebuilt.
#
# Nothing here moves the worktree, so a fetch on its own never changes what the
# build below will compile; checking out a pin is checkout_pinned_rev's job.
function clone_or_fetch_repo() {

    local url="$1"
    local dir="$2"

    if [ ! -d "${dir}/.git" ]; then

        # A path that exists but is not a checkout is something else's, and
        # cloning over it is not this script's call to make
        if [ -e "${dir}" ]; then
            print_warn "$(style_path ${dir}) exists but is not a git checkout."\
                       "$(highlight_text Skipping..)"
            return 1
        fi

        print_info "Attempting to clone $(highlight_text ${url}) into $(style_path ${dir})"

        if git clone -q "${url}" "${dir}" &>/dev/null; then
            print_info "....Successfully cloned into $(style_path ${dir})"
            return 0
        fi

        print_err "....Failed to clone $(highlight_text ${url})"
        return 1
    fi

    print_info "$(style_path ${dir}) already exists. $(highlight_text Fetching..)"

    # --tags so a pin that was added after this checkout was last fetched is
    # actually there to be checked out
    if git -C "${dir}" fetch -q --tags origin &>/dev/null; then
        print_info "....Successfully fetched"
    else
        print_warn "....Failed to fetch, using what is already checked out"
    fi

    return 0
}

# Check the tag, branch or commit $2 out in the checkout at $1. A checkout with
# local changes is left exactly where it is: the pin is here to make the build
# reproducible, not to throw away work in progress.
function checkout_pinned_rev() {

    local dir="$1"
    local rev="$2"
    local head target

    head="$(git -C "${dir}" rev-parse --verify HEAD 2>/dev/null || true)"
    target="$(git -C "${dir}" rev-parse --verify "${rev}^{commit}" 2>/dev/null || true)"

    if [ -n "${head}" ] && [ "${head}" = "${target}" ]; then
        print_info "$(style_path ${dir}) is already at $(highlight_text ${rev})."\
                   "$(highlight_text Skipping..)"
        return 0
    fi

    # --untracked-files=no because a build output or a scratch file sitting in
    # the tree is no reason to refuse: git checkout only objects to untracked
    # files it would have to overwrite, and does so itself. Changes to tracked
    # files are the ones worth stopping for.
    if [ -n "$(git -C "${dir}" status --porcelain --untracked-files=no 2>/dev/null)" ]; then
        print_warn "$(style_path ${dir}) has local changes."\
                   "$(highlight_text Leaving it where it is..)"
        return 0
    fi

    print_info "Attempting to check $(highlight_text ${rev}) out in $(style_path ${dir})"

    # Detached on purpose. The pin is a release tag, so there is no branch to be
    # on, and leaving a branch checked out at a tag would only look like the
    # branch is what got built.
    if git -C "${dir}" checkout -q --detach "${rev}" &>/dev/null; then
        print_info "....Successfully checked out $(highlight_text ${rev})"
    else
        print_warn "....Failed to check out $(highlight_text ${rev}),"\
                   "using what is already checked out"
    fi

    return 0
}

# Check $3 out as a worktree of the repository $1 at $2, reusing one that is
# already there.
#
# A worktree rather than checking the pin out in the repository itself: that
# checkout belongs to whoever cloned it, along with whatever they have built in
# it, and wanting a pinned build is no reason to move their HEAD off the branch
# they left it on or to overwrite their build output. The worktree shares the
# object store, so this costs a checkout rather than a second copy of the
# history.
function add_worktree() {

    local repo="$1"
    local dir="$2"
    local rev="$3"

    if [ -d "${dir}" ]; then

        # A linked worktree has a .git file pointing back at the repository it
        # belongs to, where a plain directory or a clone of its own does not
        if [ ! -e "${dir}/.git" ]; then
            print_warn "$(style_path ${dir}) exists but is not a git worktree."\
                       "$(highlight_text Skipping..)"
            return 1
        fi

        print_info "$(style_path ${dir}) already exists. $(highlight_text Reusing it..)"
        checkout_pinned_rev "${dir}" "${rev}"
        return 0
    fi

    print_info "Attempting to add a $(highlight_text ${rev}) worktree of"\
               "$(style_path ${repo}) at $(style_path ${dir})"

    if git -C "${repo}" worktree add -q --detach "${dir}" "${rev}" &>/dev/null; then
        print_info "....Successfully added the worktree"
        return 0
    fi

    # A worktree directory removed by hand leaves its administrative entry
    # behind in the repository, and that entry alone is enough to make add
    # refuse the same path again
    print_info "....Failed. Pruning stale worktree entries and trying once more"

    git -C "${repo}" worktree prune &>/dev/null

    if git -C "${repo}" worktree add -q --detach "${dir}" "${rev}" &>/dev/null; then
        print_info "....Successfully added the worktree"
        return 0
    fi

    print_err "....Failed to add a worktree at $(style_path ${dir})"
    return 1
}

# Clone and build lua-language-server, leaving the binary at
# ${LUA_LS_DIR}/bin/lua-language-server.
#
# The clone does not recurse: make.sh runs the submodule update itself, and this
# repository vendors enough of them (luamake, bee.lua, the love and lovr API
# docs) that fetching the lot twice is worth avoiding.
function build_lua_ls() {

    if ! clone_or_fetch_repo "${LUA_LS_URL}" "${LUA_LS_DIR}"; then
        return 1
    fi

    local bin="${LUA_LS_DIR}/bin/lua-language-server"

    # A built binary is a built binary: the fetch above does not move the
    # worktree, so there is nothing new to compile on a re-run. Picking up
    # upstream changes is a git pull and a ./make.sh by hand, deliberately, so
    # that reinstalling the dotfiles does not turn into a ten minute rebuild.
    if [ -x "${bin}" ] && "${bin}" --version &>/dev/null; then
        print_info "$(highlight_text lua-language-server) is already built at"\
                   "$(style_path ${bin}). $(highlight_text Skipping..)"
        return 0
    fi

    local log="${TMPDIR:-/tmp}/lua-language-server-build.log"

    print_info "Attempting to build $(highlight_text lua-language-server)."\
               "$(highlight_text This takes a few minutes..)"

    # In a subshell so the working directory of the rest of the script, which
    # DOTFILES was derived from, is left where it was found
    if (cd "${LUA_LS_DIR}" && ./make.sh) &>"${log}"; then
        print_info "....Successfully built $(highlight_text lua-language-server)"
    else
        print_warn "....Failed to build $(highlight_text lua-language-server),"\
                   "see $(style_path ${log})"
        return 1
    fi

    # luamake writes the binary next to the main.lua it loads at startup, and
    # finds that through its own executable path, so this has to be a real build
    # tree and not just a binary that landed somewhere
    if [ ! -x "${bin}" ] || ! "${bin}" --version &>/dev/null; then
        print_warn "....$(style_path ${bin}) does not run after a successful build"
        return 1
    fi

    return 0
}

# Echo the "<arch>-<os>" string zig stamps its release tarballs with, or fail
# when this platform has no published release.
function zig_platform() {

    local arch

    case "$(uname -m)" in
        x86_64|amd64)
            arch="x86_64"
            ;;
        arm64|aarch64)
            arch="aarch64"
            ;;
        *)
            return 1
            ;;
    esac

    if [ "${OS}" = "MacOS" ]; then
        echo "${arch}-macos"
    else
        echo "${arch}-linux"
    fi
}

# The published sha256 of the ZIG_VERSION tarball for the platform $1. A case
# rather than an associative array, which needs bash 4 and so is out on macOS.
function zig_shasum() {

    case "$1" in
        x86_64-linux)
            echo "70e49664a74374b48b51e6f3fdfbf437f6395d42509050588bd49abe52ba3d00"
            ;;
        aarch64-linux)
            echo "ea4b09bfb22ec6f6c6ceac57ab63efb6b46e17ab08d21f69f3a48b38e1534f17"
            ;;
        aarch64-macos)
            echo "b23d70deaa879b5c2d486ed3316f7eaa53e84acf6fc9cc747de152450d401489"
            ;;
        x86_64-macos)
            echo "0387557ed1877bc6a2e1802c8391953baddba76081876301c522f52977b52ba7"
            ;;
        *)
            return 1
            ;;
    esac
}

# Echo the sha256 of the file $1. macOS gets sha256sum from the coreutils this
# script installs, but that is a dependency of the install and not something to
# lean on part way through one, so shasum is accepted too.
function file_sha256() {

    if command -v sha256sum &>/dev/null; then
        sha256sum "$1" | cut -d' ' -f1
    elif command -v shasum &>/dev/null; then
        shasum -a 256 "$1" | cut -d' ' -f1
    else
        return 1
    fi
}

# True when the zig version string $1 belongs to the release series zls ZLS_TAG
# builds against.
#
# A dev build is rejected even when its version is the one wanted: dev builds
# are numbered for the release they are working towards, so 0.17.0-dev carries
# exactly the breaking changes a zls pinned to 0.16 has not caught up with.
function zig_is_compatible() {

    local version="$1"

    case "${version}" in
        ""|*-dev*)
            return 1
            ;;
    esac

    [ "${version%.*}" = "${ZIG_VERSION%.*}" ]
}

# Download and unpack the pinned zig release into REPOS, leaving the compiler at
# ${ZIG_DIR}/zig. Verified against zig_shasum, so a tarball that arrived
# truncated, or from something sitting in the middle of the connection, is
# thrown away rather than used to build a language server.
function download_zig() {

    local platform tarball url want got tmp extracted stale

    if ! platform="$(zig_platform)"; then
        print_err "No zig release is published for $(highlight_text $(uname -m))"\
                  "on $(highlight_text ${OS})"
        return 1
    fi

    if ! want="$(zig_shasum "${platform}")"; then
        print_err "No pinned sha256 recorded for $(highlight_text ${platform})"
        return 1
    fi

    tarball="zig-${platform}-${ZIG_VERSION}.tar.xz"
    url="${ZIG_URL}/${tarball}"

    # REPOS is in dirs_agnostic and so already created by the time this runs,
    # but the unpack below is the one step here that cannot report its way out
    # of it being missing
    mkdir -p "${REPOS}" &>/dev/null

    # Reached only when ${ZIG_DIR}/zig is missing or is not ZIG_VERSION, see
    # setup_zig, so anything still under these two paths is an earlier run's
    # interrupted unpack. Both names have the pinned version in them and are
    # written by nothing else, so they are ours to clear away.
    extracted="${REPOS}/zig-${platform}-${ZIG_VERSION}"

    for stale in "${ZIG_DIR}" "${extracted}"; do

        [ -e "${stale}" ] || continue

        print_warn "$(style_path ${stale}) is left over from an incomplete"\
                   "unpack, removing it"

        if ! rm -rf "${stale}" &>/dev/null; then
            print_err "....Failed to remove $(style_path ${stale})"
            return 1
        fi
    done

    if ! tmp="$(mktemp "${TMPDIR:-/tmp}/zig-XXXXXX.tar.xz")"; then
        print_err "Failed to create a temporary file to download zig into"
        return 1
    fi

    print_info "Attempting to download $(highlight_text ${url})"

    if ! curl -fsSL --retry 3 -o "${tmp}" "${url}" &>/dev/null; then
        print_err "....Failed to download $(highlight_text ${tarball})"
        rm -f "${tmp}"
        return 1
    fi

    if ! got="$(file_sha256 "${tmp}")"; then
        print_err "....Neither sha256sum nor shasum is available to verify"\
                  "$(highlight_text ${tarball})"
        rm -f "${tmp}"
        return 1
    fi

    if [ "${got}" != "${want}" ]; then
        print_err "....$(highlight_text ${tarball}) has sha256 ${got}, expected"\
                  "${want}. $(emphasize_text Refusing to unpack it..)"
        rm -f "${tmp}"
        return 1
    fi

    print_info "....sha256 matches the published $(highlight_text ${ZIG_VERSION}) release"
    print_info "....Attempting to unpack into $(style_path ${ZIG_DIR})"

    if ! tar -xJf "${tmp}" -C "${REPOS}" &>/dev/null; then
        print_err "....Failed to unpack $(highlight_text ${tarball})"
        rm -f "${tmp}"
        return 1
    fi

    rm -f "${tmp}"

    # Renamed out of the tarball's platform stamped directory, so the path the
    # symlink and the zls build refer to is the same on every machine
    if ! mv "${extracted}" "${ZIG_DIR}" &>/dev/null; then
        print_err "....Failed to move $(style_path ${extracted}) to $(style_path ${ZIG_DIR})"
        return 1
    fi

    print_info "....Successfully unpacked $(highlight_text zig ${ZIG_VERSION})"

    return 0
}

# Work out which zig to build zls with and set ZIG_BIN to it.
#
# A zig already installed is used as it is when it is of the right release
# series, so a machine that already has 0.16 does not end up carrying a second
# copy of the same compiler. Anything else, including a newer dev build, gets
# the pinned release fetched alongside it under its own versioned name, leaving
# whatever is on PATH as the zig the user gets when they type zig.
function setup_zig() {

    local installed installed_version

    installed="$(command -v zig || true)"

    if [ -x "${installed}" ]; then

        installed_version="$("${installed}" version 2>/dev/null || true)"

        if zig_is_compatible "${installed_version}"; then
            print_info "$(highlight_text zig ${installed_version}) at"\
                       "$(style_path ${installed}) can build"\
                       "$(highlight_text zls ${ZLS_TAG}). $(highlight_text Using it..)"
            ZIG_BIN="${installed}"
            return 0
        fi

        print_warn "$(highlight_text zig ${installed_version:-of unknown version})"\
                   "at $(style_path ${installed}) cannot build"\
                   "$(highlight_text zls ${ZLS_TAG}), which needs"\
                   "$(highlight_text ${ZIG_VERSION%.*}). Fetching that alongside it.."
    else
        print_info "No $(highlight_text zig) on PATH, fetching $(highlight_text ${ZIG_VERSION})"
    fi

    if [ -x "${ZIG_DIR}/zig" ] &&
       [ "$("${ZIG_DIR}/zig" version 2>/dev/null || true)" = "${ZIG_VERSION}" ]; then
        print_info "$(highlight_text zig ${ZIG_VERSION}) is already unpacked at"\
                   "$(style_path ${ZIG_DIR}). $(highlight_text Skipping the download..)"
    elif ! download_zig; then
        return 1
    fi

    installed_version="$("${ZIG_DIR}/zig" version 2>/dev/null || true)"

    if [ "${installed_version}" != "${ZIG_VERSION}" ]; then
        print_warn "$(style_path ${ZIG_DIR}/zig) reports"\
                   "$(highlight_text ${installed_version:-nothing}), expected"\
                   "$(highlight_text ${ZIG_VERSION})"
        return 1
    fi

    ZIG_BIN="${ZIG_DIR}/zig"

    return 0
}

# Build ZLS_TAG in a worktree of the zls checkout, leaving the binary at
# ${ZLS_PIN_DIR}/zig-out/bin/zls. setup_zig has to have run first.
#
# Nothing here touches ${ZLS_DIR} beyond a fetch and, on the first run, the
# worktree entry. A build the owner of that checkout had in it is left exactly
# where it was and picked up afterwards as another candidate, see
# link_versioned_alternatives.
function build_zls() {

    if [ ! -x "${ZIG_BIN}" ]; then
        print_warn "No zig available to build $(highlight_text zls) with"
        return 1
    fi

    local bin="${ZLS_PIN_DIR}/zig-out/bin/zls"

    # Checked before anything goes near git, so that a re-run with the pinned
    # build already in place does not fetch, does not add a worktree and does not
    # compile. Version rather than existence, so a binary left from a build of
    # something else is not mistaken for this one.
    if [ "$(binary_version "${bin}" --version)" = "${ZLS_TAG}" ]; then
        print_info "$(highlight_text zls ${ZLS_TAG}) is already built at"\
                   "$(style_path ${bin}). $(highlight_text Skipping..)"
        return 0
    fi

    if ! clone_or_fetch_repo "${ZLS_URL}" "${ZLS_DIR}"; then
        return 1
    fi

    if ! add_worktree "${ZLS_DIR}" "${ZLS_PIN_DIR}" "${ZLS_TAG}"; then
        return 1
    fi

    local log="${TMPDIR:-/tmp}/zls-build.log"

    print_info "Attempting to build $(highlight_text zls ${ZLS_TAG}) with"\
               "$(style_path ${ZIG_BIN}). $(highlight_text This takes a few minutes..)"

    # ReleaseSafe rather than the debug default, which is what the project ships
    # its own releases as and is the difference between completion feeling
    # instant and feeling like a language server
    if (cd "${ZLS_PIN_DIR}" && "${ZIG_BIN}" build -Doptimize=ReleaseSafe) &>"${log}"; then
        print_info "....Successfully built $(highlight_text zls)"
    else
        print_warn "....Failed to build $(highlight_text zls), see $(style_path ${log})"
        return 1
    fi

    if [ ! -x "${bin}" ]; then
        print_warn "....$(style_path ${bin}) is missing after a successful build"
        return 1
    fi

    return 0
}

# Build the language servers that ship no binaries and link them into LOCAL_BIN,
# where zshrc already has PATH pointing.
#
# Each of the three is linked from every candidate the machine has, ours and any
# that were already here, so that nothing already built gets overwritten and the
# newest of them is what the plain name resolves to.
function setup_built_lsps() {

    print_info "$(emphasize_text Building lua-language-server)"
    build_lua_ls

    print_info "$(emphasize_text Building zls ${ZLS_TAG})"
    if setup_zig; then
        build_zls
    fi

    print_info "$(emphasize_text Linking the language servers into $(style_path ${LOCAL_BIN}))"

    link_versioned_alternatives lua-language-server --version \
        "${LUA_LS_DIR}/bin/lua-language-server" \
        "$(command -v lua-language-server || true)"

    link_versioned_alternatives zls --version \
        "${ZLS_PIN_DIR}/zig-out/bin/zls" \
        "${ZLS_DIR}/zig-out/bin/zls" \
        "$(command -v zls || true)"

    link_versioned_alternatives zig version \
        "${ZIG_DIR}/zig" \
        "$(command -v zig || true)"
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
    # never run a program which uses it will not have one. REPOS and LOCAL_BIN
    # are where the language servers built from source are cloned and linked.
    dirs_agnostic=("${HOME}/.config"
                   "${HOME}/projects/minimaleffort"
                   "${REPOS}"
                   "${LOCAL_BIN}")

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

    # The links into LOCAL_BIN are deliberately not declared here. They are
    # named after the version each language server build reports, which is not
    # known until install has looked at the machine, so they are recorded in
    # LINK_MANIFEST as they are made and removed from it by clean.
}

# Remove the files and configuration the installer put on the system, in the
# reverse order it created them. Deliberately not undone: installed packages,
# repositories cloned into /opt, the checkouts, worktrees and unpacked
# toolchains under REPOS, and the login shell, all of which are shared system
# state that the user may well want regardless of these dotfiles. Of the
# language server work, only the links into LOCAL_BIN go.
function clean_dotfiles() {

    print_section "Removing Symlinks"

    run_platform_step "Removing" "Symlinks" remove_syms \
        syms_mac_only syms_linux_only syms_agnostic

    run_desktop_step "Removing" "Symlinks" remove_syms syms_linux_desktop

    print_info "$(emphasize_text Removing the language server symlinks in $(style_path ${LOCAL_BIN}))"
    remove_recorded_links

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
    echo "             packages, /opt repositories, the ~/repos source"
    echo "             checkouts and builds, and the login shell alone."
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
    # ninja and a C++17 compiler are what lua_ls' bundled luamake builds with,
    # and xz unpacks the zig tarball, so all three are here for the language
    # server builds further down rather than for anything nvim loads directly
    local deps_mac_only=("coreutils" "binutils" "gnu-sed" "go" "python" "ninja" "xz")
    local deps_linux_only=("uv" "golang:go" "fzf" "make" "clang" "clangd"
                           "ninja-build:ninja" "g++" "xz-utils:xz")
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

    ###########################################################################
    #                                                                         #
    #                       Installing Language Servers                       #
    #                                                                         #
    ###########################################################################

    # After the two sections above, both of which this depends on: the clones
    # and the built binaries need REPOS and LOCAL_BIN to exist first
    print_section "Installing Language Servers"

    print_info "$(emphasize_text Installing the python language servers into $(style_path ${VENV}))"
    setup_lsp_venv

    setup_built_lsps

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
