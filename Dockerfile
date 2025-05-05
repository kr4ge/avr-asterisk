FROM debian:bullseye

ENV ASTERISK_VERSION=22.3.0

# Install dependencies
RUN apt-get update && \
    apt-get install -y \
    curl wget gnupg2 ca-certificates build-essential \
    libedit-dev libjansson-dev libxml2-dev uuid-dev \
    libssl-dev libncurses5-dev pkg-config subversion \
    python3 sudo libsqlite3-dev

# Download and build Asterisk
RUN wget https://downloads.asterisk.org/pub/telephony/asterisk/asterisk-${ASTERISK_VERSION}.tar.gz && \
    tar -xvzf asterisk-${ASTERISK_VERSION}.tar.gz && \
    cd asterisk-${ASTERISK_VERSION} && \
    contrib/scripts/get_mp3_source.sh && \
    ./configure && \
    make menuselect.makeopts && \
    # 🔥 Force-enable ARI modules here:
    menuselect/menuselect --enable res_http_websocket --enable res_ari --enable res_ari_applications --enable res_ari_asterisk --enable res_ari_bridges --enable res_ari_channels --enable res_ari_device_states --enable res_ari_endpoints --enable res_ari_events --enable res_ari_model --enable res_ari_playbacks --enable res_ari_recordings --enable res_ari_sounds menuselect.makeopts && \
    menuselect/menuselect --enable CORE-SOUNDS-EN-ULAW menuselect.makeopts && \
    make -j4 && make install && make samples && make config

# Copy configs
COPY configs/extensions.conf /etc/asterisk/extensions.conf
COPY configs/pjsip.conf /etc/asterisk/pjsip.conf
COPY configs/ari.conf /etc/asterisk/ari.conf
COPY configs/http.conf /etc/asterisk/http.conf
COPY configs/rtp.conf /etc/asterisk/rtp.conf

# Expose ports
EXPOSE 5060/udp 8088 5038/tcp
EXPOSE 10000-20000/udp

# Start Asterisk
CMD ["asterisk", "-f", "-vvv"]
