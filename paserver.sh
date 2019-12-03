#!/bin/sh
###############################################################
# Copyright (C) 2019 Duall Sistemas Ltda.
###############################################################

set -e

paserver -scratchdir=/home/paserver -unrestricted -password= -config=/etc/paserver.config
