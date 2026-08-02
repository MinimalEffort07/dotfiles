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

On headless machines (WSL2, servers), skip the desktop-only pieces (i3, rofi,
their configs, xrandr, the caps-lock remap):
```bash
./install.sh --headless
```

## What install.sh Sets Up

### Packages
Installed via `brew` on MacOS and `apt` on Linux:

- Everywhere: `curl`, `zsh`, `neovim`, `gpg`, `tar`
- Linux: `python3-pip`, `golang`, plus `i3` and `rofi` on desktops
- MacOS: `coreutils`, `binutils`, `gnu-sed`, `go`, `python`

On MacOS, Homebrew is installed first if missing, and the conflicting `vim`
package is uninstalled. On Linux vim is left installed (see editor
alternatives below).

### Symlinks
Config files are symlinked into the repo, so edits here take effect
immediately:

- All platforms: `~/.zshrc`, `~/.gdbinit`
- MacOS: `/usr/local/bin/vim` -> `nvim`
- Linux: user nvim config (`~/.config/nvim`), i3 config (user and
  `/etc/i3/config`), rofi config, xmodmap mappings

### Editor alternatives (Linux)
`v`, `vi`, and `vim` are registered with `update-alternatives`, all pointing
at nvim and pinned with `--set` (manual mode), so nvim wins even though vim
stays installed.

### Root's nvim config (Linux)
Copied (rsync, root-owned) into `/root/.config/nvim` rather than symlinked,
so root's editor doesn't execute user-writable config.

### Misc
- Creates `~/projects/minimaleffort`
- Creates an empty executable `~/.dotfiles_local_config` for machine-local
  shell config (sourced by the zshrc)
- Rewrites the `DOTFILES=` line in `zshrc` to point at the repo's location
- Changes the default shell to zsh via `chsh`
- Remaps caps-lock to Control via `/etc/default/keyboard` (Linux desktop,
  needs a restart to take effect)
- Generates `~/.xrandr_preferences.sh` for the detected primary display
  (Linux desktop)

## Destructive Behavior / Safety
- Existing real config files at symlink destinations are backed up with
  numbered backups (`file.dotfiles.bak`, `file.dotfiles.bak.~1~`, ...) before
  being replaced — re-runs never overwrite an earlier backup. If a file
  cannot be backed up, the script aborts rather than deleting it.
- Essential steps (package installs, symlinks, directories, shell change)
  abort the script on failure; cosmetic steps (editor alternatives, root nvim
  copy, xrandr, caps-lock) warn and continue.
- The script is safe to re-run; already-installed packages and existing
  symlinks/directories are skipped or cleanly replaced.

## No Longer Handled
Git identity/SSH key setup was removed — the script no longer decrypts a
gitconfig bundle; set up git config and SSH keys manually per machine.

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
