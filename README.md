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
- MacOS
- Linux

## Usage
```bash
./install.sh
```

## Overview

TODO

...

When remapping Caps_Lock to Control you don't want to put the xmodmap mappings 
inside your zshrc because you will get error that read:   
> xmodmap: please release the following keys within 2 seconds:   
> Control_L (keysym 0xffe3, keycode 37)   
> Alt_L (keysym 0xffe9, keycode 64)   

You also can't put the xmodmap call within your i3 configuration file because 
the keyboard gets reconfigured after the i3 configuration file is executed.   
  
Instead your can just edit the ```/etc/defualt/keyboard``` file directly and 
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
