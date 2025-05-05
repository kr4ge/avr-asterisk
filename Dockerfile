# ---------- Builder Stage ----------
  FROM debian:bullseye AS builder

  ENV ASTERISK_VERSION=22.3.0
  
  # Install build dependencies
  RUN apt-get update && \
      apt-get install -y --no-install-recommends \
      build-essential curl wget gnupg2 ca-certificates \
      libedit-dev libjansson-dev libxml2-dev uuid-dev \
      libssl-dev libncurses5-dev pkg-config subversion \
      python3 sudo libsqlite3-dev && \
      rm -rf /var/lib/apt/lists/*
  
  WORKDIR /usr/src
  
  # Download and extract Asterisk
  RUN wget https://downloads.asterisk.org/pub/telephony/asterisk/asterisk-${ASTERISK_VERSION}.tar.gz && \
      tar -xvzf asterisk-${ASTERISK_VERSION}.tar.gz && \
      cd asterisk-${ASTERISK_VERSION} && \
      contrib/scripts/get_mp3_source.sh && \
      ./configure --with-jansson-bundled --with-pjproject-bundled && \
      make menuselect.makeopts && \
      menuselect/menuselect --enable res_http_websocket \
                            --enable res_agi \
                            --enable res_prometheus \
                            --enable res_ari \
                            --enable res_ari_applications \
                            --enable res_ari_asterisk \
                            --enable res_ari_bridges \
                            --enable res_ari_channels \
                            --enable res_ari_device_states \
                            --enable res_ari_endpoints \
                            --enable res_ari_events \
                            --enable res_ari_model \
                            --enable res_ari_playbacks \
                            --enable res_ari_recordings \
                            --enable res_ari_sounds menuselect.makeopts && \
      make -j$(nproc) && make install && make config
  
  # ---------- Runtime Stage ----------
  FROM debian:bullseye-slim
  
  # Install runtime dependencies
  RUN apt-get update && \
      apt-get install -y --no-install-recommends \
      libedit2 libjansson4 libxml2 uuid libssl1.1 \
      libsqlite3-0 curl jq sox && \
      apt-get clean && rm -rf /var/lib/apt/lists/*
  
  # Copy binaries and Asterisk folders
  COPY --from=builder /usr/sbin/asterisk /usr/sbin/
  COPY --from=builder /usr/lib /usr/lib
  COPY --from=builder /usr/lib/asterisk /usr/lib/asterisk
  COPY --from=builder /etc/asterisk /etc/asterisk
  COPY --from=builder /var/lib/asterisk /var/lib/asterisk
  COPY --from=builder /var/spool/asterisk /var/spool/asterisk
  
  # Copy your configuration files
  COPY configs/extensions.conf /etc/asterisk/extensions.conf
  COPY configs/pjsip.conf /etc/asterisk/pjsip.conf
  COPY configs/ari.conf /etc/asterisk/ari.conf
  COPY configs/http.conf /etc/asterisk/http.conf
  COPY configs/rtp.conf /etc/asterisk/rtp.conf
  
  # Expose essential Asterisk ports
  EXPOSE 5060/udp
  EXPOSE 8088
  EXPOSE 5038
  EXPOSE 10000-20000/udp
  
  # Start Asterisk in foreground
  CMD ["asterisk", "-f", "-vvv"]
  