FROM caddy:2.11.4-builder-alpine AS builder

RUN xcaddy build \
	--with github.com/caddy-dns/cloudflare@v0.2.4 \
	--with github.com/mholt/caddy-ratelimit@v0.1.0 \
	--with github.com/WeidiDeng/caddy-cloudflare-ip@f53b62aa13cb7ad79c8b47aacc3f2f03989b67e5 \
	--with github.com/mholt/caddy-dynamicdns@1af4f88765982db86ce091eeb075cfb2d9348dc8 \
	--with github.com/caddy-dns/selectel@v1.2.0 \
	--with github.com/caddy-dns/timeweb@v1.0.1

FROM caddy:2.11.4

COPY --from=builder /usr/bin/caddy /usr/bin/caddy

