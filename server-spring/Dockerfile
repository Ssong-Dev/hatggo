# 1단계: 빌드 스테이지
FROM eclipse-temurin:17-jdk-alpine AS build
WORKDIR /app

# Gradle 래퍼 및 빌드 설정 파일 복사
COPY gradlew .
COPY gradle gradle
COPY build.gradle .
COPY settings.gradle .

# 실행 권한 부여 및 의존성 다운로드 (캐시 활용)
RUN chmod +x gradlew
RUN ./gradlew dependencies --no-daemon || true

# 소스 코드 복사 및 빌드 진행
COPY src src
RUN ./gradlew clean build -x test --no-daemon

# 2단계: 실행 스테이지 (경량 JRE 이미지 사용)
FROM eclipse-temurin:17-jre-alpine
WORKDIR /app

# 빌드 스테이지에서 생성된 jar 파일 복사
COPY --from=build /app/build/libs/*.jar app.jar

# 환경변수 포트 바인딩 설정 및 컨테이너 노출 포트 설정
ENV PORT=3000
EXPOSE 3000

# 애플리케이션 실행
ENTRYPOINT ["java", "-jar", "-Dserver.port=${PORT}", "app.jar"]
