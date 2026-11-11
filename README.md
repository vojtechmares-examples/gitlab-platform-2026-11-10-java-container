# java-container

Spring Boot application (JDBC, Flyway, PostgreSQL) deployed to a Linux server as a **container**, run by a hand-written
**systemd unit** that calls `docker run` (Docker, not Podman).

| Topic | How |
|-------|-----|
| Image | `Dockerfile`: Rocky Linux 10 + packaged OpenJDK 21, non-root user; built with Docker-in-Docker and pushed to the **GitLab Container Registry** (`registry.maresdemo.com/examples/java-container:<pipeline id>`) |
| Tests | JUnit; `MigrationsTest` starts the application against a PostgreSQL **job service** (`services:`), pulled through the group's Dependency Proxy |
| Database migrations | Flyway, **when the application starts**, not in the pipeline |
| Deploy | over SSH: `docker login` with the project's **deploy token** (`gitlab-deploy-token`, scope `read_registry`), `docker pull`, write `IMAGE=...` to `/var/lib/examples/java-container/<env>/image.env`, `systemctl restart` |
| Run | `java-container-<env>.service` (Ansible project): `ExecStart=/usr/bin/docker run --rm --name ... --publish 127.0.0.1:<port>:8080 --env-file ... ${IMAGE}` |
| HTTPS | Caddy: https://java-container-staging.examples.maresdemo.com, https://java-container-production.examples.maresdemo.com |
| Environments | `staging` (automatic on `main`), `production` (manual job; protected environment) |
| Rollback | manual `rollback:<env>` job: the previous `image.env` is kept, the previous image is still on the server |

## CI configuration

The pipeline reads the CI/CD variables below (*Settings > CI/CD > Variables*). Variables that start with `CI_` are predefined by GitLab.

| Variable | Set on | Type | Used for |
|----------|--------|------|----------|
| `DEPLOY_HOST` | group `examples` | Variable | Address of the deploy server |
| `DEPLOY_SSH_PORT` | group `examples` | Variable | SSH port of the deploy server (`6022`) |
| `DEPLOY_USER` | group `examples` | Variable | Account the pipelines log in as (`deploy`) |
| `SSH_KNOWN_HOSTS` | group `examples` | Variable | Host keys of the deploy server; the connection uses `StrictHostKeyChecking yes` |
| `SSH_PRIVATE_KEY` | group `examples` | File, **protected** | Private key of the `deploy` account |
| `EXAMPLES_DOMAIN` | group `examples` | Variable | Parent domain of the applications (`examples.maresdemo.com`); `deploy/release.sh` waits for `https://java-container-<env>.$EXAMPLES_DOMAIN` |
| `CI_DEPLOY_USER`, `CI_DEPLOY_PASSWORD` | deploy token of this project | Predefined, from the token named **`gitlab-deploy-token`** (scope `read_registry`) | `deploy/release.sh` logs in to the Container Registry on the server with it. Create the token in *Settings > Repository > Deploy tokens*; the name must be exactly `gitlab-deploy-token` |

The group variables are inherited by every project in the `examples` group, so nothing has to be set for them here. The `.ssh-setup` snippet of `examples/ci-templates` turns the first five into `ssh deploy`.
A **protected** variable is passed only to pipelines on protected branches and tags (`main`), which is where the deploy jobs run.

The pipeline does not read a database password. Flyway connects when the application starts, with the password in `/etc/examples/java-container-<env>.env`, which the `ansible` project writes from its variable `DB_PASSWORD_JAVA_CONTAINER`. The `test` job uses a throwaway PostgreSQL service with the credentials written in `.gitlab-ci.yml`.
