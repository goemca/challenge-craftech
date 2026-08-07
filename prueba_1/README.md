# Prueba 1 - Arquitectura web distribuida en AWS


## Descripción y decisiones

La solución se despliega en `us-east-1` por su amplitud de servicios y costo competitivo. Route 53 resuelve el dominio y CloudFront actúa como punto de entrada global por otro lado AWS WAF filtra solicitudes maliciosas. El frontend React se compila como archivos estáticos y se publica en un bucket S3 privado, accesible únicamente mediante CloudFront. Las solicitudes `/api/*` se envían desde CloudFront hacia un Application Load Balancer.

El backend se ejecuta en ECS Fargate como contenedores distribuidos entre dos zonas de disponibilidad. El servicio mantiene como mínimo dos tareas y utiliza Service Auto Scaling según CPU, memoria y cantidad de solicitudes del ALB. 
Esto absorbe las cargas variables sin administrar servidores. Las tareas se ubican en subredes privadas y el único componente público de la capa de aplicación es el balanceador.

Los datos transaccionales se almacenan en RDS PostgreSQL Multi-AZ. En donde el RDS mantiene un standby síncrono en una segunda zona y realiza failover automático.Por otra parte se usa DynamoDB en modalidad on-demand se utiliza para información no relacional, como por ejemplo sesiones, preferencias o eventos, y escala sin aprovisionar capacidad. 
El Secrets Manager guarda credenciales de base de datos y tokens de los dos servicios externos; no se incorporan secretos a imágenes ni variables versionadas.
Con Amazon CloudWatche se centralizan los logs , metricas y alarmas de los componetes para poder detectar errores y problemas de performance. AWS CloudTrail registra acciones administrativas.

Cada zona posee un NAT Gateway para que el backend consuma los dos microservicios externos sin recibir conexiones directas desde Internet. Esta duplicación conserva la salida aun cuando una zona falle. 
Los Security Groups aplican mínimo privilegio: Internet solo alcanza CloudFront/ALB, el ALB solo conecta con el puerto del backend y el PostgreSQL solo acepta conexiones desde el Security Group de ECS. 

### Requisitos

| Requisito | Implementación |
|---|---|
| Cargas variables | CloudFront, DynamoDB on-demand y Auto Scaling de ECS |
| Alta disponibilidad | Dos AZ, dos tareas, ALB, RDS Multi-AZ y NAT por AZ |
| Frontend JavaScript | React compilado en S3 y distribuido por CloudFront |
| Base relacional | RDS PostgreSQL Multi-AZ |
| Base no relacional | DynamoDB on-demand |
| Dos microservicios externos | Salida desde tareas privadas mediante NAT Gateway |
| Soluciones distribuidas | CDN, balanceador, contenedores multi-AZ y servicios administrados |

## Estimación mensual orientativa
Se considero una aplicación web de tamaño pequeño a mediano que funciona durante las 24 horas, con alta disponibilidad en dos zonas.

Los valores son orientativos y no incluyen impuestos, soporte empresarial ni posibles cargos comerciales de las dos APIs externas.

 Zona `us-east-1`, 730 horas, dos tareas Linux/x86 de 0.5 vCPU y 1 GB, RDS PostgreSQL pequeño Multi-AZ, 200 GB de entrega web, 50 GB procesados por NAT, tráfico medio y dos NAT Gateways. 

Tabla
| Servicio | Parámetros principales | USD/mes estimados |
|---|---|---:|
| CloudFront + S3 | 200 GB de salida, 20 GB almacenados y solicitudes | 20 |
| AWS WAF | 1 Web ACL, reglas administradas y solicitudes | 15 |
| Application Load Balancer | 1 ALB, 730 h y carga moderada | 24 |
| ECS Fargate | 2 tareas, 0.5 vCPU, 1 GB, 24x7 | 36 |
| RDS PostgreSQL Multi-AZ | Clase burstable pequeña y 40 GB gp3 | 95 |
| DynamoDB on-demand | Volumen bajo/medio de lecturas y escrituras | 5 |
| NAT Gateway | 2 gateways, 730 h y 50 GB procesados | 68 |
| CloudWatch | Logs, métricas y alarmas | 12 |
| Route 53, Secrets Manager y ECR | Zona, secretos e imágenes | 5 |
| **Total estimado** | | **280 USD/mes** |

AWS publica para Fargate en N. Virginia precios por segundo de vCPU y memoria. Un NAT Gateway agrega costo por hora y por GB procesado, por eso es uno de los principales componentes del total. 
En Multi-AZ, RDS factura la instancia primaria y la standby. 

### Trade-offs

**Presupuesto 30 % menor.** Yo mantendría los RDS Multi-AZ y al menos dos tareas porque representan los requisitos explícitos de HA. Reduciría logs de baja utilidad y su retención, usaría Graviton/Fargate ARM si la imagen es compatible, establecería una tarea on-demand como base y Fargate Spot para capacidad de ráfaga, habilitaría endpoints VPC para S3/ECR y revisaría el tráfico de los NAT. 
Si fuera un entorno no productivo podría utilizarse un solo NAT Gateway, documentando que se pierde HA de salida.

**Tráfico duplicado.** CloudFront y DynamoDB on-demand escalan de forma administrada. Aumentaría el máximo de tareas de ECS y usaría request count del ALB como señal de escalado. Validaría conexiones de PostgreSQL, incorporaría RDS Proxy y, si predominan lecturas, una réplica de lectura. También revisaría límites de las APIs externas, timeouts, retries con backoff y circuit breakers para impedir fallos en cascada.
