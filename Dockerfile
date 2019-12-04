###############################################################
# Copyright (C) 2019 Duall Sistemas Ltda.
###############################################################

###############################################################
# Starting Firebird daemon:
#
# docker build --force-rm -t paserver-firebird .
# docker run -p 3050:3050 -p 9090:9090 -p 64211:64211 \
#   -v $(pwd)/data:/opt/firebird/data \
#   -v $(pwd)/bin:/home/paserver \
#   --name paserver-firebird -dt --restart always paserver-firebird
#
# Executing PAServer:
#
# docker exec -it -u paserver paserver-firebird paserver.sh
###############################################################

FROM ubuntu:bionic AS downloader

ENV DEBIAN_FRONTEND noninteractive

RUN apt-get update && apt-get install -qy --no-install-recommends \
    ca-certificates \
    build-essential \
    cmake \
    curl \
    libgnutls28-dev

RUN \
    curl -SL http://altd.embarcadero.com/releases/studio/20.0/PAServer/Release3/LinuxPAServer20.0.tar.gz | tar -zx && \
    curl -SL https://github.com/FirebirdSQL/firebird/releases/download/R3_0_4/Firebird-3.0.4.33054-0.amd64.tar.gz | tar -zx && \
    curl -SL https://launchpad.net/ubuntu/+source/libtommath/0.42.0-1.2/+build/8082257/+files/libtommath0_0.42.0-1.2_amd64.deb -o libtommath0_0.42.0-1.2_amd64.deb && \
    curl -SL https://github.com/risoflora/libsagui/archive/v2.4.7.tar.gz | tar -zx && \
    cd libsagui-2.4.7/ && mkdir build && cd build/ && \
    cmake -DSG_HTTPS_SUPPORT=ON .. && \
    make sagui install/strip

FROM ubuntu:bionic

###############################################################
# Specify the timezone.
###############################################################
ENV TZ 'America/Sao_Paulo'

LABEL Maintainer="Duall Sistemas <duallsistemas@gmail.com>"
LABEL Name="PAServer/Firebird"
LABEL Version="10.3.3/3.0.4"

ENV DEBIAN_FRONTEND noninteractive

RUN apt-get update && apt-get install -qy --no-install-recommends \
    ca-certificates \
    build-essential \
    tzdata \
    netbase \
    libltdl7 \
    openssl1.0 \
    libc-ares2 \
    libcurl3 \
    libcurl-openssl1.0-dev \
    libxml2 \
    libxslt1.1 && \
    apt-get clean && apt-get autoclean && rm -rf /var/lib/apt/lists/*

COPY --from=downloader /PAServer-20.0/paserver /usr/bin/

COPY --from=downloader /PAServer-20.0/paconsole /usr/bin/

COPY --from=downloader /PAServer-20.0/linuxgdb /usr/bin/

COPY --from=downloader /PAServer-20.0/paserver.config /etc/

COPY --from=downloader /Firebird-3.0.4.33054-0.amd64 /firebird

COPY --from=downloader /libtommath0_0.42.0-1.2_amd64.deb /

COPY --from=downloader /usr/local/lib/libsagui.so.2.4.7 /usr/lib/x86_64-linux-gnu/

COPY ./paserver.sh /usr/bin/paserver.sh

COPY mime.types /etc/

COPY duallapi.config /etc/

RUN \
    echo $TZ > /etc/timezone && \
    dpkg-reconfigure tzdata && \
    dpkg -i libtommath0_0.42.0-1.2_amd64.deb && rm libtommath0_0.42.0-1.2_amd64.deb && \
    cd /firebird/ && ./install.sh -silent && cd .. && \
    ln -sf '/opt/firebird/bin/fbguard' /usr/bin/ && \
    ln -sf '/opt/firebird/bin/isql' /usr/bin/ && \
    sed -i 's/ISC_PASSWORD=.*/ISC_PASSWORD=masterkey/' /opt/firebird/SYSDBA.password && \
    sed -i 's/RemoteBindAddress = localhost/RemoteBindAddress = /g' /opt/firebird/firebird.conf && \    
    echo 'duall = /opt/firebird/data/duall.fdb' >> /opt/firebird/databases.conf && \
    ln -sf '/lib/x86_64-linux-gnu/libz.so.1' '/usr/lib/x86_64-linux-gnu/libz.so' && \
    ln -sf '/usr/lib/x86_64-linux-gnu/libcares.so.2' '/usr/lib/x86_64-linux-gnu/libcares.so' && \
    ln -sf '/usr/lib/x86_64-linux-gnu/libcrypto.so.1.0.0' '/usr/lib/x86_64-linux-gnu/libcrypto.so' && \
    ln -sf '/usr/lib/x86_64-linux-gnu/libcurl.so.4' '/usr/lib/x86_64-linux-gnu/libcurl.so' && \
    ln -sf '/usr/lib/x86_64-linux-gnu/libxml2.so.2' '/usr/lib/x86_64-linux-gnu/libxml2.so' && \
    ln -sf '/usr/lib/x86_64-linux-gnu/libsagui.so.2.4.7' '/usr/lib/x86_64-linux-gnu/libsagui.so.2' && \
    ln -sf '/usr/lib/x86_64-linux-gnu/libsagui.so.2.4.7' '/usr/lib/x86_64-linux-gnu/libfbclient.so' && \
    ln -sf '/opt/firebird/lib/libfbclient.so' '/usr/lib/x86_64-linux-gnu/libfbclient.so' && \
    ln -sf '/opt/firebird/lib/libfbclient.so.2' '/usr/lib/x86_64-linux-gnu/libfbclient.so.2' && \
    ln -sf '/opt/firebird/lib/libfbclient.so.3.0.4' '/usr/lib/x86_64-linux-gnu/libfbclient.so.3.0.4' && \
    ldconfig && \
    groupadd paserver && useradd paserver -m -g paserver

VOLUME [ "/opt/firebird/data" ]

VOLUME [ "/home/paserver" ]

RUN \
    chown firebird:firebird -R /opt/firebird/data && \
    echo "ALTER USER sysdba SET password 'masterkey';" | isql -u sysdba -p masterkey /opt/firebird/security3.fdb

EXPOSE 3050/tcp 9090/tcp 64211/tcp

CMD [ "fbguard" ]

WORKDIR /usr/bin
