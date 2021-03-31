# moe-get-win-wallpapers

This is a project heavily inspired by c't magazine and downloads the
Windows 10 lockscreen images and renames them according to the
description of the picture (e.g. location).

This is a powershell script that, when executed without any command
line arguments, stores the lockscreen pictures in a configurable
folder.

## Configuration

In the script itself, there are the following configuration options:

* ```$CollectionFolder```: this is the name of the folder in which the
lockscreen pictures are stored. Important: this is a subfolder of the
Windows ```Pictures``` folder.
* ```$SetWallpaper```: when set to ```true```, the desktop background
picture is set correspondingly. When set to ```false``` the script will
only collect pictures and store them under the ```$CollectionFolder```.
* ```$Format```: per default this is set to ```Landscape``` to collect
pictures in landscape for, if you want to collect portrait pictures,
you can set this to ```Portrait```.

## Installation (optional)

## Deinstallation (optional)
