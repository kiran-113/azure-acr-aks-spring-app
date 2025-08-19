# Use official OpenJDK 17 base image
FROM openjdk:17

# Create app directory
WORKDIR /usr/app

# Copy the Spring Boot jar to the container
COPY target/spring-boot-mysql.jar spring-boot-mysql.jar

# Expose port 8080 (Spring Boot default)
EXPOSE 8080

# Run the jar file
ENTRYPOINT ["java", "-jar", "spring-boot-mysql.jar"]




# FROM openjdk:17
# COPY target/spring-boot-mysql.jar /usr/app/spring-boot-mysql.jar
# WORKDIR /usr/app/
# EXPOSE 8080
# ENTRYPOINT ["java","-jar","spring-boot-mysql.jar"]