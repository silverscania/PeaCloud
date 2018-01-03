#!/bin/bash

sudo cryptsetup luksOpen /dev/sdc5 nextcloud
sudo mount /dev/mapper/nextcloud /mnt/nextcloud_encrypted/
