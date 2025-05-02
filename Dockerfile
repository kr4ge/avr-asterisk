FROM ubuntu:22.04 AS builder

ENV ASTERISK_VERSION=20.9.2

# Install build deps
RUN apt-get update && apt-get install -y --no-install-recommends \
    build-essential wget curl git subversion gnupg2 ca-certificates \
    libedit-dev uuid-dev libjansson-dev libxml2-dev \
    libsqlite3-dev libsrtp2-dev libssl-dev libcurl4-openssl-dev \
    libncurses5-dev libspeex-dev libspeexdsp-dev libvorbis-dev libogg-dev \
    libgsm1 liburiparser-dev \
    && rm -rf /var/lib/apt/lists/*

# Download and compile Asterisk
WORKDIR /usr/src
RUN wget https://downloads.asterisk.org/pub/telephony/asterisk/asterisk-${ASTERISK_VERSION}.tar.gz && \
    tar xvf asterisk-${ASTERISK_VERSION}.tar.gz && \
    cd asterisk-${ASTERISK_VERSION} && \
    contrib/scripts/get_mp3_source.sh && \
    ./configure --with-jansson-bundled --with-pjproject-bundled && \
    make menuselect/menuselect && \
    menuselect/menuselect --enable chan_pjsip menuselect.makeopts && \
    menuselect/menuselect --enable res_http_websocket menuselect.makeopts && \
    menuselect/menuselect --enable res_pjsip_websocket menuselect.makeopts && \
    menuselect/menuselect --enable res_agi menuselect.makeopts && \
    menuselect/menuselect --enable res_prometheus menuselect.makeopts && \
    make -j$(nproc) && \
    make install && \
    make samples && \
    make config

# Final runtime image
FROM ubuntu:22.04

# Install runtime dependencies
RUN apt-get update && apt-get install -y --no-install-recommends \
    libedit2 libjansson4 libsqlite3-0 uuid libxml2 \
    libcurl4 liburiparser1 libgsm1 sox curl jq \
    && rm -rf /var/lib/apt/lists/*

# Copy from builder
COPY --from=builder /usr/sbin/asterisk /usr/sbin/
COPY --from=builder /usr/lib /usr/lib
COPY --from=builder /var/lib/asterisk /var/lib/asterisk
COPY --from=builder /var/spool/asterisk /var/spool/asterisk
COPY --from=builder /etc/asterisk /etc/asterisk
COPY --from=builder /usr/share/asterisk /usr/share/asterisk
COPY --from=builder /usr/lib/asterisk /usr/lib/asterisk
COPY --from=builder /usr/bin/safe_asterisk /usr/sbin/
COPY --from=builder /usr/src/asterisk-${ASTERISK_VERSION}/configs/basic-pbx /etc/asterisk/basic-pbx

# Inject your own config (mounted or COPYed at build time)
# COPY ./configs/*.conf /etc/asterisk/
COPY ./configs/extensions.conf /etc/asterisk/extensions.conf
COPY ./configs/pjsip.conf /etc/asterisk/pjsip.conf
COPY ./configs/ari.conf /etc/asterisk/ari.conf
COPY ./configs/http.conf /etc/asterisk/http.conf
COPY ./configs/rtp.conf /etc/asterisk/rtp.conf

# Expose required ports
EXPOSE 5060/udp 8088/tcp 5038/tcp
EXPOSE 10000-20000/udp

# Start Asterisk in foreground
CMD [ "asterisk", "-f", "-vvv" ]
