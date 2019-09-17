# ccvfs
Replacement api for ComputerCraft's fs library, allowing for the manipulation of virtual files, device files, mounts, and virtual file systems.

    Copyright (C) 2019  Connor Horman

    This program is free software: you can redistribute it and/or modify
    it under the terms of the GNU General Public License as published by
    the Free Software Foundation, either version 3 of the License, or
    (at your option) any later version.

    This program is distributed in the hope that it will be useful,
    but WITHOUT ANY WARRANTY; without even the implied warranty of
    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
    GNU General Public License for more details.

    You should have received a copy of the GNU General Public License
    along with this program.  If not, see <https://www.gnu.org/licenses/>.

## License Exemptions

  This program supplants the ComputerCraft native `fs` api with a custom version. Other programs may access this supplanted api for the purposes of utilising the bindings from the native version, as well as the additional api functions documented. Such programs do not need to be released under the terms of the GNU General Public License to make use of either set of api bindings. 
  
  Additionally, this program provides additional apis which can be used by other programs via a "require" statement. The Linking Exemption of the GNU General Public License applies to these additional APIS, and as such, do not require programs making use of these APIs to be released under the terms of the GNU General Public License. 
  
## Contents of this Program

  This program provides several APIs, startup scripts, and shell commands which allow for the direct use of the APIs through the CraftOS Shell. 
  
### Installed APIS
* `fsbind` (as `fs`): replaces the standard ComputerCraft `fs` api with a modular one which allows for virtual files and filesystems. 
* `mounts`: Allows for other progams to introduce new mount handles to be consumed by `fsbind`.
* `devices`: Similar to `mounts` but for virtual/device files.
  
### Installed Shell Commands
* `mknod`: Creates a device file with given properties. 
* `mount`: Mounts some sort of virtual filesystem to a given directory
* `chroot`: Executes a program within a constrained environment, mapping absolute paths to paths resolved with some prefix.
* `ls`: Lists the files in a given directory, optionally with the file's properties
* `stat`: Lists the properties of a given file or directory. 
* `ln`: Forms symbolic links between files, or hard links on mounts that support them.
 
### Installed Startup Scripts

* `00vfs_inject.lua`: Run before all other startup scripts. Replaces the standard `fs` api with `fsbind`. 
* `load_mounts.lua`: If there is an `/etc/fstab` file, activates the mounts given in that file.
