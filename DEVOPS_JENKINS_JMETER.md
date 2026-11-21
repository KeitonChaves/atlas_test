# Automatización CI/CD con Jenkins y Pruebas de Estrés con JMeter

Este documento explica cómo ejecutar el pipeline de **Jenkins** y las pruebas de estrés con **Apache JMeter** en el repositorio `atlas_test`.

## Archivos agregados

- `Jenkinsfile`: Pipeline declarativo con las etapas:
  1. **Checkout**: Descarga el repositorio.
  2. **Lint & Build Frontend**: Ejecuta `npm ci && npm run lint && npm run build` en `FRONTEND`.
  3. **Build & Deploy Stack (Docker Compose)**: Levanta PostgreSQL, Backend y Frontend con `docker compose up -d --build` y espera el healthcheck del backend.
  4. **API & Security Tests (Jest)**: Ejecuta `npm ci && npm run test:report` en `BACKEND` y genera los reportes en `BACKEND/tests/results/`.
  5. **Stress Tests (JMeter)**: Ejecuta `jmeter/atlas-stress-test.jmx` en modo no-GUI generando `jmeter/results/results.jtl` y el dashboard HTML en `jmeter/results/html-report/`.
- `jenkins/Dockerfile` y `jenkins/docker-compose.jenkins.yml`: Entorno Jenkins LTS listo con Docker CLI y Docker Compose para ejecutar pipelines basados en contenedores.
- `jmeter/atlas-stress-test.jmx`: Plan de pruebas de estrés parametrizado (`HOST`, `PORT`, `THREADS`, `RAMPUP`, `LOOPS`, `USER`, `PASS`).
- `jmeter/run-jmeter.ps1`: Script PowerShell para lanzar JMeter localmente (usa JMeter instalado o Docker `justb4/jmeter:5.5` automáticamente).

---

## 1. Levantar Jenkins con Docker

Asegúrate de tener **Docker Desktop** iniciado y ejecuta desde la raíz de `atlas_test`:

```powershell
docker compose -f jenkins/docker-compose.jenkins.yml up -d --build
```

1. Abre `http://localhost:8080` en tu navegador.
2. Obtén la contraseña inicial de administrador:
   ```powershell
   docker exec atlas-jenkins cat /var/jenkins_home/secrets/initialAdminPassword
   ```
3. Instala los plugins sugeridos (y opcionalmente **HTML Publisher** para ver el reporte de JMeter embebido).
4. Crea un **New Item -> Pipeline**:
   - En **Pipeline -> Definition**, selecciona **Pipeline script from SCM**.
   - **SCM**: `Git`
   - **Repository URL**: `https://github.com/KeitonChaves/atlas_test.git`
   - **Branch**: `*/main` (o la rama que estés usando)
   - **Script Path**: `Jenkinsfile`
5. Haz clic en **Build Now** (o **Build with Parameters** para ajustar `JMETER_THREADS`, `JMETER_RAMPUP`, `JMETER_LOOPS`).

---

## 2. Ejecutar Pruebas de Estrés con JMeter (Standalone)

Con la aplicación Atlas corriendo (`docker compose up -d`), ejecuta:

```powershell
.\jmeter\run-jmeter.ps1 -Threads 50 -RampUp 10 -Loops 3
```

Para pruebas de pico más exigentes (ej. 200 usuarios concurrentes):

```powershell
.\jmeter\run-jmeter.ps1 -Threads 200 -RampUp 20 -Loops 5
```

Al finalizar, abre el reporte interactivo en:
- `jmeter/results/html-report/index.html`

> **Nota sobre endpoints con latencia simulada:** En este proyecto de pruebas, `POST /autenticacion/login` y `GET /clientes` incluyen un `delay(4000)` intencional en el backend. Por eso el plan JMeter inicia sesión una sola vez por hilo (`OnceOnlyController`) y mide tanto endpoints rápidos (`/`, `/contratos/dashboard`, `/contratos/estados`, `/metricas`) como `/clientes`.
