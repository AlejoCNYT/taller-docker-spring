# Taller: Modularización con Virtualización y Docker (Spring → Docker → AWS)

Este repositorio contiene una **aplicación web mínima** (endpoint `/greeting`) construida con **Java 17** y **Spring Boot 3**, empacada con **Maven**, **contenedorizada con Docker** y desplegada en **AWS EC2**.

> Nota: El taller usa Spring Boot para practicar contenedorización. **Para la TAREA final** debes reemplazar Spring por **tu propio mini‑framework** (no usar Spring) y garantizar concurrencia y **apagado elegante**. Abajo dejo una guía de cómo adaptar el proyecto.

---

## Índice
1. [Arquitectura y estructura](#arquitectura-y-estructura)
2. [Requisitos](#requisitos)
3. [Compilar y ejecutar localmente](#compilar-y-ejecutar-localmente)
4. [Construir imagen Docker](#construir-imagen-docker)
5. [Probar contenedor local](#probar-contenedor-local)
6. [Publicar en Docker Hub](#publicar-en-docker-hub)
7. [Despliegue en AWS EC2](#despliegue-en-aws-ec2)
8. [Pruebas de verificación](#pruebas-de-verificación)
9. [Apagado elegante y concurrencia](#apagado-elegante-y-concurrencia)
10. [Extensiones para la TAREA (sin Spring)](#extensiones-para-la-tarea-sin-spring)
11. [Limpieza](#limpieza)

---

## Arquitectura y estructura

```
taller-docker-spring/
├─ src/main/java/co/edu/escuelaing/modularizacion/
│  ├─ HelloRestController.java     # REST: GET /greeting?name=...
│  └─ RestServiceApplication.java  # Arranque Spring Boot + puerto por ENV PORT (def. 5000)
├─ pom.xml                         # Java 17 + Spring Boot Web
├─ Dockerfile                      # Imagen ejecutable con clases y dependencias
├─ docker-compose.yml              # (opcional) servicios compuestos
└─ README.md
```

**Endpoint principal**

- `GET /greeting` → `"Hello, World!"`
- `GET /greeting?name=TuNombre` → `"Hello, TuNombre!"`

---

## Requisitos

- **Java 17** (o superior)
- **Maven 3.8+**
- **Docker Desktop** (Windows/macOS) o **Docker Engine** (Linux)
- Cuenta en **Docker Hub**
- Cuenta en **AWS** (EC2 – Amazon Linux 2/2023)

---

## Compilar y ejecutar localmente

```bash
# 1) Compilar
mvn clean package

# 2) Ejecutar desde clases y dependencias (Windows PowerShell)
$env:PORT = 6000
java -cp ".	arget\classes;.	arget\dependency\*" co.edu.escuelaing.modularizacion.RestServiceApplication

# (Linux/macOS)
export PORT=6000
java -cp "./target/classes:./target/dependency/*" co.edu.escuelaing.modularizacion.RestServiceApplication
```

Abrir en el navegador:
```
http://localhost:6000/greeting
http://localhost:6000/greeting?name=Daniel
```

---

## Construir imagen Docker

Asegúrate de haber corrido `mvn clean package` para que exista `target/classes` y `target/dependency`.

**Dockerfile (usado en el taller):**
```dockerfile
# Java 17 base
FROM eclipse-temurin:17-jre

WORKDIR /usrapp/bin

# Copia binarios compilados por Maven
COPY target/classes /usrapp/bin/classes
COPY target/dependency /usrapp/bin/dependency

# Puerto por variable de entorno (default 6000)
ENV PORT=6000
EXPOSE 6000

# Importante: en Linux el classpath usa ":" (no ";")
CMD ["java","-cp","./classes:./dependency/*","co.edu.escuelaing.modularizacion.RestServiceApplication"]
```

**Build:**

```bash
docker build -t docker-spring-primer .
```

Verifica:
```bash
docker images
```

---

## Probar contenedor local

```bash
docker run -d --name springweb -e PORT=6000 -p 42000:6000 docker-spring-primer

# Verificación rápida
curl http://localhost:42000/greeting
```

---

## Publicar en Docker Hub

```bash
# Autenticarse
docker login

# Etiquetar (reemplaza <usuario> y <repo>)
docker tag docker-spring-primer <usuario>/<repo>:latest

# Empujar
docker push <usuario>/<repo>:latest
```

Ejemplo real (si ya creaste el repo en Docker Hub):
```bash
docker tag docker-spring-primer dnieblen/firstsprkwebapprepo:latest
docker push dnieblen/firstsprkwebapprepo:latest
```

---

## Despliegue en AWS EC2

1. **Crear EC2**
   - AMI: **Amazon Linux 2** (o Amazon Linux 2023)
   - Tipo: `t2.micro` (free tier)
   - **Security Group (Inbound rules)**:
     - SSH (TCP **22**) – *My IP*
     - Custom TCP (TCP **42000**) – **0.0.0.0/0**

2. **Conectarse por SSH** (Windows PowerShell):
   ```powershell
   ssh -i "C:
uta\mi-llave.pem" ec2-user@<IP_PUBLICA>
   ```

3. **Instalar Docker** (en la EC2):
   ```bash
   sudo yum update -y
   sudo yum install -y docker
   sudo service docker start
   sudo usermod -a -G docker ec2-user
   exit   # salir y volver a entrar por SSH para aplicar el grupo
   ```

4. **Correr el contenedor (usando tu imagen de Docker Hub)**:
   ```bash
   docker run -d --restart=always -e PORT=6000 -p 42000:6000 --name webapp <usuario>/<repo>:latest
   docker ps
   ```

5. **Probar desde tu PC**:
   ```
   http://<IP_PUBLICA>:42000/greeting
   ```

> Si no responde:
> - `docker logs webapp`
> - Revisa que en logs diga “Tomcat started on port **6000**”
> - Valida Security Group: puerto **42000** abierto.
> - Test interno: `curl http://localhost:42000/greeting` desde la EC2.

---

## Pruebas de verificación
<img width="797" height="99" alt="imagen" src="https://github.com/user-attachments/assets/bdfb378d-ade6-4c7f-b4a3-6a981a57009c" />
<img width="1848" height="589" alt="imagen" src="https://github.com/user-attachments/assets/9c9634c7-d367-41c5-ba40-30736aa6df28" />

- **Salud básica:** `GET /greeting` → 200 OK y cuerpo `"Hello, World!"`  
- **Parámetro:** `GET /greeting?name=Ada` → `"Hello, Ada!"`  
- **Contenedor en ejecución:** `docker ps` muestra `0.0.0.0:42000->6000/tcp`  
- **Logs limpios:** `docker logs webapp` sin stacktraces inesperados.

---

## Apagado elegante y concurrencia

Spring Boot ya soporta:
- Señal `SIGTERM` → inicia **graceful shutdown** de Tomcat.
- Pool de hilos para peticiones concurrentes.

En Docker, para simular apagado elegante:
```bash
docker stop webapp   # envía SIGTERM y espera
```

---

## Extensiones para la TAREA (sin Spring)

Para cumplir **NO USAR SPRING**:
- Implementa un **micro‑framework propio** con `ServerSocket`/`HttpServer` o Netty/Undertow embebido.
- Soporta rutas mínimas: `GET /greeting` con parámetro `name`.
- Maneja **concurrencia** con `ExecutorService` (por ejemplo `newFixedThreadPool`).
- Implementa **graceful shutdown**:
  - Captura `SIGTERM` → rechaza nuevas conexiones, espera a que terminen las activas, y cierra el pool.
- Expón también el puerto por variable de entorno `PORT` (default 6000) para que el Dockerfile y AWS no cambien.
- Repite la contenedorización y el despliegue (los pasos son los mismos).

**Pistas rápidas (Java puro):**
```java
int port = Integer.parseInt(System.getenv().getOrDefault("PORT", "6000"));
var executor = Executors.newFixedThreadPool(8);
// aceptar sockets, parsear HTTP mínimo, responder "Hello, %s!"
// agregar Runtime.getRuntime().addShutdownHook(...) para cierre ordenado
```

Incluye en el README capturas/resultado de:
- `docker images`, `docker ps`
- Comandos para construir, ejecutar y detener
- URL funcionando en EC2

---

## Limpieza

```bash
# Local
docker rm -f webapp 2>/dev/null
docker rmi docker-spring-primer 2>/dev/null

# AWS
# - Detén/Termina la instancia EC2 cuando no la uses
# - (Opcional) Elimina la imagen del Docker Hub si ya no la necesitas
```

---

## Autor
- **Estudiante:** _Tu Nombre_
- **Curso:** AREP – Taller de Modularización con Virtualización
- **Fecha:** 2025-09
