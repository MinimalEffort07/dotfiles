```
       ██╗██████╗  ██████╗ ████████╗███████╗██╗██╗     ███████╗███████╗
      ██╔╝██╔══██╗██╔═══██╗╚══██╔══╝██╔════╝██║██║     ██╔════╝██╔════╝
     ██╔╝ ██║  ██║██║   ██║   ██║   █████╗  ██║██║     █████╗  ███████╗
    ██╔╝  ██║  ██║██║   ██║   ██║   ██╔══╝  ██║██║     ██╔══╝  ╚════██║
██╗██╔╝   ██████╔╝╚██████╔╝   ██║   ██║     ██║███████╗███████╗███████║
╚═╝╚═╝    ╚═════╝  ╚═════╝    ╚═╝   ╚═╝     ╚═╝╚══════╝╚══════╝╚══════╝
```

Install desired software packages and setup relevant configuration files.

## Supported Operating System
- MacOS (Homebrew)
- Linux (apt)

## Usage
Run from the root of the repository (the script uses the current working
directory to set the `DOTFILES` environment variable):
```bash
./install.sh
```
You will be prompted for your password to decrypt `gitconfig.enc` during the
git configuration step.

## Overview

The install script performs the following steps, in order:

1. **Determine OS** — Selects the package manager: `brew` on MacOS, `sudo apt`
   on Linux. On MacOS, Homebrew is installed first if it isn't already
   present.
2. **Uninstall conflicts** — Removes packages that conflict with the ones
   being installed. Currently: `vim` (replaced by neovim).
3. **Install dependencies**
   - All platforms: `curl`, `zsh`, `neovim`, `pip`, `gpg`, `tar`, `go`
   - MacOS only: `coreutils`, `binutils`, `gnu-sed`
   - Linux only: `i3`, `rofi`
4. **Clone repositories** — Clones any configured GitHub repos into `/opt`
   and chowns them to the current user (none configured at the moment).
5. **Set `DOTFILES` environment variable** — Rewrites the `DOTFILES=` line in
   `zshrc` to point at the repository's location (a `zshrc.dotfiles.bak`
   backup is created).
6. **Create directories**
   - All platforms: `~/projects/minimaleffort`, `~/projects/private-git`
   - Linux only: `~/.config/i3`, `/etc/i3`, `~/.config/rofi`
7. **Create symlinks** — Existing non-symlink files are backed up to
   `<file>.dotfiles.bak` before being replaced.
   - All platforms: `~/.zshrc` and `~/.gdbinit` point into the repo
   - MacOS only: `/usr/local/bin/vim` -> `/usr/local/bin/nvim`
   - Linux only: neovim config (for the user and root), i3 config (user and
     `/etc/i3/config`), rofi config, xmodmap mappings, and
     `/usr/bin/vim` -> `/usr/bin/nvim`
8. **Create local config script** — Creates an empty executable
   `~/.dotfiles_local_config` for machine-specific configuration (sourced by
   the zshrc).
9. **Set up git configs** — Decrypts `gitconfig.enc` with gpg (password
   prompt), extracts it, and installs:
   - `~/.gitconfig` (global config)
   - `~/projects/private-git/.gitconfig` and
     `~/projects/minimaleffort/.gitconfig` (per-directory identities)
   - SSH keys into `~/.ssh/private-git` and `~/.ssh/minimaleffort`, which are
     then added to a freshly started ssh-agent
10. **Switch remote to SSH** — Points this repo's `origin` at the SSH URL
    instead of HTTPS.
11. **Set up screen resolution** — Creates `~/.xrandr_preferences.sh` (run at
    login) if it doesn't already exist.
12. **Remap Caps_Lock to Control** — Adds `ctrl:nocaps` to `XKBOPTIONS` in
    `/etc/default/keyboard` (requires a restart to take effect).
13. **Change default shell to zsh** — Via `chsh`.

Note: installing the vim-plug plugin manager and neovim plugins is currently
disabled in the script.

## Notes

When remapping Caps_Lock to Control you don't want to put the xmodmap mappings 
inside your zshrc because you will get error that read:   
> xmodmap: please release the following keys within 2 seconds:   
> Control_L (keysym 0xffe3, keycode 37)   
> Alt_L (keysym 0xffe9, keycode 64)   

You also can't put the xmodmap call within your i3 configuration file because 
the keyboard gets reconfigured after the i3 configuration file is executed.   
  
Instead your can just edit the ```/etc/default/keyboard``` file directly and 
specify you want to change Caps_Lock to Control as done in the install script.   

   
## Configuration Not Handled By Install Script
On thinkpads running linux you wlil need to enable the use of the Function (fn)
keys. You essentially provide a mask to the kernel which specifies which keys 
should be handled. Do like so:
```bash
sudo -i
cat /sys/devices/platform/thinkpad_acpi/hotkey_recommended_mask > /sys/devices/platform/thinkpad_acpi/hotkey_mask
```

This will enable the fn keys as inputs. Now to get the sound working you want 
to install ```pulseaudio```. Those two steps fixed sounds buttons.   
   
To fix brightness buttons, ensure you have set the apropriate mask as above and 
then you need to ```enable display brightness keys``` in the power settings. I 
haven't figured out where this value is stored on disk so I just use 
```xfce4-power-manager-settings``` and you can see the option there. 

### Configuring Brightness
Stop screen from dimming after inactivity:
Potential Fix: ```gsettings set org.gnome.settings-daemon.plugins.power idle-brightness 100```
