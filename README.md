# Sidecar Cron

A Docker sidecar container that runs scheduled jobs via cron alongside your main service.

## ✨ Features

- Minimal cron runtime built on `python:3.11-slim-trixie`, with `cron`, Python and common CLI tools
- System-wide crontab (`/etc/crontab`) and `run-parts` schedules (`cron.hourly`/`daily`/`weekly`/`monthly`) synced at startup from mounted config/script volumes
- User-editable schedules through mounted `cron.d`, periodic script and custom script volumes - no image rebuild needed
- Bundled example jobs (`echo.sh`, `hello.py`, `backup.sh`) for smoke testing
- Docker CLI and Compose plugin available inside the container
- `compose.sh` helper CLI plus `Makefile` targets for day-to-day operations
- Versioning, build, release and changelog scripts with GitHub Actions CI/CD

---

## 🐤 Getting Started

### 1. 🚧 Prerequisites

- Install [**docker** and **docker compose**](https://docs.docker.com/engine/install) in **server**
- A cron job to schedule, as one of:
    - cron files inside `./volumes/configs/cron/cron.d` directory
    - custom scripts inside `./volumes/configs/cron/scripts` directory
    - or an executable script for `run-parts` inside `./volumes/configs/cron/periodic/cron.*/` directories
- Familiarity with [cron syntax](https://uptimerobot.com/knowledge-hub/cron-monitoring/cron-expressions-complete-guide) if you plan to edit [schedules](https://crontab.guru)

For **DEVELOPMENT**:

- Install [**git**](https://git-scm.com/downloads)
- Setup an [**SSH key**](https://docs.github.com/en/github/authenticating-to-github/connecting-to-github-with-ssh)

### 2. 📥 Download or clone the repository

```sh
mkdir -pv ~/workspaces/projects
cd ~/workspaces/projects

# HTTPS:
git clone https://github.com/humblebeeai/sidecar-cron.git
# Or SSH (development):
git clone git@github.com:humblebeeai/sidecar-cron.git

cd sidecar-cron
```

Alternatively, download the source from the [releases](https://github.com/humblebeeai/sidecar-cron/releases) page.

### 3. 🛠 Configure the environment

[TIP] Skip this step, if you've already configured environment or run with the default configuration.

#### 3.1. 🌎 Configure **`.env`** (environment variables) file

```sh
# Copy .env.example file into .env file:
cp -v ./.env.example ./.env

# Edit environment variables to fit in your environment:
nano ./.env
```

#### 3.2. 🎺 Configure **`compose.override.yml`** file

[TIP] Skip this step, if you want run with default configuration!

You can use below template **`compose.override.yml`** files for different environments:

- **DEVELOPMENT**: [templates/compose/compose.override.dev.yml](./templates/compose/compose.override.dev.yml)
- **PRODUCTION/STAGING**: [templates/compose/compose.override.prod.yml](./templates/compose/compose.override.prod.yml)

```sh
# Copy 'compose.override.[ENV].yml' file to 'compose.override.yml' file:
cp -v ./templates/compose/compose.override.[ENV].yml ./compose.override.yml
# For example, DEVELOPMENT environment:
cp -v ./templates/compose/compose.override.dev.yml ./compose.override.yml
# For example, STAGING or PRODUCTION environment:
cp -v ./templates/compose/compose.override.prod.yml ./compose.override.yml

# Edit 'compose.override.yml' file to fit in your environment:
nano ./compose.override.yml
```

#### 3.3. ✅ Validate the docker compose configuration

**[WARNING]** If you get an error or warning, check your configuration files (**`.env`** or **`compose.override.yml`**).

```sh
./compose.sh validate
# Or:
docker compose config
```

### 4. ⏰ Add your cron jobs

Drop jobs into the mounted volumes:

- **Custom scripts** -> `./volumes/configs/cron/scripts/` (mounted at `/app/cron/scripts/custom`)
- **Extra cron entries** -> `./volumes/configs/cron/cron.d/` (mounted at `/app/cron/configs/cron.d`)
- **Periodic scripts** -> `./volumes/configs/cron/periodic/cron.{hourly,daily,weekly,monthly}/` (mounted at `/app/cron/scripts/periodic/...`)
- **Job logs** -> `./volumes/storage/cron/logs/` (mounted at `/var/log/cron`)

Example `./volumes/configs/cron/cron.d/test` file:

```cron
* * * * * root /app/cron/scripts/custom/test.sh >> /var/log/cron/test.log 2>&1
```

Example `./volumes/configs/cron/scripts/test.sh` file:

```sh
#!/usr/bin/env bash
echo "[INFO]: Tested cron job at - $(date '+%Y-%m-%dT%H:%M:%S%z')."
```

### 5. 🚀 Start docker compose

```sh
./compose.sh start -l
# Or:
docker compose up -d --remove-orphans --force-recreate && \
    docker compose logs -f -n 100
```

On startup the entrypoint syncs the mounted `cron.d` files, periodic scripts and custom crontab into `/etc/`, validates `/etc/crontab` and every `/etc/cron.d/*` file, then runs `cron` in the foreground under `tini`.

### 6. 📡 Monitor the service

```sh
./compose.sh list    # or: docker compose ps
./compose.sh logs    # or: docker compose logs -f -n 100
./compose.sh ps      # or: docker compose top
./compose.sh stats   # or: docker compose stats
./compose.sh enter   # or: docker compose exec cron /bin/bash
```

### 7. 🪂 Stop docker compose

```sh
./compose.sh stop
# Or:
docker compose down --remove-orphans
```

---

## ⚙️ Configuration

### ⏰ Cron scheduling

The system crontab lives in [`src/configs/crontab`](./src/configs/crontab) and is copied to `/etc/crontab` at startup. Its default `run-parts` schedule:

```cron
SHELL=/bin/bash
PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin

17 *  * * *  root  cd / && run-parts --report /etc/cron.hourly
25 6  * * *  root  test -x /usr/sbin/anacron || { cd / && run-parts --report /etc/cron.daily; }
47 6  * * 7  root  test -x /usr/sbin/anacron || { cd / && run-parts --report /etc/cron.weekly; }
52 6  1 * *  root  test -x /usr/sbin/anacron || { cd / && run-parts --report /etc/cron.monthly; }
```

### 📁 Runtime paths and volumes

| Host path | Container path | Purpose |
| --------------------------------- | -------------------------- | ------------------ |
| `./volumes/configs/cron/scripts/` | `/app/cron/scripts/custom/` | Custom job scripts |
| `./volumes/configs/cron/cron.d/` | `/app/cron/configs/cron.d/` | Additional cron files |
| `./volumes/configs/cron/periodic/cron.{hourly,daily,weekly,monthly}/` | `/app/cron/scripts/periodic/cron.*/` | `run-parts` scripts |
| `./volumes/storage/cron/logs/` | `/var/log/cron/` | Cron job logs |

Copied into the image from `src/`:

| Source path                           | Destination path                     |
| ------------------------------------- | ------------------------------------ |
| `src/scripts/`                        | `/app/cron/scripts/`                 |
| `src/scripts/periodic/cron.*/`        | `/app/cron/scripts/periodic/cron.*/` |
| `src/configs/crontab`                 | `/app/cron/configs/crontab`          |
| `src/configs/cron.d/`                 | `/app/cron/configs/cron.d/`          |
| `scripts/docker/docker-entrypoint.sh` | `/usr/local/bin/docker-entrypoint.sh`|

At container startup the entrypoint copies the periodic scripts into `/etc/cron.{hourly,daily,weekly,monthly}/`, the `cron.d` files into `/etc/cron.d/`, and the `crontab` into `/etc/crontab` before launching `cron`.

### 🌎 Environment variables

| Variable          | Required | Default                         | Description                                |
| ----------------- | -------- | ------------------------------- | ------------------------------------------ |
| `TZ`              | No       | `Asia/Seoul`                    | Container timezone                         |

`backup.sh` uses `STORAGE_DIR` (default `/var/lib/storage`), `BACKUPS_DIR` (default `/var/lib/backups`), `BACKUP_UID` (default `1000`) and `BACKUP_GID` (default `11000`).

---

## 🧪 Examples

Bundled jobs live in [`src/scripts`](./src/scripts):

**`echo.sh`**

```sh
#!/usr/bin/env bash
set -euo pipefail

echo "[INFO]: Cron job executed at - $(date '+%Y-%m-%dT%H:%M:%S%z')."
```

**`hello.py`**

```py
#!/usr/bin/env python3
from potato_util.dt import now_utc_dt
from beans_logging.auto import logger

def main() -> None:
    logger.info(f"Hello world - {now_utc_dt().isoformat()}")
    return

if __name__ == "__main__":
    main()
```

Enable the example jobs by uncommenting the sample entries in the [system crontab](./src/configs/crontab):

```cron
# * * * * * root /app/cron/scripts/echo.sh >> /var/log/cron/echo.log 2>&1
# * * * * * root /app/cron/scripts/hello.py >> /var/log/cron/hello.log 2>&1
# 0 1 1 * * root /app/cron/scripts/backup.sh >> /var/log/cron/backup.log 2>&1
```

---

## 🏗 Build

```sh
./scripts/build.sh
# Or:
./compose.sh build
```

---

## 📚 Documentation

- [Docs](./docs)
- [Release Notes](./docs/release-notes.md)
- [Changelog](./CHANGELOG.md)

---

## 📑 References

- <https://man7.org/linux/man-pages/man8/cron.8.html>
- <https://man7.org/linux/man-pages/man5/crontab.5.html>
- <https://crontab.guru>
- <https://github.com/krallin/tini>
- <https://docs.docker.com>
- <https://docs.docker.com/compose>
- <https://uptimerobot.com/knowledge-hub/cron-monitoring/cron-expressions-complete-guide>
