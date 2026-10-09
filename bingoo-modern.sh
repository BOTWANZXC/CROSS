#!/usr/bin/env bash
#
# bingoo-modern.sh — Refactor didáctico del bloque de inicialización de BinGoo! v1
# -----------------------------------------------------------------------------
# Proyecto educativo: "¿Pueden mis ideas mejorar los scripts?"
# Objetivo: enseñar buenas prácticas de Bash tomando como base una herramienta
#           clásica de auditoría (BinGoo! v1, de Hood3dRob1n).
#
# ESTE ARCHIVO cubre SOLO la PARTE 1: configuración, resolución de rutas,
# variables y manejo de señales/limpieza (trap). La lógica de dorking se
# construirá en vídeos posteriores, siempre bajo un marco de uso autorizado
# (bug bounty con scope, laboratorios propios, rate-limiting responsable).
#
# Lección central: la seguridad de una herramienta empieza por la calidad de
# su propio código. Un script frágil es un script peligroso.
# -----------------------------------------------------------------------------

# === 1. MODO ESTRICTO =========================================================
# El original no traía ninguno de estos. Son la primera línea de defensa:
#   -e            aborta ante cualquier comando que falle (salvo los manejados)
#   -u            tratar variables sin definir como error (adiós a typos mudos)
#   -o pipefail   un fallo en cualquier etapa de un pipe hace fallar al pipe
#   IFS seguro    evita el "word splitting" accidental por espacios/tabs
set -euo pipefail
IFS=$'\n\t'

# === 2. METADATOS =============================================================
readonly PROGRAM_NAME="bingoo-modern"
readonly PROGRAM_VERSION="0.1.0-edu"

# === 3. ANCLAJE DEL SCRIPT A SU PROPIO DIRECTORIO =============================
# El original usaba rutas relativas como "plugins/admin.lst", que solo
# funcionan si te paras justo en la carpeta correcta. Resolvemos la ruta REAL
# del script para poder localizar sus recursos desde cualquier directorio.
SCRIPT_SOURCE="${BASH_SOURCE[0]}"
while [[ -h "${SCRIPT_SOURCE}" ]]; do # resolver symlinks encadenados
  dir="$(cd -P "$(dirname "${SCRIPT_SOURCE}")" >/dev/null 2>&1 && pwd)"
  SCRIPT_SOURCE="$(readlink "${SCRIPT_SOURCE}")"
  [[ "${SCRIPT_SOURCE}" != /* ]] && SCRIPT_SOURCE="${dir}/${SCRIPT_SOURCE}"
done
# SC2155: declaramos y asignamos por separado para no enmascarar el código de
# salida del `cd ... && pwd` (si fallara, `readonly` lo ocultaría).
SCRIPT_DIR="$(cd -P "$(dirname "${SCRIPT_SOURCE}")" >/dev/null 2>&1 && pwd)"
readonly SCRIPT_DIR

# Recursos del propio proyecto, anclados al directorio del script (no al CWD).
# Antes: FINDERLIST=plugins/admin.lst   ->   ahora: ruta absoluta y predecible.
readonly ADMIN_FINDER_LIST="${SCRIPT_DIR}/plugins/admin.lst"

# === 4. DEPENDENCIAS EXTERNAS: AUTODETECCIÓN + OVERRIDE =======================
# El pecado original: SPATH=/home/hood3drob1n/fun/sqlmap (ruta fija de usuario).
# Aquí NO adivinamos dónde vive cada quien. Prioridad:
#   1) Variable de entorno que el usuario exporte (BINGOO_SQLMAP, etc.)
#   2) Autodetección en el PATH con `command -v`
#   3) Si no existe, se anota y se decide más tarde (no reventamos aquí).
#
# `command -v ... || true` evita que `set -e` nos mate si la herramienta falta.
readonly SQLMAP_BIN="${BINGOO_SQLMAP:-$(command -v sqlmap || true)}"
readonly FIMAP_BIN="${BINGOO_FIMAP:-$(command -v fimap || true)}"

# === 5. DIRECTORIO TEMPORAL RESPETANDO EL ENTORNO ============================
# Antes: JUNK=/tmp (hardcodeado, ignora $TMPDIR, /tmp es de escritura global).
# Respetamos $TMPDIR si existe; si no, caemos a /tmp como último recurso.
readonly WORK_TMPDIR="${TMPDIR:-/tmp}"

# === 6. ARCHIVOS TEMPORALES SEGUROS ==========================================
# Antes: nombres predecibles ("fooooobar1") y mezcla no portable de -p y -t.
# Ahora: un único directorio temporal privado, con nombre aleatorio de mktemp.
# Meter todo dentro de un directorio facilita una limpieza atómica (rm -rf uno).
# Se declaran vacías primero para que el trap de limpieza sea seguro aunque
# el script muera ANTES de crearlas (gracias a `set -u` usamos :- en cleanup).
RUN_TMPDIR=""

# === 7. LIMPIEZA GARANTIZADA VÍA TRAP ========================================
# El original dejaba temporales huérfanos ante un Ctrl-C. Aquí la limpieza se
# ejecuta en CUALQUIER salida (normal, error o señal) y es idempotente.
cleanup() {
  local exit_code=$?
  # ${VAR:-} + set -u: si RUN_TMPDIR nunca se asignó, no explota.
  if [[ -n "${RUN_TMPDIR:-}" && -d "${RUN_TMPDIR}" ]]; then
    rm -rf -- "${RUN_TMPDIR}"
  fi
  exit "${exit_code}"
}

# EXIT cubre la salida normal y la provocada por `set -e`.
# Las señales se redirigen a EXIT para no duplicar la limpieza.
trap cleanup EXIT
trap 'trap - EXIT; cleanup' INT TERM HUP

# === 8. UTILIDADES DE REGISTRO (logging) =====================================
# Mensajes a STDERR para no contaminar la salida de datos (buena práctica Unix).
log()  { printf '[%s] %s\n' "${PROGRAM_NAME}" "$*" >&2; }
warn() { printf '[%s] AVISO: %s\n' "${PROGRAM_NAME}" "$*" >&2; }
die()  { printf '[%s] ERROR: %s\n' "${PROGRAM_NAME}" "$*" >&2; exit 1; }

# === 9. INICIALIZACIÓN DEL ENTORNO DE EJECUCIÓN ==============================
init_workspace() {
  # Creamos el directorio temporal privado SOLO cuando ya lo necesitamos.
  RUN_TMPDIR="$(mktemp -d "${WORK_TMPDIR}/${PROGRAM_NAME}.XXXXXXXX")" \
    || die "No se pudo crear el directorio temporal en ${WORK_TMPDIR}"
  log "Directorio de trabajo temporal: ${RUN_TMPDIR}"

  # Validación de recursos propios (didáctico: avisar, no fallar en silencio).
  [[ -r "${ADMIN_FINDER_LIST}" ]] \
    || warn "Lista de administración no encontrada: ${ADMIN_FINDER_LIST}"

  # Reporte honesto del estado de dependencias externas.
  # SC2015: usamos if-then-else explícito en lugar de `A && B || C`, porque ese
  # patrón ejecuta C también cuando B falla. El if deja la intención clara.
  if [[ -n "${SQLMAP_BIN}" ]]; then
    log "sqlmap detectado: ${SQLMAP_BIN}"
  else
    warn "sqlmap no encontrado (exporta BINGOO_SQLMAP=/ruta si lo tienes)"
  fi
  if [[ -n "${FIMAP_BIN}" ]]; then
    log "fimap detectado: ${FIMAP_BIN}"
  else
    warn "fimap no encontrado (exporta BINGOO_FIMAP=/ruta si lo tienes)"
  fi
}

# === 10. PUNTO DE ENTRADA ====================================================
# Encapsular en main() evita ejecutar código al hacer `source` del script para
# testearlo, y mantiene el ámbito ordenado.
main() {
  log "${PROGRAM_NAME} v${PROGRAM_VERSION} — refactor didáctico (Parte 1)"
  init_workspace
  log "Entorno inicializado correctamente. (Lógica de dorking: próximos vídeos.)"
}

# Ejecuta main solo si el script se corre directamente, no si se hace `source`.
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
  main "$@"
fi
