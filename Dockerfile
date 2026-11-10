# Rocky Linux base (the client runs Red Hat family systems), packaged OpenJDK 21, non-root user.
FROM rockylinux/rockylinux:10

# Rocky's mirrorlist can pick a mirror that serves a few kB/s and stall the build; dl.rockylinux.org is fast from the lab.
# (Drop this RUN where the default mirrors are fine.)
RUN sed -i -E 's#^mirrorlist=.*[?&]repo=([A-Za-z]+)-\$releasever\$rltype$#baseurl=https://dl.rockylinux.org/pub/rocky/$releasever/\1/$basearch/os/#' /etc/yum.repos.d/rocky*.repo \
    && printf 'timeout=30\nretries=5\n' >> /etc/dnf/dnf.conf

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
