# imagen liviana de python
FROM python:3.11-slim AS runtime

# evita que python genere archivos compilados y tambien para el uso de logs a salida
ENV PYTHONDONTWRITEBYTECODE=1 \ 
    PYTHONUNBUFFERED=1

# Se instalan las depencias del sistema
RUN apt-get update \ 
    && apt-get install --no-install-recommends -y netcat-openbsd libpq5 \
    && rm -rf /var/lib/apt/lists/* \
    && groupadd --system django \
    && useradd --system --gid django --create-home django

WORKDIR /app

COPY requirements.txt .
RUN pip install --no-cache-dir --upgrade pip \
    && pip install --no-cache-dir -r requirements.txt

COPY --chown=django:django . .
RUN chmod +x /app/entrypoint.sh

USER django

EXPOSE 8000

ENTRYPOINT ["/app/entrypoint.sh"]
CMD ["gunicorn", "core.wsgi:application", "--bind", "0.0.0.0:8000", "--workers", "3", "--timeout", "60"]
