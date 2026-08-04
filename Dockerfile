FROM eclipse-temurin:17-jre

WORKDIR /app

COPY target/spring-petclinic-*.jar app.jar

RUN mkdir -p /app/logs /app/dumps

EXPOSE 8080

ENTRYPOINT ["java", \
  "-Xms256m", \
  "-Xmx512m", \
  "-XX:+UseG1GC", \
  "-XX:MaxGCPauseMillis=200", \
  "-XX:G1NewSizePercent=20", \
  "-XX:G1MaxNewSizePercent=50", \
  "-XX:+HeapDumpOnOutOfMemoryError", \
  "-XX:HeapDumpPath=/app/dumps/", \
  "-Xlog:gc*:file=/app/logs/gc.log:time,uptime,level,tags:filecount=5,filesize=10m", \
  "-Dfile.encoding=UTF-8", \
  "-Duser.timezone=Asia/Shanghai", \
  "-jar", "app.jar"]
