# 🔧 Auditoría de Mejoras Técnicas - Observability Stack

**Estado actual:** 46 dashboards, 4 datasources principales (VM metrics/logs, SkyWalking, Grafana)
**Fecha:** 2026-03-04
**Objetivo:** 20 mejoras técnicas prioritarias para http://home.pin

---

## 📊 Análisis de Problemas Identificados

### Tier 1: CRÍTICO (Bloquean visibilidad)
Estos problemas impactan directamente en que los usuarios no vean datos o vean datos incorrectos.

1. **SkyWalking - Sin correlación de traces en Grafana**
   - **Problema:** `skywalking.jsonnet` solo muestra JVM metrics del OAP, no muestra traces
   - **Impacto:** Usuario no puede correlacionar errors en logs con traces de SkyWalking
   - **Solución:** Agregar panel de traces recientes con búsqueda por trace_id desde VictoriaLogs
   - **Esfuerzo:** Medio (requiere integración SkyWalking datasource)

2. **Logs panel - Sin formato de nivel/severidad**
   - **Problema:** `logs.jsonnet` usa panel genérico sin highlight de errors
   - **Impacto:** Difícil identificar rápidamente errores críticos en grandes volúmenes
   - **Solución:** Agregar field overrides para colorear por level (red=error, yellow=warning, etc)
   - **Esfuerzo:** Bajo

3. **Performance queries - Sin optimización (n+1 queries)**
   - **Problema:** `performance.jsonnet` ejecuta múltiples queries independientes
   - **Impacto:** Cargas lentas, especialmente en time ranges largos
   - **Solución:** Consolidar queries, agregar `interval:5m` donde sea apropiado
   - **Esfuerzo:** Medio

4. **Cardinality - Sin alertas automáticas de crecimiento**
   - **Problema:** `metrics-discovery.jsonnet` muestra estado, pero no alerta de explosión
   - **Impacto:** Puede pasar desapercibido hasta que storage se llena
   - **Solución:** Agregar stat con threshold para growth rate > 100 series/min
   - **Esfuerzo:** Bajo

5. **Dashboard huérfanos - Sin navegación desde home**
   - **Problema:** `cost-tracking.jsonnet`, `dashboard-usage.jsonnet` existen pero no son descubribles
   - **Impacto:** Usuarios no saben que dashboards existen
   - **Solución:** Crear dashboard de índice centralizado con tags navegables
   - **Esfuerzo:** Medio

### Tier 2: IMPORTANTE (Degradan UX)
Estos no rompen funcionalidad pero hacen el sistema tedioso.

6. **Links externos - Botones demasiado grandes**
   - **Problema:** `externalLinksPanel()` ocupa 6 celdas horizontales
   - **Impacto:** Desperdicia espacio valioso en dashboards
   - **Solución:** Reducir a botones pequeños (2x1), posicionar en esquina
   - **Esfuerzo:** Bajo

7. **Skywalking UI link - Hardcodeado**
   - **Problema:** En `skywalking.jsonnet` está `http://traces.pin` hardcodeado
   - **Impacto:** Si URL cambia, necesita editar jsonnet
   - **Solución:** Variable global en `common.libsonnet` con `$skywalking_ui_url`
   - **Esfuerzo:** Muy bajo

8. **Logs panel - Sin plugin de categorización**
   - **Problema:** Panel genérico sin agrupar por service/level
   - **Impacto:** Difícil filtrar cuando hay muchos servicios
   - **Solución:** Usar plugin `Grafana-Loki-datasource` si disponible, o agregar field filters
   - **Esfuerzo:** Bajo-Medio

9. **Stats panels - Sin unidades consistentes**
   - **Problema:** Algunos usan `short`, otros `bytes`, otros sin unidades
   - **Impacto:** Confuso comparar métricas
   - **Solución:** Crear standard enum en `common.libsonnet` (bytes, count, percent, latency_ms)
   - **Esfuerzo:** Bajo

10. **Alert Info panels - Sin links contextuales**
    - **Problema:** Texto estático en `alerts.jsonnet`, no linkea a runbooks
    - **Impacto:** On-call tiene que buscar manualmente cómo responder a alerts
    - **Solución:** Agregar links a wiki/runbooks en los info panels
    - **Esfuerzo:** Bajo

### Tier 3: ARQUITECTURA (Deuda técnica)
Mejoras que no afectan visibilidad pero simplificarían mantenimiento.

11. **Dashboard templates - Sin versionado**
    - **Problema:** Si cambias `common.libsonnet`, todos los dashboards se regeneran
    - **Impacto:** Risk de cambios inesperados
    - **Solución:** Agregar version tag en dashboard metadata
    - **Esfuerzo:** Bajo

12. **Queries - Sin caching de intermediate results**
    - **Problema:** Cada panel re-ejecuta queries, sin cache
    - **Impacto:** Lentitud en dashboards con muchos panels
    - **Solución:** Agregar cache hints en VictoriaMetrics queries (via `_start`/`_end` params)
    - **Esfuerzo:** Medio

13. **Panel naming - Sin convención consistente**
    - **Problema:** Nombres como "JVM Heap" vs "heap_used_bytes" vs "Memory Heap"
    - **Impacto:** Confusión al refactorizar
    - **Solución:** Estándar: `{Metric Type} - {Service} - {Context}` ej: "Latency - API Gateway - p99"
    - **Esfuerzo:** Bajo (documentación)

14. **Datasource variables - Sin fallback**
    - **Problema:** Si VictoriaLogs está down, panel falla silenciosamente
    - **Impacto:** Usuario no sabe qué pasó
    - **Solución:** Agregar error panel con mensaje "Logs unavailable, check VictoriaLogs"
    - **Esfuerzo:** Medio

15. **Thresholds - Sin contexto histórico**
    - **Problema:** Thresholds son hardcodeados (ej: latency > 500ms)
    - **Impacto:** Difícil saber si threshold es razonable
    - **Solución:** Agregar reference line con percentil histórico (p95 de último mes)
    - **Esfuerzo:** Medio

### Tier 4: OBSERVABILIDAD (Meta)
Estas mejoras son sobre la observabilidad de la observabilidad.

16. **Dashboard metrics - Sin tracking de uso**
    - **Problema:** No sabemos qué dashboards se usan y cuáles no
    - **Impacto:** Dashboards muertos se acumulan
    - **Solución:** Agregar evento en Grafana cuando alguien abre dashboard, pushear a VictoriaMetrics
    - **Esfuerzo:** Alto (requiere script externo)

17. **Query performance - Sin profiling**
    - **Problema:** No sabemos si slow downs vienen de Grafana o VictoriaMetrics
    - **Impacto:** Imposible optimizar sin data
    - **Solución:** Agregar dashboard con `duration_ms` metrics de queries ejecutadas
    - **Esfuerzo:** Medio

18. **Dashboard integrity - Sin validación**
    - **Problema:** Posible que un dashboard tenga query rota pero no lo sepas
    - **Impacto:** Data gaps invisibles
    - **Solución:** Script `verify-dashboards.js` que valida todas las queries
    - **Esfuerzo:** Bajo (ya existe, mejorar)

### Tier 5: ESTÉTICA (Mejora experiencia)
Sin impacto funcional pero mejora claridad visual.

19. **Panels - Sin tema visual consistente**
    - **Problema:** Algunos panels tienen fondo blanco, otros gris
    - **Impacto:** Se ve desorganizado
    - **Solución:** Aplicar tema Grafana dark mode, agregar color gradient backgrounds
    - **Esfuerzo:** Bajo

20. **Row headers - Sin iconografía consistente**
    - **Problema:** Algunos usan emojis, otros palabras simples
    - **Impacto:** Falta coherencia visual
    - **Solución:** Estándar: emoji + título ej: "📊 Status" "🔥 Errors" "⚡ Performance"
    - **Esfuerzo:** Muy bajo

---

## 🎯 Matriz de Priorización

| ID  | Problema | Tier | Esfuerzo | Impacto | Prioridad |
|-----|----------|------|----------|---------|-----------|
| 1   | SkyWalking traces | 1 | M | Alto | 🔴 P0 |
| 2   | Logs colorización | 1 | B | Alto | 🔴 P0 |
| 3   | Performance queries | 1 | M | Alto | 🔴 P0 |
| 4   | Cardinality alerts | 1 | B | Medio | 🟠 P1 |
| 5   | Dashboard index | 1 | M | Medio | 🟠 P1 |
| 6   | Links button resize | 2 | B | Bajo | 🟡 P2 |
| 7   | SkyWalking URL var | 2 | V | Bajo | 🟡 P2 |
| 8   | Logs categorization | 2 | B-M | Medio | 🟡 P2 |
| 9   | Units standard | 2 | B | Bajo | 🟡 P2 |
| 10  | Alert runbook links | 2 | B | Bajo | 🟡 P2 |
| 11  | Dashboard versioning | 3 | B | Bajo | 🟢 P3 |
| 12  | Query caching | 3 | M | Medio | 🟢 P3 |
| 13  | Panel naming | 3 | B | Bajo | 🟢 P3 |
| 14  | Datasource fallback | 3 | M | Medio | 🟢 P3 |
| 15  | Threshold context | 3 | M | Bajo | 🟢 P3 |
| 16  | Dashboard usage tracking | 4 | A | Bajo | 🔵 P4 |
| 17  | Query profiling | 4 | M | Medio | 🔵 P4 |
| 18  | Dashboard validation | 4 | B | Alto | 🔵 P4 |
| 19  | Visual theme | 5 | B | Bajo | ⚪ P5 |
| 20  | Row iconography | 5 | V | Bajo | ⚪ P5 |

**Leyenda:** B=Bajo (< 30min), M=Medio (30min-2h), A=Alto (2h+), V=Muy Bajo (< 5min)

---

## 📋 Plan de Ataque (Sesión Actual)

**Objetivo:** Atacar todos los P0 y P1 en orden de dependencias

1. ✅ Análisis completado (este documento)
2. 🔄 Fase 1: Logs improvements (P0 crítico) - 30min
3. 🔄 Fase 2: SkyWalking integration (P0 crítico) - 45min  
4. 🔄 Fase 3: Dashboard index (P1) - 30min
5. 🔄 Fase 4: Quick wins P2 (links, vars) - 20min
6. 🔄 Fase 5: Validation & testing - 15min

**Tiempo total estimado:** ~2h 20min para P0+P1+algunos P2

---

## 🚀 Siguientes Pasos

- [ ] Fase 1: Mejorar logs con field overrides y colorización
- [ ] Fase 2: Agregar panel de traces a SkyWalking dashboard
- [ ] Fase 3: Crear dashboard index/home mejorado
- [ ] Fase 4: Refactor botones de links externos
- [ ] Fase 5: Ejecutar verify-dashboards.js y validar todos los cambios
