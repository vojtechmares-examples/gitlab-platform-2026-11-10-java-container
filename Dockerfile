# Rocky Linux base (the client runs Red Hat family systems), packaged OpenJDK 21, non-root user.
FROM rockylinux/rockylinux:10

RUN dnf -y --setopt=install_weak_deps=False install java-21-openjdk-headless \
    && dnf clean all \
    && rm -rf /var/cache/dnf \
    && useradd --system --uid 10001 --home-dir /app --shell /sbin/nologin app

ARG BUILD_ID=local
LABEL org.opencontainers.image.title="java-container" \
      org.opencontainers.image.description="Spring Boot demo (examples group)" \
      org.opencontainers.image.revision="${BUILD_ID}"

WORKDIR /app
COPY --chown=app:app target/app.jar /app/app.jar

USER app
EXPOSE 8080
ENTRYPOINT ["java", "-XX:MaxRAMPercentage=60", "-jar", "/app/app.jar"]
