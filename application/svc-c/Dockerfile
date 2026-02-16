FROM eclipse-temurin:17-jre-alpine AS runtime

WORKDIR /app

COPY target/svc-c-*.jar app.jar

EXPOSE 8080

HEALTHCHECK --interval=30s --timeout=3s --retries=3 \
  CMD wget -qO- http://localhost:8080/actuator/health || exit 1

ENTRYPOINT ["java", "-jar", "app.jar"]
