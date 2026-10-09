# Parte 1 — Inicialización, variables y manejo de señales

> Serie: "¿Pueden mis ideas mejorar los scripts?" · Caso base: **BinGoo! v1** (Hood3dRob1n)
> Enfoque: hacking ético / bug bounty con alcance autorizado y uso responsable.

## Idea central del vídeo
**La seguridad de una herramienta empieza por la calidad de su propio código.**
Un script frágil (rutas fijas, temporales predecibles, sin limpieza) es un
script peligroso para quien lo ejecuta, antes incluso de tocar un objetivo.

## Los 8 fallos del bloque original y su corrección

| # | Fallo original | Corrección aplicada |
|---|----------------|---------------------|
| 1 | Rutas fijas `/home/hood3drob1n/...` | Autodetección con `command -v` + override por variable de entorno (`BINGOO_SQLMAP`, `BINGOO_FIMAP`) |
| 2 | Sin modo estricto | `set -euo pipefail` + `IFS=$'\n\t'` |
| 3 | `JUNK=/tmp` hardcodeado | Respeta `${TMPDIR:-/tmp}` |
| 4 | Temporales predecibles (`fooooobar1`) | Un único `mktemp -d` con nombre aleatorio; limpieza atómica |
| 5 | Ruta relativa `plugins/admin.lst` | Anclaje al directorio real del script vía `BASH_SOURCE` (con resolución de symlinks) |
| 6 | Nombres crípticos (`METH`, `SPATH`) | Nombres descriptivos + `readonly` para constantes |
| 7 | `trap` incompleto → temporales huérfanos | `trap cleanup EXIT` + `INT TERM HUP`, idempotente |
| 8 | `mktemp -p` + `-t` (no portable) | Un solo `mktemp -d` portable |

## Dos trampas que nos enseñó ShellCheck (bonus de clase)
- **SC2155**: `readonly VAR="$(cmd)"` **enmascara** el código de salida de `cmd`.
  Solución: declarar y asignar en líneas separadas.
- **SC2015**: `A && B || C` **no es** un if-then-else. Si `B` falla, `C` se
  ejecuta igual. Solución: `if/then/else` explícito.

## Cómo probarlo
```bash
shellcheck bingoo-modern.sh      # debe salir sin hallazgos
./bingoo-modern.sh               # inicializa y limpia sus temporales solo
BINGOO_SQLMAP=/ruta/sqlmap ./bingoo-modern.sh   # ejemplo de override
```

## Próximo vídeo
Parte 2: parseo de argumentos (`getopts`), validación de entrada y el marco de
uso responsable (scope, rate-limiting) antes de tocar la lógica de búsqueda.
