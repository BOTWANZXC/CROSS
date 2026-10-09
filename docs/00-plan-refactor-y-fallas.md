# Guion-maestro: análisis de fallas y plan por fases

> Serie: "¿Pueden mis ideas mejorar los scripts?" · Caso base: **BinGoo! v1** (Hood3dRob1n)
> Marco: hacking ético / bug bounty con alcance autorizado y uso responsable.

Este documento es el mapa de la serie: qué está mal en el script heredado y en
qué orden lo arreglamos. Cada fase = un vídeo (o módulo de clase).

---

## Análisis por partes

| Sección | Líneas | Rol | Estado |
|---|---|---|---|
| Configuración | 17–27 | Rutas a sqlmap/fimap, temp, finderlist | ✅ Parte 1 |
| Variables globales | 31–46 | `METH`, temporales, user-agents, `trapper` | ⚠️ |
| `bashtrap()` | 48–73 | Limpieza Ctrl-C + "self-kill" `ps\|grep\|kill` | 🔴 |
| `start_engine()` | 75–110 | Menú principal (`select`) | ⚠️ |
| Banners | 112–162 | Arte ASCII | ✅ |
| `g_finder`/`bing_dorker` | 173–198 | Scraping vía `lynx` | ⚠️ |
| `g_cleaner`/`bing_cleaner` | 184–211 | Parseo + blacklist gigante | 🔴 |
| `core()` | 213–289 | Orquestador: single vs mass scan | ⚠️ + diseño |
| `biglinks_funk` | 291–296 | Une resultados | ⚠️ |
| `lfi_reg`/`sqli_reg` | 298–314 | Formateo de hallazgos | ⚠️ |
| `statistic_count` | 316–340 | Heurística de SQLi ciego | ⚠️ |
| `regex_check` | 342–439+ | Array de ~75 firmas de error de BD | 🔴 bug real |

---

## TOP de fallas (priorizado)

### 🔴 Críticas
1. **Self-kill temerario** (65–68): `ps aux | grep "./bingoo" | kill -9` mata por
   coincidencia de texto; puede matar procesos ajenos.
2. **Bug de índice en el array** (355–356): `SQLiREGEX[10]` asignado dos veces →
   se pierde una firma; el bucle mezcla contadores `z` e `i`.
3. **`trap` solo en INT**: no cubre EXIT/TERM/HUP → temporales huérfanos. (✅ Parte 1)
4. **`trapper=0` lógica muerta**: nunca cambia; el `if` del trap es decorativo.

### 🟠 Robustez / corrección
5. `[ $METH == G ]` sin comillas y con `==` en `[ ]` → usar `[[ "$METH" == "G" ]]`.
6. `read DORK`/`read DORKFILE` sin `-r` ni validación.
7. Parseo mágico frágil: `cut -d' ' -f4`, `sed 's/9.//'`, `sed 's/.//'`.
8. `COUNT` sin inicializar en varias rutas → rompe con modo estricto.
9. `if [ "$?" == 0 ]` tras grep → usar `if grep -q ...`.
10. Aritmética con `expr`/`bc` donde basta `$(( ))`.

### 🟡 Calidad / mantenibilidad
11. UUOC (`cat X | grep ...`) en todo el script.
12. Abuso de `grep --color` para colorear texto → función `color()`.
13. Blacklist de ~40 dominios en un `grep -v` encadenado → archivo externo.
14. Globales sin `local` → difícil de testear.
15. `lynx` como motor de scraping → migrar a `curl`.
16. User-agents hardcodeados y de 2012 → archivo de config.

### 🔵 Diseño / uso responsable
17. "Mass Scan" indiscriminado sin scope ni límite → convertir en **opt-in con
    alcance obligatorio + rate-limiting**; explicarlo como lección de ética.
18. Sin throttling hacia los buscadores → añadir pausas y límites por defecto.

---

## Plan por FASES

- **Fase 0 — Baseline**: estructura de proyecto, ShellCheck en CI, tests con `bats`.
- **Fase 1 — Inicialización** ✅: config, rutas, temporales, trap. (`bingoo-modern.sh`)
- **Fase 2 — Utilidades**: `log`/`color`/`die`; eliminar el self-kill peligroso.
- **Fase 3 — Entrada y marco responsable**: `getopts`, validación, scope + rate-limit.
- **Fase 4 — Capa de red**: `lynx` → `curl`, user-agent configurable, throttling.
- **Fase 5 — Motor de búsqueda modular**: un proveedor por módulo.
- **Fase 6 — Parseo robusto**: fuera el `cut`/`sed` mágico; extracción fiable de URLs.
- **Fase 7 — Motor de firmas regex**: corregir índice duplicado; firmas desde archivo.
- **Fase 8 — Reporte estructurado**: salida JSON/CSV además de texto.
- **Fase 9 — Tests + CI + docs**: `bats`, GitHub Actions, README.

> Pendiente: el fragmento recibido corta en la línea 439 (dentro de `regex_check`).
> Al recibir el código completo se revisará el `case` de clasificación, los módulos
> `digger_recon`, `bing_geo_dorker`, `analyze_type` y el bloque final.
