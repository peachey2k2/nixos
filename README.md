Here is my entire NixOS system.

## Install
1. Install NixOS conventionally with your desired partitioning.
2. Clone this repo to your home directory.
3. Run `~/nixos/scripts/install.sh`. It'll create the hardware configuration, bind the existing partitions and install everything.
4. Reboot.
5. Run `nh clean all -k 0` to get rid of all the fluff from the old system.


There are some aliases I added to enhance my workflow:
| alias | description |
|---|---|
|`%rebuild`|rebuilds the system|
|`%edit`|opens the system flake on an editor|
|`%config-reload`|updates all configs|
|`%list-packages`|list all installed packages|
|`%clear-backups`|brings up a prompt to remove the old instances of every replaced config|
|`%devel`|brings up a fuzzy finder to select between my projects|
|`%env`|opens a Nix shell with desired package(s) in PATH|
|`%logs`|prints out the last 10 lines of `nixos/log.txt`|

