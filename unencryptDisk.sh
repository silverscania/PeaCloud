#!/bin/bash

sudo cryptsetup luksOpen /dev/disk/by-uuid/71a2e23e-90dd-4ad6-86d3-2cda6926bc1c nextcloud
sudo mount /dev/mapper/nextcloud /mnt/nextcloud_encrypted/
