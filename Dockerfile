FROM debian:bullseye AS builder

ENV ASTERISK_VERSION=22.3.0

# Install only what is needed to build Asterisk
RUN apt-get update && apt-get install -y --no-install-recommends \
  curl wget gnupg2 ca-certificates build-essential \
  libedit-dev libjansson-dev libxml2-dev uuid-dev \
  libssl-dev libncurses5-dev pkg-config subversion \
  python3 sudo libsqlite3-dev && \
  rm -rf /var/lib/apt/lists/*

WORKDIR /usr/src
RUN wget https://downloads.asterisk.org/pub/telephony/asterisk/asterisk-${ASTERISK_VERSION}.tar.gz && \
    tar -xvzf asterisk-${ASTERISK_VERSION}.tar.gz && \
    cd asterisk-${ASTERISK_VERSION} && \
    contrib/scripts/get_mp3_source.sh && \
    ./configure && \
    make menuselect.makeopts && \
    menuselect/menuselect --enable res_http_websocket --enable res_ari \
                          --enable res_ari_applications --enable res_ari_asterisk \
                          --enable res_ari_bridges --enable res_ari_channels \
                          --enable res_ari_device_states --enable res_ari_endpoints \
                          --enable res_ari_events --enable res_ari_model \
                          --enable res_ari_playbacks --enable res_ari_recordings \
                          --enable res_ari_sounds menuselect.makeopts && \
    menuselect/menuselect --enable CORE-SOUNDS-EN-ULAW menuselect.makeopts && \
    make -j$(nproc) && \
    make install && \
    make config

# ---------------------
# Runtime Stage
# ---------------------
FROM debian:bullseye-slim

# Only runtime libraries
RUN apt-get update && apt-get install -y --no-install-recommends \
  libedit2 libjansson4 libxml2 uuid libssl1.1 \
  libsqlite3-0 curl jq sox && \
  apt-get clean && rm -rf /var/lib/apt/lists/*

# Copy only what’s needed from builder
COPY --from=builder /usr/sbin/asterisk /usr/sbin/
COPY --from=builder /usr/lib /usr/lib
COPY --from=builder /usr/lib/asterisk /usr/lib/asterisk
COPY --from=builder /usr/share/asterisk /usr/share/asterisk
COPY --from=builder /var/lib/asterisk /var/lib/asterisk
COPY --from=builder /var/spool/asterisk /var/spool/asterisk
COPY --from=builder /etc/asterisk /etc/asterisk

# Inject your configs
COPY config/extensions.conf /etc/asterisk/extensions.conf
COPY config/pjsip.conf /etc/asterisk/pjsip.conf
COPY config/ari.conf /etc/asterisk/ari.conf
COPY config/http.conf /etc/asterisk/http.conf
COPY config/rtp.conf /etc/asterisk/rtp.conf

# Expose ports
EXPOSE 5060/udp 8088 5038/tcp
EXPOSE 10000-20000/udp

# Entry command
CMD ["asterisk", "-f", "-vvv"]
