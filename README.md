# caddy-dns-pro

Docker образ [Caddy](https://caddyserver.com/) с DNS-плагинами для автоматического получения SSL-сертификатов и управления DNS-записями.

Образ еженедельно обновляется до последней версии Caddy через GitHub Actions.

## Модули

| Модуль | Описание | Источник |
|--------|----------|----------|
| `dns.providers.selectel` | Selectel DNS API v2 | [caddy-dns/selectel](https://github.com/caddy-dns/selectel) |
| `dns.providers.timeweb` | Timeweb DNS | [caddy-dns/timeweb](https://github.com/caddy-dns/timeweb) |
| `dns.providers.cloudflare` | Cloudflare DNS | [caddy-dns/cloudflare](https://github.com/caddy-dns/cloudflare) |
| `dynamic_dns` | Авто-обновление A-записей | [caddy-dynamicdns](https://github.com/mholt/caddy-dynamicdns) |
| `http.handlers.rate_limit` | Rate limiting | [caddy-ratelimit](https://github.com/mholt/caddy-ratelimit) |
| `http.handlers.cloudflare_ip` | Реальный IP клиента за Cloudflare proxy | [caddy-cloudflare-ip](https://github.com/WeidiDeng/caddy-cloudflare-ip) |

## Быстрый старт

```bash
docker pull ghcr.io/webzaytsev/caddy-dns-pro:latest
# или
docker pull webzaytsev/caddy-dns-pro:latest
```

`docker-compose.yml`:

```yaml
services:
  caddy:
    image: ghcr.io/webzaytsev/caddy-dns-pro:latest
    restart: unless-stopped
    ports:
      - "80:80"
      - "443:443"
      - "443:443/udp"
    volumes:
      - ./Caddyfile:/etc/caddy/Caddyfile
      - caddy_data:/data
      - caddy_config:/config
    env_file: .env

volumes:
  caddy_data:
  caddy_config:
```

## DNS провайдеры

Все провайдеры используются только для DNS challenge при получении SSL-сертификатов. Открывать 80/443 порт наружу для получения сертификатов **не требуется**.

### Selectel

Переменные окружения:

```bash
SELECTEL_USER=your_service_user
SELECTEL_PASSWORD=your_service_password
SELECTEL_ACCOUNT_ID=123456
SELECTEL_PROJECT_NAME=your_project_name
```

> Используйте [Selectel Service User](https://my.selectel.ru/iam/users_management/users?type=service) с правами администратора в проекте.

Caddyfile:

```caddyfile
{
	acme_dns selectel {
		user {env.SELECTEL_USER}
		password {env.SELECTEL_PASSWORD}
		account_id {env.SELECTEL_ACCOUNT_ID}
		project_name {env.SELECTEL_PROJECT_NAME}
	}
}

example.com, *.example.com {
	reverse_proxy backend:8080
}
```

### Timeweb

Переменные окружения:

```bash
TIMEWEB_API_TOKEN=your_timeweb_api_token
```

Caddyfile:

```caddyfile
{
	acme_dns timeweb {env.TIMEWEB_API_TOKEN}
}

example.com, *.example.com {
	reverse_proxy backend:8080
}
```

### Cloudflare

Переменные окружения:

```bash
CLOUDFLARE_API_TOKEN=your_cloudflare_api_token
```

> Токен создаётся в [Cloudflare Dashboard](https://dash.cloudflare.com/profile/api-tokens) с правом `Zone / DNS / Edit`.

Caddyfile:

```caddyfile
{
	acme_dns cloudflare {env.CLOUDFLARE_API_TOKEN}
}

example.com, *.example.com {
	reverse_proxy backend:8080
}
```

## Cloudflare Real IP

Модуль `http.handlers.cloudflare_ip` восстанавливает реальный IP-адрес клиента из заголовка `CF-Connecting-IP`, подставляемого Cloudflare. Без него Caddy видит IP прокси-сервера Cloudflare, а не пользователя.

```caddyfile
{
	order cloudflare_ip first
}

example.com {
	cloudflare_ip
	reverse_proxy backend:8080
}
```

> Достаточно добавить директиву `cloudflare_ip` в блок сайта — модуль автоматически загрузит диапазоны IP Cloudflare и проверит, что запрос пришёл именно от их сети.

## Dynamic DNS

Модуль `dynamic_dns` автоматически создаёт и обновляет A-записи при изменении IP сервера. Полезно для серверов с динамическим IP.

### Директива `dynamic_domains`

При включении `dynamic_domains` модуль автоматически подхватывает все домены из Caddyfile, чьи зоны перечислены в блоке `domains`. Новый поддомен добавил в Caddyfile — A-запись создалась сама.

```caddyfile
{
	dynamic_dns {
		provider timeweb {env.TIMEWEB_API_TOKEN}
		domains {
			example.com @        # управляет корнем зоны
		}
		dynamic_domains          # подхватывает *.example.com из Caddyfile автоматически
		ip_source simple_http https://icanhazip.com
		check_interval 5m
		versions ipv4
	}

	acme_dns timeweb {env.TIMEWEB_API_TOKEN}
}

example.com {
	reverse_proxy localhost:3000
}

# A-запись для api.example.com создастся автоматически
api.example.com {
	reverse_proxy localhost:8080
}
```

> Домены из других зон (не перечисленных в `domains {}`) управляться не будут.

## Сборка

Локально:

```bash
docker build -t caddy-dns-pro:latest .
```

Автоматическая сборка через GitHub Actions запускается при push в `main`/`master`, по расписанию (каждое воскресенье) и вручную. При этом автоматически обновляется версия Caddy и версии всех xcaddy-модулей в Dockerfile.

> Версии модулей в Dockerfile закреплены явно (`--with module@vX.Y.Z`, либо коммитом для репозиториев без релизов). Это сделано намеренно: если версии не закреплены, Docker BuildKit кэширует шаг `xcaddy build` по тексту команды и не замечает, что апстрим-модуль обновился — образ годами собирается из старого кода, даже если CI формально проходит зелёным. Закреплённые версии автоматически бампаются тем же CI-шагом, что обновляет версию Caddy.

Образы публикуются в:
- `ghcr.io/webzaytsev/caddy-dns-pro`
- `webzaytsev/caddy-dns-pro`

Для публикации на Docker Hub настройте секрет `DOCKERHUB_TOKEN` в Settings → Secrets and variables → Actions.

## Ссылки

- [Caddy документация](https://caddyserver.com/docs/)
- [caddy-dns/selectel](https://github.com/caddy-dns/selectel)
- [caddy-dns/timeweb](https://github.com/caddy-dns/timeweb)
- [caddy-dns/cloudflare](https://github.com/caddy-dns/cloudflare)
- [caddy-dynamicdns](https://github.com/mholt/caddy-dynamicdns)
- [caddy-cloudflare-ip](https://github.com/WeidiDeng/caddy-cloudflare-ip)
- [Selectel DNS API v2](https://developers.selectel.ru/docs/cloud-services/dns_api/dns_api_actual/)
