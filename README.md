# Caddy with Selectel DNS Plugin

Docker образ Caddy с предустановленными DNS плагинами для автоматического управления DNS-записями через Selectel DNS API v2, Cloudflare и Dynamic DNS.

## Обзор

Этот проект предоставляет готовый Docker образ [Caddy](https://caddyserver.com/) с включенными модулями:

- **caddy-selectel** - модуль для работы с Selectel DNS API v2
- **caddy-dns/cloudflare** - модуль для Cloudflare DNS
- **caddy-dynamicdns** - модуль для динамического обновления DNS-записей

Образ автоматически обновляется до последней версии Caddy каждую неделю (воскресенье) через GitHub Actions.

## Структура проекта

```
.
├── Dockerfile                      # Мультистейдж сборка Caddy с плагинами | builder stage, runtime stage
└── .github/
    └── workflows/
        └── build.yml               # CI/CD pipeline для сборки образа | version check, docker build, registry push
```

## Использование

### Получение образа

Образ доступен в GitHub Container Registry и Docker Hub:

**GitHub Container Registry:**
```bash
docker pull ghcr.io/webzaytsev/caddy-selectel-docker:latest
```

**Docker Hub:**
```bash
docker pull webzaytsev/caddy-selectel-docker:latest
```

### Запуск контейнера

#### Базовый запуск

```bash
docker run -d \
  --name caddy \
  -p 80:80 -p 443:443 -p 443:443/udp \
  -v $(pwd)/Caddyfile:/etc/caddy/Caddyfile \
  -v caddy_data:/data \
  -v caddy_config:/config \
  ghcr.io/webzaytsev/caddy-selectel-docker:latest
```

### Конфигурация для Selectel DNS

#### JSON конфигурация

Для использования Selectel DNS в ACME DNS challenge, настройте ACME issuer в JSON конфигурации Caddy:

```json
{
  "module": "acme",
  "challenges": {
    "dns": {
      "provider": {
        "name": "selectel",
        "user": "SELECTEL_USER",
        "password": "SELECTEL_PASSWORD",
        "account_id": "SELECTEL_ACCOUNT_ID",
        "project_name": "SELECTEL_PROJECT_NAME"
      }
    }
  }
}
```

#### Caddyfile конфигурация

**Глобальная настройка:**

```caddyfile
{
	acme_dns selectel {
		user {env.SELECTEL_USER}
		password {env.SELECTEL_PASSWORD}
		account_id {env.SELECTEL_ACCOUNT_ID}
		project_name {env.SELECTEL_PROJECT_NAME}
	}
}

example.com {
	tls {
		dns selectel
	}
}
```

**Настройка для одного сайта:**

```caddyfile
example.com {
	tls {
		dns selectel {
			user {env.SELECTEL_USER}
			password {env.SELECTEL_PASSWORD}
			account_id {env.SELECTEL_ACCOUNT_ID}
			project_name {env.SELECTEL_PROJECT_NAME}
		}
	}
	
	respond "Hello from Caddy!"
}
```

#### Переменные окружения

Создайте файл `.env` или передайте переменные окружения в контейнер:

```bash
SELECTEL_USER=your_service_user
SELECTEL_PASSWORD=your_service_password
SELECTEL_ACCOUNT_ID=123456
SELECTEL_PROJECT_NAME=your_project_name
```

Запуск с переменными окружения:

```bash
docker run -d \
  --name caddy \
  -p 80:80 -p 443:443 \
  --env-file .env \
  -v $(pwd)/Caddyfile:/etc/caddy/Caddyfile \
  -v caddy_data:/data \
  -v caddy_config:/config \
  ghcr.io/webzaytsev/caddy-selectel-docker:latest
```

### Docker Compose

Пример `docker-compose.yml`:

```yaml
version: '3.8'

services:
  caddy:
    image: ghcr.io/webzaytsev/caddy-selectel-docker:latest
    container_name: caddy
    restart: unless-stopped
    ports:
      - "80:80"
      - "443:443"
      - "443:443/udp"
    volumes:
      - ./Caddyfile:/etc/caddy/Caddyfile
      - caddy_data:/data
      - caddy_config:/config
    environment:
      - SELECTEL_USER=${SELECTEL_USER}
      - SELECTEL_PASSWORD=${SELECTEL_PASSWORD}
      - SELECTEL_ACCOUNT_ID=${SELECTEL_ACCOUNT_ID}
      - SELECTEL_PROJECT_NAME=${SELECTEL_PROJECT_NAME}

volumes:
  caddy_data:
  caddy_config:
```

## Авторизация Selectel

Для авторизации необходимо использовать [Selectel Service User](https://my.selectel.ru/iam/users_management/users?type=service) с правами администратора в проекте.

Требуемые параметры:

- **user** - имя сервисного пользователя Selectel
- **password** - пароль сервисного пользователя
- **account_id** - идентификатор основного аккаунта Selectel (например, "123456")
- **project_name** - название проекта, в котором сервисный пользователь является администратором

## Сборка образа

### Локальная сборка

```bash
docker build -t caddy-selectel:latest .
```

### Автоматическая сборка

Образ автоматически собирается через GitHub Actions при:

- Push в ветки `main` или `master`
- Создании Pull Request
- Ручном запуске workflow
- Еженедельном расписании (каждое воскресенье в 00:00 UTC)

При запуске по расписанию или вручную workflow автоматически проверяет наличие новой версии Caddy и обновляет Dockerfile.

**Публикация образов:**

Образы автоматически публикуются в:
- **GitHub Container Registry** (`ghcr.io/webzaytsev/caddy-selectel-docker`)
- **Docker Hub** (`webzaytsev/caddy-selectel-docker`)

Для публикации на Docker Hub требуется настроить секрет `DOCKERHUB_TOKEN` в настройках репозитория GitHub (Settings → Secrets and variables → Actions).

## Модули

### dns.providers.selectel

Модуль для управления DNS-записями через Selectel DNS API v2. Подробнее: [caddy-selectel](https://github.com/WEBzaytsev/caddy-selectel)

**Особенности:**

- Debug логирование включено по умолчанию
- Все DNS операции отображаются в логах Caddy
- Поддержка всех типов DNS-записей через Selectel API v2

### dynamicdns

Модуль для автоматического обновления DNS-записей при изменении IP-адреса сервера. Подробнее: [caddy-dynamicdns](https://github.com/mholt/caddy-dynamicdns)

**Особенности:**

- Поддержка различных DNS-провайдеров, включая Selectel
- Автоматическое определение публичного IP-адреса
- Настраиваемый интервал проверки изменений
- Поддержка множественных доменов

**Поддерживаемые провайдеры:**

- Selectel (через caddy-selectel)
- Cloudflare
- И другие провайдеры, поддерживающие libdns

### Другие модули

- **cloudflare** - модуль для работы с Cloudflare DNS

## Примеры использования

### Получение SSL сертификата через DNS challenge

```caddyfile
*.example.com {
	tls {
		dns selectel {
			user {env.SELECTEL_USER}
			password {env.SELECTEL_PASSWORD}
			account_id {env.SELECTEL_ACCOUNT_ID}
			project_name {env.SELECTEL_PROJECT_NAME}
		}
	}
	
	reverse_proxy backend:8080
}
```

### Использование с несколькими доменами

```caddyfile
{
	acme_dns selectel {
		user {env.SELECTEL_USER}
		password {env.SELECTEL_PASSWORD}
		account_id {env.SELECTEL_ACCOUNT_ID}
		project_name {env.SELECTEL_PROJECT_NAME}
	}
}

example.com, www.example.com {
	tls
	reverse_proxy backend:8080
}

api.example.com {
	tls
	reverse_proxy api:3000
}
```

### Использование Dynamic DNS с Selectel

Модуль `dynamicdns` позволяет автоматически обновлять DNS-записи при изменении IP-адреса сервера. Это особенно полезно для серверов с динамическим IP-адресом.

**Пример конфигурации с Dynamic DNS и Selectel:**

```caddyfile
{
	# Глобальная настройка Dynamic DNS
	dynamic_dns {
		provider selectel {
			user {env.SELECTEL_USER}
			password {env.SELECTEL_PASSWORD}
			account_id {env.SELECTEL_ACCOUNT_ID}
			project_name {env.SELECTEL_PROJECT_NAME}
		}
		domains {
			example.com
			www.example.com
			api.example.com
		}
		ip_source public
		check_interval 5m
		ttl 300
	}
}

example.com {
	tls {
		dns selectel {
			user {env.SELECTEL_USER}
			password {env.SELECTEL_PASSWORD}
			account_id {env.SELECTEL_ACCOUNT_ID}
			project_name {env.SELECTEL_PROJECT_NAME}
		}
	}
	
	reverse_proxy backend:8080
}
```

**Параметры Dynamic DNS:**

- `provider selectel` - использует Selectel в качестве DNS-провайдера для обновления записей
- `domains` - список доменов, для которых будут обновляться A-записи
- `ip_source` - источник IP-адреса:
  - `public` - автоматическое определение публичного IP через внешние сервисы
  - `http://ip-service-url` - использование кастомного сервиса для определения IP
- `check_interval` - интервал проверки изменений IP (например, `5m`, `10m`, `1h`)
- `ttl` - время жизни DNS-записи в секундах (по умолчанию 300)

**Комбинированное использование:**

Можно использовать Dynamic DNS для обновления A-записей и одновременно использовать Selectel для получения SSL-сертификатов:

```caddyfile
{
	dynamic_dns {
		provider selectel {
			user {env.SELECTEL_USER}
			password {env.SELECTEL_PASSWORD}
			account_id {env.SELECTEL_ACCOUNT_ID}
			project_name {env.SELECTEL_PROJECT_NAME}
		}
		domains {
			home.example.com
		}
		ip_source public
		check_interval 10m
	}
	
	acme_dns selectel {
		user {env.SELECTEL_USER}
		password {env.SELECTEL_PASSWORD}
		account_id {env.SELECTEL_ACCOUNT_ID}
		project_name {env.SELECTEL_PROJECT_NAME}
	}
}

home.example.com {
	tls
	reverse_proxy localhost:8080
}

api.example.com {
	tls
	reverse_proxy api:3000
}
```

В этом примере:
- `home.example.com` будет автоматически обновлять свою A-запись при изменении IP
- Оба домена будут использовать Selectel для получения SSL-сертификатов через DNS challenge

**Важные замечания:**

1. Dynamic DNS обновляет только A-записи (IPv4). Для IPv6 используйте AAAA-записи (требует дополнительной настройки)
2. Убедитесь, что у сервисного пользователя Selectel есть права на изменение DNS-записей для указанных доменов
3. Интервал проверки не должен быть слишком частым, чтобы не перегружать API Selectel
4. Dynamic DNS работает независимо от получения SSL-сертификатов - это два разных процесса

## Благодарности

Этот проект использует следующие модули:

- [caddy-selectel](https://github.com/WEBzaytsev/caddy-selectel) - модуль Selectel DNS для Caddy
- [caddy-dns/cloudflare](https://github.com/caddy-dns/cloudflare) - модуль Cloudflare DNS
- [caddy-dynamicdns](https://github.com/mholt/caddy-dynamicdns) - модуль динамического DNS

## Ссылки

- [Caddy документация](https://caddyserver.com/docs/)
- [Selectel DNS API v2](https://developers.selectel.ru/docs/cloud-services/dns_api/dns_api_actual/)
- [Selectel Service User управление](https://my.selectel.ru/iam/users_management/users?type=service)
- [caddy-selectel GitHub](https://github.com/WEBzaytsev/caddy-selectel)
- [selectel-libdns GitHub](https://github.com/WEBzaytsev/selectel-libdns)

