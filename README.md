# Mediateca

Servidor de medios propio, para reemplazar Jellyfin. Corre en el NAS, en Docker,
y lee los archivos de `/mnt/data/multimedia` sin copiarlos ni transcodificarlos.

Hoy hace **música**. El video viene después.

## Cómo está armado

La música sale de la biblioteca de [beets](https://beets.io) que ya vive en el
NAS. `Beets::Library` la lee (read-only) y devuelve value objects;
`Music::Importer` los espeja en el catálogo propio. El importer recibe cualquier
objeto que responda `#albums`, así que beets es *una* fuente y no *la* fuente:
los ~270 FLAC que beets todavía no conoce van a entrar detrás de la misma
interfaz.

Los bytes nunca pasan por Ruby. En producción Rails solo nombra el archivo
(`X-Sendfile`) y **Thruster** lo sirve, con soporte de `Range` — o sea, el
reproductor puede hacer seek sin bajar el FLAC entero.

`MediaFile` es el límite de confianza: los paths salen de la base, y él rechaza
cualquiera que caiga fuera de la raíz de medios (`..`, paths absolutos,
directorios hermanos con el mismo prefijo, symlinks que apuntan afuera).

Nada se transcodifica: los FLAC se sirven crudos y todos los browsers modernos
los reproducen nativamente.

## Desarrollo

```bash
bin/setup            # dependencias, base, assets
bin/dev              # servidor local
bin/rails test       # la suite
bin/ci               # lo mismo que corre GitHub Actions
```

Los tests no tocan el NAS: `Beets::Library` corre contra bases SQLite que se
arman en el momento, y `MEDIA_ROOT` apunta a un par de FLAC falsos en
`test/fixtures/media`.

Para levantar la app con tu música real:

```bash
scp nas:/mnt/data/beets/musiclibrary.db /tmp/
BEETS_DATABASE=/tmp/musiclibrary.db bin/rails music:import
```

## Deploy

`kamal-proxy` se queda con el `:80` del NAS. Jellyfin sigue vivo en `:8096`
mientras dure la migración.

Antes del primer deploy, una sola vez:

```bash
# 1. Un token de GitHub con permiso para pushear imágenes a ghcr.io
gh auth refresh -s write:packages

# 2. Guardalo en el Keychain (nunca en un archivo)
security add-generic-password -a gstn-caruso -s mediateca-ghcr -w "$(gh auth token)"

# 3. Que .kamal/secrets (gitignoreado) lo lea de ahí:
#      KAMAL_REGISTRY_PASSWORD=$(security find-generic-password -a gstn-caruso -s mediateca-ghcr -w)
#      RAILS_MASTER_KEY=$(cat config/master.key)

# 4. Liberar el :80 — nginx hoy proxea a Jellyfin, que sigue accesible en :8096
ssh nas 'sudo systemctl disable --now nginx'
```

Después:

```bash
bin/kamal setup      # la primera vez
bin/kamal deploy     # las siguientes
bin/kamal import     # importa la biblioteca de beets al catálogo
bin/kamal logs
```

La imagen se buildea **en el NAS**, que es amd64: cross-compilar desde la Mac
(arm64) con QEMU funciona pero es mucho más lento.

La música se monta read-only y bajo el mismo path que en el host, así un path
guardado en el catálogo significa lo mismo adentro y afuera del contenedor.
