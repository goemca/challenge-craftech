# Prueba 3 - CI/CD con Nginx

## Ejecución local

```bash
cd prueba-3
docker build -t nginx-challenge:local .
docker run --rm -p 8081:8080 nginx-challenge:local
```

En otra terminal:

```bash
curl --fail http://localhost:8081/
curl --fail http://localhost:8081/healthz
```

## Pipeline implementado

El workflow `.github/workflows/nginx-cicd.yml` se dispara cuando cambian `index.html`, el Dockerfile, la configuración de Nginx, el Compose, el script de deployment o el propio workflow.

El flujo es:

1. Checkout del repositorio.
2. Autenticación en GitHub Container Registry mediante `GITHUB_TOKEN`.
3. Cálculo de un tag inmutable.
4. Construcción y publicación de la imagen.
5. Push a `main`: deployment de staging.

### Versionado

- Staging: `sha-<12 caracteres del commit>`.
- Producción: tag de release, por ejemplo `v1.0.0`.

### Ambientes

Docker Compose se ejecuta con proyectos diferentes:

- `nginx-staging`, puerto 8081.
- `nginx-production`, puerto 8082.

Esto genera contenedores independientes aun cuando ambos corran en el mismo host

## Preparación de runners - (PENDIENTE)

La construcción corre en un runner administrado por GitHub. Los despliegues necesitan runners windows autohospedados con Docker, Compose.
