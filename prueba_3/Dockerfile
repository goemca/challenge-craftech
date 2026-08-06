#imagen base y liviana de ngix
FROM nginxinc/nginx-unprivileged:1.27-alpine

# copio la config por default
COPY nginx.conf /etc/nginx/conf.d/default.conf

#copio la pagina  al la imagen de DF
COPY index.html /usr/share/nginx/html/index.html

EXPOSE 8080

# chequeo de estado de salud
HEALTHCHECK --interval=30s --timeout=3s --start-period=5s --retries=3 \
  CMD wget -qO- http://127.0.0.1:8080/healthz || exit 1
