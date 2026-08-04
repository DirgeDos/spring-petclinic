FROM eclipse-temurin:17-jre

WORKDIR /app

COPY target/spring-petclinic-*.jar app.jar

RUN mkdir -p /app/logs /app/dumps

EXPOSE 8080

ENTRYPOINT ["java", \
  "-Xms512m", \
  "-Xmx512m", \
  "-XX:MetaspaceSize=128m", \
  "-XX:MaxMetaspaceSize=256m", \
  "-XX:+UseG1GC", \
  "-XX:MaxGCPauseMillis=200", \
  "-XX:+HeapDumpOnOutOfMemoryError", \
  "-XX:+ExitOnOutOfMemoryError", \
  "-XX:HeapDumpPath=/app/dumps/", \
  "-Xlog:gc*:file=/app/logs/gc.log:time,uptime,level,tags:filecount=5,filesize=10m", \
  "-Dfile.encoding=UTF-8", \
  "-Duser.timezone=Asia/Shanghai", \
  "-Djava.security.egd=file:/dev/./urandom", \
  "-jar", "app.jar"]
