#!/bin/sh
###############################################################
# Copyright (C) 2019 Duall Sistemas Ltda.
###############################################################

set -e

docker build --force-rm -t paserver-firebird .

docker run -p 3050:3050 -p 9090:9090 -p 64211:64211 \
	-v $(pwd)/data:/opt/firebird/data \
	-v $(pwd)/bin:/home/paserver \
	--name paserver-firebird -dt --restart always paserver-firebird

docker exec -e TZ=America/Cuiaba -it -u paserver paserver-firebird paserver.sh
