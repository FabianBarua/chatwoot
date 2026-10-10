# Xplus: cómo hacer un cambio, compilar y desplegar

Guía para trabajar sobre la edición Xplus de Chatwoot: desde editar el código hasta tenerlo corriendo en producción, y cómo volver atrás si algo sale mal.

## Cómo está armado

- **Rama de trabajo:** `v4.18.0-xp`, basada en Chatwoot `v4.18.0`. La app muestra la versión `4.18.0-xp`.
- **Imagen:** `ghcr.io/fabianbarua/chatwoot`, con dos etiquetas por compilación: `v4.18.0-xp` (la última) y `v4.18.0-xp-<commit>` (fija, para volver atrás).
- **Producción:** Dokploy → proyecto **Server-Xplus** → compose **chatwoot** (dominio `chatwoot.website`). El compose usa `image: ghcr.io/fabianbarua/chatwoot:v4.18.0-xp` con `pull_policy: always`, así que cada Deploy baja la última imagen.
- **Migraciones:** el servicio `chatwoot-rails` corre `rails db:chatwoot_prepare` al arrancar, así que las migraciones nuevas se aplican solas en cada Deploy.
- **Edición enterprise:** el plan está fijo en `enterprise` (`lib/chatwoot_hub.rb`) y todas las funciones premium vienen activadas. No hace falta montar ningún initializer extra en el compose.

## Requisitos en la PC

- Docker Desktop con contenedores Linux.
- Node 24 y pnpm 10 (`corepack enable`), y Git Bash en Windows.
- Ruby no hace falta: los chequeos de Ruby corren dentro de una imagen de desarrollo (ver más abajo).
- Para publicar imágenes: `gh auth login` con permiso `write:packages`, y luego:

```bash
gh auth token | docker login ghcr.io -u FabianBarua --password-stdin
```

## 1. Hacer el cambio

```bash
git checkout v4.18.0-xp
pnpm install --frozen-lockfile
```

Reglas del repo (detalle en `AGENTS.md`):

- Vue con Composition API y `<script setup>`, solo clases de Tailwind (sin CSS propio ni estilos inline).
- Todo texto visible va por i18n. El equipo usa español y portugués: agregá cada clave en `en`, `es`, `pt_BR` y `pt` (`app/javascript/dashboard/i18n/locale/<idioma>/`), y en `config/locales/<idioma>.yml` para textos del backend.
- Cambios de base de datos: migración nueva en `db/migrate/` y actualizar `db/schema.rb` a mano (versión y tabla/columna/índice). Los nombres de índice no pueden pasar de 63 caracteres.
- Si agregás una función premium nueva de upstream, activala en `config/features.yml` y en una migración (ver `db/migrate/20261005000002_enable_premium_features_for_xplus.rb`).

## 2. Verificar el código

Frontend:

```bash
pnpm exec eslint <archivos cambiados>
```

```bash
pnpm exec vitest run <carpeta o spec>
```

Backend (Ruby dentro de Docker). La imagen de desarrollo se compila una sola vez:

```bash
docker build -f docker/Dockerfile --build-arg RAILS_ENV=development --build-arg BUNDLE_WITHOUT='' --build-arg EXECJS_RUNTIME=Node -t chatwoot:xp-dev .
```

```bash
MSYS_NO_PATHCONV=1 docker run --rm -v "$(pwd -W 2>/dev/null || pwd):/app" -w /app chatwoot:xp-dev bundle exec rubocop <archivos .rb>
```

Para RSpec hace falta Postgres y Redis: ver la sección **RSpec** al final.

## 3. Probar en local con la imagen real

Commiteá primero: el script compila desde un clon limpio del commit, no desde la carpeta de trabajo.

```bash
docker/xplus/build.sh
```

```bash
docker compose -f docker/xplus/docker-compose.local.yaml up -d
```

La primera vez, cargá datos de prueba (cuenta, agentes, bandeja web y conversaciones en distintos estados):

```bash
docker compose -f docker/xplus/docker-compose.local.yaml cp docker/xplus/setup_local.rb rails:/tmp/setup_local.rb
```

```bash
MSYS_NO_PATHCONV=1 docker compose -f docker/xplus/docker-compose.local.yaml exec rails bundle exec rails runner /tmp/setup_local.rb
```

Abrí http://localhost:8090 e ingresá con el usuario de prueba de `db/seeds.rb` (`john@acme.inc`). Para volver a probar después de otro cambio: `docker/xplus/build.sh` y luego `docker compose -f docker/xplus/docker-compose.local.yaml up -d rails sidekiq`.

Para borrar todo el stack local, incluidos los datos:

```bash
docker compose -f docker/xplus/docker-compose.local.yaml down -v
```

## 4. Publicar

```bash
git push origin v4.18.0-xp
```

```bash
docker/xplus/build.sh --push
```

El push a cualquier rama `*-xp` también dispara el workflow **Imagen Xplus** (`.github/workflows/xp-image.yml`), que compila y publica lo mismo. Si GitHub Actions está bloqueado (por ejemplo, por facturación), `build.sh --push` hace el mismo trabajo desde tu PC.

El paquete de GHCR tiene que ser **público**. Si es privado, Dokploy falla con `unauthorized` al bajar la imagen.

## 5. Desplegar en Dokploy

1. Dokploy → **Server-Xplus** → compose **chatwoot** → **Deploy**.
2. Esperá a que el deploy diga *Done* y que `chatwoot-rails` y `chatwoot-sidekiq` estén *running* en la pestaña **Containers**.
3. Comprobá la versión:

```bash
curl -s https://chatwoot.website/api
```

Tiene que responder `"version":"4.18.0-xp"` con `queue_services` y `data_services` en `ok`.

4. Si algo falla, mirá **Logs** de `chatwoot-rails` (arranque y migraciones) y de `chatwoot-sidekiq`.

## 6. Volver atrás

1. Buscá la etiqueta anterior en https://github.com/users/FabianBarua/packages/container/package/chatwoot (por ejemplo `v4.18.0-xp-a318591`).
2. En el compose de Dokploy cambiá la línea `image:` a esa etiqueta y hacé **Deploy**.
3. Ojo: las migraciones no se deshacen. Volver a una imagen anterior funciona mientras esa versión tolere las columnas nuevas, que es lo normal cuando solo se agregan.

## Problemas conocidos

| Síntoma | Causa | Solución |
|---|---|---|
| `exec docker/entrypoints/rails.sh: no such file or directory` | Imagen compilada desde una copia con CRLF | Compilar con `docker/xplus/build.sh` (clona con LF). El repo tiene `.gitattributes` con `eol=lf`. |
| `unauthorized` al bajar la imagen | Paquete de GHCR privado | Hacerlo público, o cargar un registry con token `read:packages` en Dokploy. |
| Sidekiq cae con `can't write unknown attribute feature_flags_ext_1` | Initializer viejo `zzz_local_premium_unlock.rb` montado en el compose | Quitar ese volumen del compose; la edición Xplus ya trae todo habilitado. |
| Workflow "Imagen Xplus" falla en 2 segundos | Cuenta de GitHub bloqueada por facturación | Resolver la facturación o usar `docker/xplus/build.sh --push`. |
| `pnpm story:dev` (Histoire) no muestra componentes | Falla al cargar historias en este entorno | Verificar en la app local (paso 3). |
| Algunas specs de upstream fallan | Esperan los valores de la edición community (plan del hub, Captain apagado) | Es esperado en Xplus. |

## RSpec

```bash
docker network create xp-net
```

```bash
docker run -d --name xp-pg --network xp-net -e POSTGRES_PASSWORD=postgres pgvector/pgvector:pg16
```

```bash
docker run -d --name xp-redis --network xp-net redis:alpine
```

```bash
MSYS_NO_PATHCONV=1 docker run --rm --network xp-net -v "$(pwd -W 2>/dev/null || pwd):/app" -w /app -e RAILS_ENV=test -e POSTGRES_HOST=xp-pg -e POSTGRES_USERNAME=postgres -e POSTGRES_PASSWORD=postgres -e REDIS_URL=redis://xp-redis:6379 -e SECRET_KEY_BASE=test -e FRONTEND_URL=http://localhost:3000 chatwoot:xp-dev sh -c "bundle exec rails db:create db:schema:load && bundle exec rspec <specs>"
```

Montar la carpeta de Windows es lento. Para correr muchas specs conviene copiar el repo dentro de un contenedor de larga duración y ejecutar ahí.

## Actualizar a una versión nueva de Chatwoot

1. Traer el tag de Chatwoot oficial y crear la rama desde él, por ejemplo `git fetch upstream tag v4.19.0 --no-tags` y `git checkout -b v4.19.0-xp v4.19.0`. El fork en GitHub solo guarda la rama en uso: no tiene las ramas ni los tags de upstream.
2. Traer los commits de Xplus desde la rama anterior (`git cherry-pick` de los commits `feat`, `fix`, `ci` y `build` de `v4.18.0-xp`), resolviendo conflictos.
3. Revisar las funciones premium nuevas de `config/features.yml` y activarlas.
4. Cambiar la versión en `config/app.yml` y `package.json` a `4.19.0-xp`.
5. Seguir los pasos 2 a 5. En el compose de Dokploy, cambiar la etiqueta a `v4.19.0-xp`.
