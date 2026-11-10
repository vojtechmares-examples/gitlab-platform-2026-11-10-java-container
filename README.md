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
