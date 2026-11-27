# Comandos de ejecución de pruebas — Atlas


## 1. Levantar Atlas

```powershell
docker compose up -d --build
docker compose ps
```

**Qué hace:** construye y levanta los tres servicios con Docker Compose: frontend (puerto 3350), API (4450) y PostgreSQL (15432). `docker compose ps` muestra si los contenedores están activos. Este paso es necesario antes de ejecutar cualquier prueba.

---

## 2. Levantar Jenkins

```powershell
docker compose -f jenkins/docker-compose.jenkins.yml up -d --build
docker exec atlas-jenkins cat /var/jenkins_home/secrets/initialAdminPassword
```

**Qué hace:** levanta Jenkins en un contenedor (puerto 8080). El segundo comando muestra la contraseña inicial de administrador, necesaria para el primer acceso. Esa contraseña no debe aparecer en capturas de pantalla.

Luego se crea un trabajo Pipeline con "Pipeline script from SCM", usando el repositorio de GitHub y el archivo `Jenkinsfile`, y se ejecuta con Build with Parameters.

---

## 3. Pruebas de API y seguridad (Jest)

```powershell
cd BACKEND
npm ci
npm test              # ejecuta ambas suites con salida detallada
npm run test:report   # genera tests/results/report.json y el HTML
```

**Qué hace:** `npm ci` instala las dependencias exactas del proyecto. `npm test` ejecuta las dos suites de pruebas automatizadas, la funcional (`atlas.test.js`) y la de seguridad de configuración (`security-config.test.js`), contra la API en `http://localhost:4450`. `npm run test:report` repite la ejecución y guarda un reporte en JSON y otro en HTML.

**Importante:** el backend debe estar levantado antes de ejecutar estas pruebas. Si Jest termina con fallos, el HTML puede no regenerarse, por lo que conviene revisar su fecha.

---

## 4. Verificación en base de datos

```powershell
docker cp BACKEND/tests/db-checks.sql atlas-postgres:/tmp/db-checks.sql
docker exec -i atlas-postgres psql -U postgres -d atlas -f /tmp/db-checks.sql
```

**Qué hace:** el primer comando copia el script SQL al contenedor de PostgreSQL, porque Docker Compose no lo monta automáticamente. El segundo lo ejecuta con `psql`. El script revisa:

- el formato de las contraseñas almacenadas (CP-28),
- si el RUT y el número de cuenta aparecen en texto plano (CP-29),
- y las últimas entradas de la tabla de auditoría (CP-32).

---

## 5. Pruebas de carga (JMeter)

```powershell
# Carga moderada
powershell -ExecutionPolicy Bypass -File .\jmeter\run-jmeter.ps1 -Threads 50 -RampUp 10 -Loops 3

# Carga de pico
powershell -ExecutionPolicy Bypass -File .\jmeter\run-jmeter.ps1 -Threads 200 -RampUp 20 -Loops 5
```

**Qué hace:** ejecuta el plan `jmeter/atlas-stress-test.jmx`, usando JMeter local si está instalado o una imagen Docker en caso contrario. Cada usuario virtual inicia sesión una vez y luego repite consultas a los endpoints de la API.

| Parámetro | Significado |
|---|---|
| `-Threads` | Usuarios virtuales simultáneos |
| `-RampUp` | Segundos para alcanzar todos los usuarios |
| `-Loops` | Repeticiones de las consultas por usuario |

El reporte queda en `jmeter/results/html-report/index.html`. El script borra la carpeta `jmeter/results` en cada ejecución, por lo que se debe copiar el resultado antes de repetir la prueba.

---

## Resultados generados

| Prueba | Ubicación del resultado |
|---|---|
| Jest | `BACKEND/tests/results/report.json` y `reporte_evidencias.html` |
| JMeter | `jmeter/results/results.jtl` y `jmeter/results/html-report/` |
| Base de datos | Salida de la terminal (`psql`) |
| Jenkins | Build en `http://localhost:8080`, con su Console Output y artefactos |