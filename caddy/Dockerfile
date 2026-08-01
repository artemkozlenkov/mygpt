# Caddy with the caddy-dns/azure module, so it can solve ACME DNS-01
# challenges against the Azure DNS zone for chat.softawebit.com
# (the host is behind CGNAT, so HTTP-01 challenges are not possible).
FROM caddy:2.11.4-builder AS builder
RUN xcaddy build --with github.com/caddy-dns/azure

FROM caddy:2.11.4
COPY --from=builder /usr/bin/caddy /usr/bin/caddy
