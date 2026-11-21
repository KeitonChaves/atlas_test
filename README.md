# Sistema de Gestión Atlas — QA, CI/CD con Jenkins y Pruebas de Estrés con JMeter

Proyecto desarrollado para la asignatura **ISY1102 — Calidad y seguridad en el desarrollo de software** (Caso A: *Sistema de Gestión Atlas*). Incluye aplicación **Frontend**, **Backend**, base de datos **PostgreSQL**, suite de pruebas funcionales/seguridad con **Jest**, pipeline de automatización **CI/CD con Jenkins** y pruebas de carga/estrés con **Apache JMeter**.

---

## Descripción funcional

Atlas permite a usuarios registrados por empresa:
- Gestionar **clientes**, **contratos** y documentos PDF asociados.
- Administrar **empresas**, **usuarios** y **roles** internos.
- Consultar **métricas** y **auditoría** de acciones.
- Exponer documentación interactiva de la API mediante **Swagger / OpenAPI** (`/docs`).

> **Nota académica:** El backend incluye comportamiento intencionalmente vulnerable/simulado para fines de evaluación de calidad y seguridad (por ejemplo, `delay(4000)` en `POST /autenticacion/login` y `GET /clientes`, y cabeceras/CORS permisivos detectados por las pruebas de seguridad).

---

## Stack tecnológico

| Capa | Tecnología | Puerto por defecto |
| :--- | :--- | :--- |
| **Frontend** | React 19, Vite, Material UI, Tailwind CSS, Nginx | `3350` → `80` |
| **Backend** | Node.js 18, Express 4, JWT, Multer, Swagger UI | `4450` → `4000` |
| **Base de datos** | PostgreSQL 15 Alpine (con dump inicial `dump-atlas.sql`) | `15432` → `5432` |
| **Pruebas API & Seguridad** | Jest 29 + Axios | — |
| **CI/CD** | Jenkins LTS + Docker CLI / Compose Plugin | `8080` / `50000` |
| **Pruebas de Estrés** | Apache JMeter 5.5 (`justb4/jmeter:5.5`) | — |

---

## Estructura del repositorio

```text
atlas_test/
├── BACKEND/
│   ├── sql/
│   │   ├── dump-atlas.sql          # Esquema y datos semilla (usuarios admin/admin, editor/editor)
│   │   ├── init-db.sh              # Script de inicialización para PostgreSQL
│   │   └── init.sql
│   ├── src/
│   │   ├── routes/                 # auth, users, clients, contracts, audit, empresas, roles, empresa_usuarios, metricas
│   │   ├── app.js                  # Servidor Express + Swagger (/docs)
│   │   ├── db.js                   # Pool de conexión PostgreSQL
│   │   └── openapi.json            # Especificación OpenAPI
│   ├── tests/
│   │   ├── atlas.test.js           # Suite funcional API (CRUD y validaciones)
│   │   ├── security-config.test.js # Pruebas de cabeceras HTTP, CORS, 401 y SQLi
│   │   ├── generate-report.js      # Generador de reporte desde results/report.json
│   │   ├── load-test.k6.js         # Script alternativo de carga con k6
│   │   └── Atlas_API_Tests.postman_collection.json
│   ├── uploads/contracts/          # Carpeta para archivos adjuntos de contratos
│   ├── Dockerfile
│   └── package.json
├── FRONTEND/
│   ├── src/                        # Páginas, componentes, contexto y rutas React
│   ├── Dockerfile                  # Build multi-stage (Node 20 + Nginx Alpine)
│   ├── nginx.conf
│   └── package.json
├── jenkins/
│   ├── Dockerfile                  # Jenkins LTS con docker-ce-cli y docker-compose-plugin
│   └── docker-compose.jenkins.yml  # Levantamiento de Jenkins con acceso al socket Docker
├── jmeter/
│   ├── atlas-stress-test.jmx       # Plan de pruebas de estrés parametrizado para JMeter
│   └── run-jmeter.ps1              # Script PowerShell para ejecutar JMeter local o vía Docker
├── .env                            # Variables de entorno para Docker Compose
├── .gitignore
├── docker-compose.yml              # Orquestación de postgres + backend + frontend
├── Jenkinsfile                     # Pipeline declarativo CI/CD completo
├── DEVOPS_JENKINS_JMETER.md        # Guía rápida de Jenkins y JMeter
└── README.md
```

---

## Variables de entorno (`.env`)

En la raíz del proyecto se definen los valores por defecto utilizados por `docker-compose.yml`:

- `JWT_SECRET`: Llave para firmar y verificar los tokens JWT.
- `PORT_POSTGRES`: `15432` (puerto expuesto para PostgreSQL).
- `PORT_BACKEND`: `4450` (puerto expuesto para la API).
- `PORT_FRONTEND`: `3350` (puerto expuesto para el cliente web).

---

## 1. Levantamiento rápido con Docker Compose

Requiere **Docker Desktop** iniciado. Desde la raíz del repositorio:

```powershell
docker compose up -d --build
```

Servicios disponibles:
- **Frontend:** `http://localhost:3350`
- **Backend API:** `http://localhost:4450` (`{"name":"Atlas","status":"ok"}`)
- **Documentación Swagger:** `http://localhost:4450/docs`
- **PostgreSQL:** `localhost:15432` | DB: `atlas` | Usuario: `postgres` | Contraseña: `postgres`

Credenciales semilla de la aplicación (definidas en `BACKEND/sql/dump-atlas.sql`):
- Usuario: `admin` / Contraseña: `admin`
- Usuario: `editor` / Contraseña: `editor`

---

## 2. Pruebas automatizadas de API y Seguridad (Jest)

Con el backend levantado en `http://localhost:4450`:

```powershell
cd BACKEND
npm ci
npm run test:report
```

Esto ejecuta:
- `tests/atlas.test.js`: pruebas funcionales de autenticación, empresas, usuarios, clientes, contratos, roles, métricas y auditoría.
- `tests/security-config.test.js`: verificación de cabeceras de seguridad (`X-Content-Type-Options`, `X-Frame-Options`, `HSTS`), CORS, acceso sin token (`401`) y payloads de inyección SQL.
- Genera el reporte en `BACKEND/tests/results/report.json`.

---

## 3. Automatización CI/CD con Jenkins

### Levantar Jenkins en Docker

```powershell
docker compose -f jenkins/docker-compose.jenkins.yml up -d --build
```

1. Abre `http://localhost:8080`.
2. Obtén la contraseña inicial de administrador:
   ```powershell
   docker exec atlas-jenkins cat /var/jenkins_home/secrets/initialAdminPassword
   ```
3. Instala los plugins sugeridos.
4. *(Opcional recomendado)* Instala el plugin **HTML Publisher** (`Manage Jenkins → Plugins → Available plugins → HTML Publisher`) para visualizar el dashboard de JMeter directamente dentro de Jenkins.

### Configurar el Pipeline

1. En Jenkins selecciona **New Item** → ingresa un nombre (ej. `atlas-ci`) → **Pipeline** → **OK**.
2. En la sección **Pipeline**:
   - **Definition:** `Pipeline script from SCM`
   - **SCM:** `Git`
   - **Repository URL:** `https://github.com/KeitonChaves/atlas_test.git`
   - **Branch Specifier:** `*/main`
   - **Script Path:** `Jenkinsfile`
3. Guarda y ejecuta **Build Now** (o **Build with Parameters**).

### Parámetros del `Jenkinsfile`

| Parámetro | Valor por defecto | Descripción |
| :--- | :--- | :--- |
| `RUN_STRESS_TEST` | `true` | Habilita o omite la etapa de pruebas de estrés con JMeter. |
| `JMETER_THREADS` | `50` | Número de usuarios concurrentes simulados. |
| `JMETER_RAMPUP` | `10` | Tiempo de rampa en segundos para alcanzar todos los hilos. |
| `JMETER_LOOPS` | `3` | Cantidad de iteraciones por cada usuario virtual. |
| `TEARDOWN_AFTER_RUN` | `false` | Si es `true`, detiene los contenedores Docker al finalizar el pipeline. |

### Etapas del Pipeline

1. **Checkout:** Descarga el código fuente desde el repositorio Git.
2. **Lint & Build Frontend:** Ejecuta `npm ci`, `npm run lint` (no bloqueante para advertencias/errores preexistentes) y `npm run build` en `FRONTEND` usando `node:20-alpine` con `--volumes-from $(hostname)`.
3. **Build & Deploy Stack (Docker Compose):** Verifica si `http://atlas-backend:4000/` ya está saludable en `atlas-network`; si no lo está, limpia contenedores previos y ejecuta `docker compose up -d --build`, esperando hasta que el backend responda HTTP `200`.
4. **API & Security Tests (Jest):** Ejecuta `npm ci && npm run test:report` en `BACKEND` usando `node:18-alpine`. Si alguna prueba falla, marca la etapa como `UNSTABLE` (amarillo) mediante `catchError` para conservar el reporte y continuar hacia las pruebas de estrés.
5. **Stress Tests (JMeter):** Ejecuta `justb4/jmeter:5.5` contra `http://atlas-backend:4000` dentro de `atlas-network`, generando `jmeter/results/results.jtl` y el dashboard HTML en `jmeter/results/html-report/`.
6. **Post (Artifacts y Reportes):** Archiva `BACKEND/tests/results/**` y `jmeter/results/**` en **Build Artifacts** y, si **HTML Publisher** está instalado, publica la pestaña **JMeter Stress Report**.

---

## 4. Pruebas de Estrés con Apache JMeter

El plan `jmeter/atlas-stress-test.jmx` está parametrizado con propiedades (`PROTOCOL`, `HOST`, `PORT`, `THREADS`, `RAMPUP`, `LOOPS`, `USER`, `PASS`) y simula el siguiente flujo por cada usuario virtual:

1. **Login único por hilo (`OnceOnlyController`):** `POST /autenticacion/login` con `admin/admin`, extrayendo `$.token` mediante `JSONPostProcessor` en `${jwt_token}`. *(Se ejecuta una sola vez por hilo para evitar repetir el `delay(4000)` del login en cada iteración).*
2. **Peticiones autenticadas (`Authorization: Bearer ${jwt_token}`):**
   - `GET /` (Healthcheck)
   - `GET /contratos/dashboard`
   - `GET /contratos/estados`
   - `GET /clientes` *(incluye `delay(4000)` intencional en backend)*
   - `GET /metricas`
3. **Aserciones:** Valida HTTP `200` en cada endpoint y aplica un *Think Time* aleatorio (`200–600 ms`).

### Ejecución local (sin necesidad de instalar JMeter)

El script `jmeter/run-jmeter.ps1` detecta automáticamente si tienes `jmeter` instalado localmente; si no, utiliza el contenedor `justb4/jmeter:5.5`:

```powershell
# Prueba moderada (50 usuarios concurrentes, 10s rampa, 3 iteraciones)
powershell -ExecutionPolicy Bypass -File .\jmeter\run-jmeter.ps1 -Threads 50 -RampUp 10 -Loops 3

# Prueba de pico (200 usuarios concurrentes, 20s rampa, 5 iteraciones)
powershell -ExecutionPolicy Bypass -File .\jmeter\run-jmeter.ps1 -Threads 200 -RampUp 20 -Loops 5
```

Al finalizar, abre el reporte HTML interactivo generado en:
```text
jmeter/results/html-report/index.html
```

---

## Solución de problemas frecuentes

- **PowerShell bloquea `run-jmeter.ps1` por política de ejecución:** Ejecuta con `powershell -ExecutionPolicy Bypass -File .\jmeter\run-jmeter.ps1 ...`.
- **Error de puerto ocupado (`3350`, `4450`, `8080`, `15432`):** Ajusta los puertos en `.env` o detén servicios previos con `docker compose down`.
- **Jenkins no muestra estilos/gráficos en `JMeter Stress Report`:** Es por la política CSP por defecto de Jenkins; puedes descargar el reporte completo desde **Build Artifacts** (`jmeter/results/html-report/index.html`).
