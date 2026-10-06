# Menú de atención con n8n

Cuando un cliente escribe, el bot le muestra el menú de sectores, navega los submenús y, según la opción, pasa la conversación a un equipo o la cierra con un mensaje. Mientras el cliente está en el menú, la conversación queda en **Pendientes** y los agentes no la reciben.

Archivos:

- `menu-xplus.n8n.json`: workflow para importar en n8n.
- `menu.js`: el mismo código del nodo *Menú Xplus*, para leerlo o versionarlo.

## Cómo funciona

1. Chatwoot manda cada mensaje de la bandeja al webhook de n8n (Agent Bot).
2. El nodo **Menú Xplus** decide la respuesta y devuelve las llamadas a la API de Chatwoot.
3. El nodo **Chatwoot API** las ejecuta en orden: enviar mensaje, guardar el menú actual, asignar equipo, pasar a agentes o resolver.

El menú actual del cliente se guarda en los atributos de la conversación `menu_actual` y `menu_intentos`.

| El cliente escribe | El bot hace |
|---|---|
| Su primer mensaje (cualquier texto) | Muestra el menú principal |
| El número de una opción | Abre el submenú, pasa a un equipo o cierra, según la opción |
| `0` dentro de un submenú | Vuelve al menú principal |
| `Menu` | Vuelve al menú principal |
| `Encerrar` | Se despide y resuelve la conversación |
| Algo inválido | "Opção inválida" y repite el menú; a la 3.ª vez pasa a un agente |
| Cualquier cosa después de pasar a un agente | Nada: la conversación ya es de los agentes |
| De nuevo, en una conversación resuelta | Chatwoot la vuelve a Pendientes y el bot muestra el menú principal |

## Instalación

1. **Crear el bot en Chatwoot.** Configuración → Bots → Agregar bot. Nombre "Menú Xplus" y URL del webhook temporal (se completa en el paso 4). Al guardarlo, copiá el **token de acceso** del bot.
2. **Importar en n8n.** Workflows → Import from file → `menu-xplus.n8n.json`.
3. **Credencial.** En el nodo *Chatwoot API*, credencial nueva de tipo **Header Auth**, llamada `Chatwoot Bot Xplus`: Name `api_access_token`, Value = el token del paso 1.
4. **Activar.** Activá el workflow y copiá la **Production URL** del nodo *Chatwoot Bot* (termina en `/webhook/xplus-menu`). Pegala como URL del webhook del bot en Chatwoot.
5. **Conectar a la bandeja.** Configuración → Bandejas → la bandeja (por ejemplo WhatsApp) → pestaña **Bot** → elegí "Menú Xplus" y guardá.

A partir de ese momento, las conversaciones nuevas de esa bandeja entran al menú. Para desactivarlo, quitá el bot de la bandeja.

## Configurar textos, submenús y equipos

Todo está arriba del código del nodo **Menú Xplus**:

- `CONFIG.chatwootUrl`: la URL de Chatwoot.
- `CONFIG.maxInvalidas`: respuestas inválidas antes de pasar a un agente.
- `CONFIG.equipoFallback`: equipo al que va quien se equivoca demasiado (`null` = cualquier agente).
- `TEXTOS`: pie del menú, opción inválida, transferencia y despedida.
- `MENUS`: un bloque por menú, con `titulo` y `opciones`. Cada opción lleva un `texto` y **una** acción:
  - `ir: 'clave'` abre otro menú.
  - `equipo: 3` pasa la conversación al equipo con ID 3. `equipo: null` la pasa a cualquier agente. Opcional: `mensaje: '...'` reemplaza el texto de transferencia.
  - `cerrar: 'texto'` manda el texto y resuelve la conversación.

La opción `[ 0 ] - Voltar` se agrega sola en los submenús. Un submenú dentro de otro submenú se arma con `ir`, y con `volver: 'clave'` en el submenú hijo para que el 0 vuelva al padre.

**ID de un equipo:** Configuración → Equipos → abrí el equipo; el número está en la URL (`/settings/teams/3/edit` → `3`). Cuando un equipo tiene la asignación automática activada y la bandeja también, la conversación se asigna a un agente **online** de ese equipo.

Después de editar, guardá el workflow; el cambio aplica al instante, sin deploy de Chatwoot.

## Probar sin afectar a los clientes

Conectá el bot a una bandeja de prueba (por ejemplo la del sitio web) antes de la de WhatsApp. En n8n, la pestaña **Executions** muestra cada mensaje procesado y las llamadas a Chatwoot.

En local, `docker/xplus/docker-compose.local.yaml` ya permite que Chatwoot llame a servicios de la red privada (`SAFE_FETCH_ALLOW_PRIVATE_NETWORK`). En producción no hace falta, porque n8n se llama por su URL pública.

## A tener en cuenta

- **Si n8n se cae**, las conversaciones nuevas quedan en Pendientes sin respuesta. Revisá Pendientes o configurá un workflow de errores en n8n que avise.
- **Fuera de horario**, el mensaje automático de Chatwoot sale igual. El menú sigue funcionando y la conversación espera en la cola del equipo hasta que haya agentes online.
- Los agentes ven las conversaciones del menú en el filtro **Pendientes**. Si toman una manualmente, el bot deja de responder en ella.
