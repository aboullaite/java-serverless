ARG MVN_VERSION=3.9.6
ARG JDK_VERSION=21
ARG RUNTIME_IMAGE="/opt/java-runtime"
ARG APP_DIR="/app"

FROM maven:${MVN_VERSION}-eclipse-temurin-${JDK_VERSION} as MAVEN_TOOL_CHAIN_CACHE
ARG TARGETPLATFORM
ARG BUILDPLATFORM
ARG RUNTIME_IMAGE
ARG APP_DIR
ARG JDK_VERSION

WORKDIR /build
COPY pom.xml .
RUN mvn dependency:go-offline

COPY ./pom.xml ${APP_DIR}/pom.xml
COPY ./src ${APP_DIR}/src/
COPY ./BOOT-INF ${APP_DIR}/BOOT-INF/
WORKDIR ${APP_DIR}
RUN mvn clean package

# Install objcopy for jlink
RUN <<EOT
    # set -o errexit -o nounset -o errtrace -o pipefail
    set -eux
    echo "Building jlink custom image using Java ${JDK_VERSION} for ${TARGETPLATFORM} on ${BUILDPLATFORM}"
    DEBIAN_FRONTEND=noninteractive
    apt -y update
    apt -y upgrade
    apt -y install \
           --no-install-recommends \
           binutils curl \
           tzdata locales ca-certificates
    # wget procps vim unzip \
    # freetype fontconfig \
    # make gcc g++ libc++-dev \
    # openssl gnupg libssl-dev libcrypto++-dev libz.a \
    # software-properties-common

    rm -rf /var/lib/apt/lists/* /tmp/*
    apt -y clean
EOT


RUN <<EOT
 set -eux
 echo "Getting JDK module dependencies..."
 jdeps -q \
       -R \
       --ignore-missing-deps \
       --print-module-deps \
       --multi-release=${JDK_VERSION} \
       --class-path 'BOOT-INF/lib/*' \
       target/*.jar > java.modules
 cat java.modules
 echo "Creating custom JDK runtime image in ${RUNTIME_IMAGE}..."
 INCUBATOR_MODULES=$(java --list-modules | grep -i incubator | sed 's/@.*//' | paste -sd "," - )
 $JAVA_HOME/bin/jlink \
          --verbose \
          --module-path ${JAVA_HOME}/jmods \
          --add-modules="$(cat java.modules)" \
          --compress=zip-9 \
          --strip-debug \
          --strip-java-debug-attributes \
          --no-man-pages \
          --no-header-files \
          --save-opts "${APP_DIR}/jlink.opts" \
          --generate-cds-archive \
          --output ${RUNTIME_IMAGE}
EOT

RUN <<EOT
  echo "Creating dynamic CDS archive by running the app..."
  nohup ${RUNTIME_IMAGE}/bin/java \
        -XX:+AutoCreateSharedArchive \
        -XX:SharedArchiveFile=${APP_DIR}/app.jsa \
        -jar ${APP_DIR}/target/chatbot-0.0.1-SNAPSHOT.jar & \
  sleep 2 && \
  curl -fsSL --retry 5 --retry-delay 2 --retry-all-errors http://localhost:8081/actuator/health/readiness
  curl -fsSL -X POST http://localhost:8081/actuator/shutdown ||  echo "App CDS archive generation completed!"
  # Give some time to generate the CDS archive
  sleep 5
EOT

FROM gcr.io/distroless/java-base-debian12

ARG APP_DIR
ARG RUNTIME_IMAGE
ENV JAVA_HOME=${RUNTIME_IMAGE}

USER nonroot:nonroot
COPY --from=MAVEN_TOOL_CHAIN_CACHE --chown=nonroot:nonroot $JAVA_HOME $JAVA_HOME
COPY --from=MAVEN_TOOL_CHAIN_CACHE --chown=nonroot:nonroot ${APP_DIR}/target/chatbot-0.0.1-SNAPSHOT.jar /chatbot-0.0.1.jar
COPY --from=MAVEN_TOOL_CHAIN_CACHE --chown=nonroot:nonroot ${APP_DIR}/app.jsa /app.jsa
EXPOSE 8080
EXPOSE 8081
EXPOSE 8778
EXPOSE 9779

ENV _JAVA_OPTIONS "-XX:MinRAMPercentage=60.0 -XX:MaxRAMPercentage=90.0 \
-XX:+AutoCreateSharedArchive" \
-XX:SharedArchiveFile=app.jsa" \
-Djava.security.egd=file:/dev/./urandom \
-Djava.awt.headless=true -Dfile.encoding=UTF-8 \
-Dspring.output.ansi.enabled=ALWAYS \
-Dspring.profiles.active=default"

ENTRYPOINT ["/opt/java-runtime/bin/java", "-jar", "/chatbot-0.0.1.jar"]