# FrankenPHP Bundle

This bundle contains everything needed to run the Symfony API inside Docker: the `php` FrankenPHP (Caddy) service with built-in TLS, a `php-worker` running `messenger:consume`, and a rich set of Make targets. It is the FrankenPHP counterpart to [make-apache-php](https://github.com/xebro-gmbh/make-apache-php). It **must be consumed through** `docker/core`, which adds the bundle to the global `Makefile` surface and wires its compose file into the shared network.

## Core Principles

- **Single entrypoint** – All commands (`make php.bash`, `make php.migrate`, etc.) are executed from the project root via the core `Makefile`.
- **Reproducible** – Targets scaffold environment variables, compose services, migrations, fixtures, and JWT keys so a new checkout boots with `make install && make init`.
- **Safe defaults** – The services are development-focused (mounted source tree, host networking, verbose logging). Do not deploy them outside of local environments.

## Installation & Daily Flow

```bash
make php.install   # ensure env vars and helper files exist
make php.init      # same as `make init`: composer install, migrations, fixtures, cache clear
make start         # bring up php along with other enabled bundles
```

When you need ad-hoc CLI access run `make php.bash`. To run Symfony console commands without opening a shell use `make php.cmd cmd='cache:clear'`.

## Key Targets

Runtime
- `php.bash` – Get an interactive shell inside the container.
- `php.logs` – Follow container logs.
- `php.docker.build` – Build the image from the bundle’s Dockerfile.
- `php.restart` – Restart the service (runs migrations+fixtures first).

Application Lifecycle
- `php.install` – Append bundle-specific values to `.env` and configure gitignore snippets (invoked by `make install`).
- `php.init` – Composer install (dev), migrate, load fixtures, clear cache, generate JWT keys.
- `php.assets`, `php.cmd`, `php.exec`, `php.cc`, `php.jwt_keys`.

Database
- `php.migrate`, `php.migration`, `php.fixtures`, `php.db`, `php.validate_db`.

Composer & Quality
- `php.composer.dev`, `php.composer.prod`.
- `php.cs-fixer`, `php.lint`, `php.stan`, `php.test`, `php.verify` (full suite), `fix`, `lint`, `ci`.

## Notes & Warnings

- `php.fixtures` truncates the database before loading fixtures; do not run it against persistent data you care about.
- `php.db` changes the schema directly; prefer migrations for anything beyond quick prototypes.
- The bundle expects `XO_ROOT_DIR`, `XO_PHP_ROOT`, and `DOCKER_COMPOSE` to be exported by the core. If the targets are missing, make sure your root `Makefile` is linked to `docker/core/main_file`.
- `make start` generates a local TLS certificate (mkcert if available) for `${XO_SERVER_NAME:-localhost}` and mounts it at `/cert`; FrankenPHP serves HTTPS on `${XO_PHP_TLS_PORT:-443}` and HTTP on `${XO_PHP_PORT:-80}`.
- With parallel instances (see the core README) all instances on a machine share the image tag from `XO_PHP_IMAGE`: a rebuild in one instance reaches the others on their next container recreate. When changing the Dockerfile, set a private `XO_PHP_IMAGE` in your `.env.local` to keep other instances unaffected.

## License

This make bundle is provided under the MIT License. See the [LICENSE](./LICENSE) file for details.

Part of the [make-core](https://github.com/xebro-gmbh/make-core) system.

Copyright (c) 2026 xebro GmbH
