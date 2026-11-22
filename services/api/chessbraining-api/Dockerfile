# syntax=docker/dockerfile:1

FROM eclipse-temurin:21-jdk-jammy AS build
WORKDIR /workspace

COPY .mvn .mvn
COPY mvnw pom.xml ./
RUN chmod +x mvnw && ./mvnw -B -DskipTests dependency:go-offline

COPY src src
RUN ./mvnw -B -Dmaven.test.skip=true package

FROM eclipse-temurin:21-jre-jammy
WORKDIR /app

# The official generic x86-64 release avoids AVX-specific CPU requirements.
# Keep its bundled source and GPL notice with the redistributed executable.
RUN apt-get update && apt-get install -y --no-install-recommends ca-certificates curl tar \
    && mkdir -p /opt/stockfish \
    && curl -fL --retry 3 -o /tmp/stockfish.tar https://github.com/official-stockfish/Stockfish/releases/download/sf_17.1/stockfish-ubuntu-x86-64.tar \
    && echo '4dafdd04f71e70755a327b5be258937b281e60ba87bc0a5801399908240d4a73  /tmp/stockfish.tar' | sha256sum -c - \
    && tar -xf /tmp/stockfish.tar -C /opt/stockfish --strip-components=1 && rm /tmp/stockfish.tar \
    && /opt/stockfish/stockfish-ubuntu-x86-64 bench 16 1 4 default depth > /dev/null 2>&1 \
    && apt-get purge -y curl && apt-get autoremove -y && rm -rf /var/lib/apt/lists/* \
    && useradd --create-home --shell /usr/sbin/nologin appuser
ENV STOCKFISH_PATH=/opt/stockfish/stockfish-ubuntu-x86-64 \
    STOCKFISH_REQUIRED=true \
    STOCKFISH_HASH_MB=32
COPY --from=build /workspace/target/*.jar /app/chessbraining-api.jar

USER appuser
EXPOSE 8080

ENTRYPOINT ["java", "-jar", "/app/chessbraining-api.jar"]
