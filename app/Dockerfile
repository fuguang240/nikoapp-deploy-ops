# 多阶段构建：temurin 编译 jar，centos:stream10 运行
FROM eclipse-temurin:17-jdk AS build
WORKDIR /build
COPY src ./src
RUN javac -d out src/com/nikoapp/App.java \
    && jar --create --file app.jar --main-class com.nikoapp.App -C out .

FROM centos:stream10
RUN dnf -y install java-17-openjdk-headless \
    && dnf clean all
WORKDIR /app
COPY --from=build /build/app.jar /app/app.jar
EXPOSE 8080
CMD ["java", "-jar", "/app/app.jar"]
