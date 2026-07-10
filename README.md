# Mediateca

Servidor de medios propio, para reemplazar Jellyfin. Corre en Docker sobre el
NAS y lee los archivos de `/mnt/data/multimedia` sin copiarlos ni
transcodificarlos.

Hoy hace **música**, con una interfaz al estilo Spotify. El video viene después.

---

## Cómo está armado

El disco decide qué música existe; beets solo dice cómo se llama.

`Music::FilesystemSource` escanea la música y lee los tags de cada FLAC con
ffprobe: los 1171 archivos, no los 934 que beets conoce. `Beets::Library` aporta
lo que sabe. `Music::Library` los combina, y `Music::Importer` espeja el
resultado en el catálogo, de forma idempotente: el directorio identifica al
álbum y el path al track.

La carátula la elige el disco, no beets: beets había elegido la contratapa para
los seis álbumes de Almafuerte.

Los bytes nunca pasan por Ruby. En producción Rails solo nombra el archivo con
el header `X-Sendfile` y **Thruster** lo sirve, con soporte de `Range` — o sea,
el reproductor puede hacer seek sin bajar el FLAC entero. En desarrollo no hay
nada adelante, así que Rails sirve con `Rack::Files`, que también implementa
`Range`. La regla, escrita en `ServesMedia`: *quien sirve el archivo sirve
también el rango.*

`MediaFile` es el límite de confianza. Los paths salen de la base, y él rechaza
cualquiera que caiga fuera de la raíz de medios: `..`, paths absolutos,
directorios hermanos con el mismo prefijo (`/mnt/data-secreto` no está dentro de
`/mnt/data`) y symlinks que apuntan afuera.

Nada se transcodifica. Los FLAC se sirven crudos y todos los browsers modernos
los reproducen nativamente.

El player vive fuera del `<body>` que Turbo Drive reemplaza al navegar
(`data-turbo-permanent`), y la cola de reproducción se guarda **en el elemento
`<audio>`**, no en el controller de Stimulus — que Turbo destruye y reconstruye
en cada página. Por eso la música no se corta al cambiar de vista.

---

## Requisitos

| | |
|---|---|
| Ruby | 4.0.5 (`.ruby-version`). Ojo: no existe Ruby 3.5 estable — esa serie se renombró a 4.0 |
| Rails | 8.1.3 |
| Base | SQLite (primary, cache, queue, cable) |
| Docker | solo para deployar. Docker Desktop tiene que estar **corriendo**: Kamal levanta el registry local ahí |

---

## Desarrollo

```bash
bin/setup                # dependencias, base, assets
bin/dev                  # servidor local en :3000
bin/rails test           # 111 tests
bin/rails test:system    # 3 system tests con Chrome headless
bin/ci                   # todo lo que corre GitHub Actions
```

Los tests **nunca tocan el NAS**: `Beets::Library` corre contra bases SQLite que
se arman en el momento, y `MEDIA_ROOT` apunta a un par de FLAC falsos en
`test/fixtures/media`.

**Y no necesitan ffmpeg.** `Video::Playback` decide sin abrir nada;
`Video::Probe` y `Music::Tags` interpretan salida de ffprobe grabada en
`test/fixtures/ffprobe`; `Video::Conversion` arma el comando y otro lo corre.
Correr un proceso es una responsabilidad aparte, y vive en `Ffprobe`.

Los únicos que sí lo corren son los de `test/contracts/`, y son los únicos que
pueden verificar lo que nadie más: que ffprobe siga describiendo los archivos
como cuando grabamos su salida, y que ffmpeg entienda los argumentos que
armamos. Si ffmpeg no está, se saltean — salvo con `REQUIRE_FFMPEG=1`, que es
como los corre el CI, para que nunca queden verdes sin haber corrido.

Para levantar la app con tu música real, copiate la base de beets:

```bash
scp nas:/mnt/data/beets/musiclibrary.db /tmp/
BEETS_DATABASE=/tmp/musiclibrary.db bin/rails music:import
```

Los paths que guarda beets son absolutos (`/mnt/data/multimedia/...`), así que
en la Mac vas a ver el catálogo pero los archivos no van a existir. Para
reproducir de verdad, deployá.

---

## Preparar el NAS (una sola vez)

Kamal puede instalar Docker solo, pero solo si entra como root por SSH. En este
NAS root está denegado, así que se instala a mano:

```bash
ssh nas 'curl -fsSL https://get.docker.com | sudo sh'
ssh nas 'sudo usermod -aG docker gaston'   # para no necesitar sudo
```

**`/var` es una partición chica** (6,4 GB) y ahí van, por defecto, tanto el
`data-root` de Docker como el de containerd. Con dos imágenes y el build cache
se llena, y la app muere con `SQLite3::FullException: database or disk is full`.
`/srv` tiene 195 GB. Hay que mover **los dos** — mover solo el de Docker no
alcanza, porque desde Docker 23 las imágenes viven en el content store de
containerd:

```bash
ssh nas 'sudo systemctl stop docker.socket docker containerd

  sudo mkdir -p /srv/docker /srv/containerd
  sudo rsync -aHAX --remove-source-files /var/lib/docker/     /srv/docker/
  sudo rsync -aHAX --remove-source-files /var/lib/containerd/ /srv/containerd/
  sudo rm -rf /var/lib/docker /var/lib/containerd

  printf "{\n  \"data-root\": \"/srv/docker\"\n}\n" | sudo tee /etc/docker/daemon.json
  sudo sed -i "s|^disabled_plugins = \[\"cri\"\]|disabled_plugins = [\"cri\"]\n\nroot = \"/srv/containerd\"|" /etc/containerd/config.toml

  sudo systemctl start containerd docker'
```

**Liberar el `:80`.** kamal-proxy lo necesita, y ahí vivía el nginx que proxeaba
a Jellyfin. Jellyfin sigue accesible directo en `:8096`:

```bash
ssh nas 'sudo systemctl disable --now nginx'
```

---

## Deploy

```bash
cp .kamal/secrets.example .kamal/secrets   # no tiene secretos, solo lookups
open -a Docker                             # el registry local corre acá

bin/kamal setup      # la primera vez
bin/kamal deploy     # las siguientes
bin/kamal import     # escanea la música y la mete en el catálogo (~80s)
bin/kamal logs
bin/kamal console
```

El escaneo también corre solo, todas las madrugadas: `ScanMusicJob` a las 4am.

Y ya está en `http://192.168.1.7/`.

No hay token de registry ni imágenes privadas dando vueltas por internet: el
registry es local (`localhost:5555`), Kamal lo levanta como contenedor en tu
máquina y abre un port-forward SSH inverso para que el NAS pullee de su propio
localhost. La imagen nunca sale de la LAN.

La imagen se buildea **en el NAS**, que es amd64. Cross-compilar desde la Mac
(arm64) con QEMU funciona, pero es mucho más lento.

La música se monta read-only y **bajo el mismo path que en el host**, así un path
guardado en el catálogo significa lo mismo adentro y afuera del contenedor. El
contenedor corre como uid 1000, que en el NAS es `gaston`, dueño de los archivos.

### Tres trampas que ya pagamos

**El puerto 5000 no sirve en macOS.** El receptor de AirPlay (ControlCenter)
escucha en `*:5000` sobre IPv4 e IPv6. Docker bindea `127.0.0.1:5000`, pero
`localhost` resuelve primero a `::1`, así que el push del registry termina
hablándole a AirTunes, que contesta `403 Forbidden` con un `Server:
AirTunes/...` en el header. De ahí el `5555`.

**Kamal y un git en español.** Kamal decide si su clon de build ya existe
matcheando el error de git contra `already exists and is not an empty
directory`. Un git localizado dice otra cosa, el regex no matchea, y en vez de
resetear el clon Kamal lo borra y lo vuelve a clonar en **cada** deploy, después
de imprimir un `Error preparing clone` que asusta y no significa nada. `bin/kamal`
fija `LC_ALL=C` por eso: el deploy pasa de 79 s a 9 s.

**Rails 8.1 deja comentados los paths de SQLite de producción** en
`config/database.yml`. Sin completarlos el contenedor muere al arrancar con
`No database file specified`.

---

## CI

Seis jobs en GitHub Actions, en cada push y cada PR:

| Job | Qué hace |
|---|---|
| Tests | `bin/rails test` |
| Tests de sistema | Chrome headless, sube screenshots si falla |
| Estilo | RuboCop (rubocop-rails-omakase) con caché |
| Seguridad (Ruby) | Brakeman + bundler-audit |
| Seguridad (JavaScript) | `importmap audit` |
| Imagen Docker (amd64) | buildea la imagen, la levanta y verifica que `/up` conteste |

Ese último job existe porque un build que compila pero no arranca no prueba
nada, y un deploy no es el momento de enterarse.

Brakeman marca el `send_file` de `ServesMedia` porque el path viene de un
atributo del modelo. La categoría es correcta; el guardián que no ve es
`MediaFile`. Está ignorado con nota en `config/brakeman.ignore`.

---

## Qué falta

- **Video.** Ahí esperan 375 `.mkv`, 168 `.mp4` y 61 `.avi`. Muchos mkv son HEVC
  con audio FLAC 5.1 multipista y subtítulos ASS: no son direct-play en ningún
  browser. El plan acordado es remuxear con `ffmpeg -c copy` (cambiar el
  contenedor sin recomprimir el video), no transcodificar.
- **Búsqueda**, y una vista de álbumes que no pase por el artista.
