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

---

## Hallazgos del código completo (análisis estático sobre las 845 líneas)

Bugs reales adicionales que solo se ven con el script entero:

1. **Reporte mentiroso por copy-paste** (536–537, 572–573): imprime `$sqlicount`
   para las categorías LFI y Blind (deberían ser `$lficount` y `$possibles`).
2. **Lógica de `FAIL` rota** (424–468): `FAIL` se reasigna en cada iteración, así
   que al final solo refleja la ÚLTIMA firma, no si hubo algún match.
3. **Rama `case` muerta** (446–448): `"include_path"` no existe en el array
   `SQLiREGEX` → nunca se alcanza.
4. **Variable fantasma** (697): usa `$TARGET` donde la variable real es
   `$SHAREDTARGET`.
5. **Comparación numérica como string** (331): `[ "$zz" \< 16 ]` compara en ASCII,
   no numéricamente.
6. **Fuga de temporales**: la limpieza final (832–836) olvida `$STORAGE4` y
   `$STORAGE5`.
7. **Blacklist triplicada y divergente** (205, 716, 772): viola DRY; `sourceforge.net`
   solo aparece en dos de las tres copias.

**Corrección al análisis previo:** los contadores `z`/`i` de `regex_check` SÍ están
sincronizados (no es un bug, solo código redundante). Lección: verifica antes de
afirmar, incluso en una auditoría.

---

## Alcance del proyecto: dónde está la línea (nota de ética del canal)

Visto el tool completo, su arquitectura es **descubrimiento masivo e indiscriminado
de objetivos** (dorking a buscadores) + **test automático de inyección** (`curl_magic`
/ `injector_tester_core`) contra sitios de terceros sin autorización ni alcance.

Decisión de proyecto, coherente con el enfoque de hacking ético del canal:

- ✅ **Sí trabajamos** (educativo/defensivo): análisis de código y bugs, higiene de
  Bash (Fases 0–2), explicación *conceptual* de cómo la detección por regex de
  errores funciona y **cómo defenderse** (desactivar errores verbosos, WAF, etc.).
- 🧪 **Demo en laboratorio propio**: reproducir los conceptos contra un objetivo
  intencionadamente vulnerable y local que controlemos (p. ej. DVWA/bWAPP en Docker),
  nunca contra Internet abierto.
- ⛔ **No reconstruimos** el motor funcional de dorking masivo ni el de inyección
  automatizada contra objetivos arbitrarios: un "mass scanner" sin alcance no se
  vuelve ético por refactorizarlo; una versión limpia y funcional es *más* dañina.

Esto no limita la serie — la hace mejor: el contraste "por qué este diseño es
irresponsable" ES la clase de ética más valiosa del canal.
