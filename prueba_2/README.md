# Prueba 2 - Deployment Django + React

La aplicación se empaqueta en tres servicios: React compilado y servido por Nginx, Django ejecutado con Gunicorn y PostgreSQL. Nginx también actúa como reverse proxy para `/api/`, de modo que el navegador utiliza un único origen en `http://localhost:8080`.

## Paso a paso con Docker Compose

### 1. Requisitos

- Docker Engine 24 o posterior.
- Docker Compose v2 (`docker compose`).
- Puertos 8080 libres.

### 2. Preparar la configuración

```bash
cd prueba-2
cp .env.example .env
```

Para una prueba local se pueden conservar los valores de ejemplo. Nunca deben emplearse en producción. Para generar un `SECRET_KEY`:

```bash
python -c "import secrets; print(secrets.token_urlsafe(50))"
```

### 3. Construir y levantar

```bash
docker compose config
docker compose build
docker compose up -d
docker compose ps
```

El frontend queda disponible en <http://localhost:8080>. El backend no publica un puerto al host: solamente es accesible desde Nginx por la red interna.

### 4. Verificar

```bash
curl --fail http://localhost:8080/healthz
curl -i http://localhost:8080/api/users/
```
### 5. Detener

```bash
docker compose down
```

## Decisiones tomadas

- El backend utiliza `python:3.11-slim` y Gunicorn. `runserver` no es tan apropiado para producción.
- El frontend usa un build multietapa: Node compila React y la imagen final contiene únicamente Nginx sin privilegios y los archivos estáticos.
- React usa `/api/` como URL relativa. Nginx reenvía esas solicitudes a `backend:8000`, evitando URLs fijas y problemas CORS.
- PostgreSQL no publica el puerto 5432 al host y conserva los datos en un volumen nombrado.
- `depends_on` se combina con health checks: ordenar contenedores no garantiza que la base esté lista.
- El entrypoint ejecuta migraciones idempotentes y ya no hace `flush`, porque borrar datos en cada reinicio es un comportamiento destructivo.
- Los secretos se reciben por variables. `.env.example` documenta las claves, mientras que `.env` no debe versionarse.

## Como seria un despliegue en AWS

El proceso seria:
1. Crear repositorios ECR para frontend y backend.
2. Construir y publicar ambas imágenes con tags inmutables basados en commit SHA.
3. Crear un cluster ECS y dos Task Definitions independientes.
4. Ejecutar servicios ECS Fargate en al menos dos subredes privadas y dos AZ.
5. Reemplazar PostgreSQL en contenedor por RDS PostgreSQL Multi-AZ.
6. Guardar `SECRET_KEY` y credenciales en Secrets Manager e inyectarlas en la Task Definition.
7. Exponer el frontend mediante un ALB HTTPS y mantener el backend en un target group/ruta `/api/*`.
8. Configurar health checks, Auto Scaling, CloudWatch Logs, alarmas y rollback del deployment circuit breaker.