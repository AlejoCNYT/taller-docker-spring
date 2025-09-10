# Java 17 (compatible con Spring Boot 3.x)
FROM eclipse-temurin:17-jre
WORKDIR /usrapp/bin

# Copia lo que Maven generó (debes haber corrido mvn package antes)
COPY target/classes    /usrapp/bin/classes
COPY target/dependency /usrapp/bin/dependency

# La app escucha el puerto que defina PORT (por defecto 6000)
ENV PORT=5000
EXPOSE 5000

# OJO: dentro del contenedor (Linux) el classpath usa ":" (no ";")
CMD ["java","-cp","./classes:./dependency/*","co.edu.escuelaing.modularizacion.RestServiceApplication"]
