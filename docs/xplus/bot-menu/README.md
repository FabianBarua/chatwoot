# Menú de atención con n8n

Cuando un cliente escribe, el bot le muestra el menú de sectores, navega los submenús y, según la opción, pasa la conversación a un equipo o la cierra con un mensaje. Mientras el cliente está en el menú, la conversación queda en **Pendientes** y los agentes no la reciben.

El workflow ya está creado en n8n: **Xplus - Menú de atención (Chatwoot)**, en https://n8n-chat.xplusapp.org (proyecto personal Xplus Admin, sin publicar).

Archivos de respaldo en este repo:

- `menu-xplus.n8n.json`: el workflow para importar en otra instancia de n8n.
- `menu.js`: el mismo código del nodo de decisión, para leerlo o versionarlo.

## Cómo funciona

1. Chatwoot manda cada mensaje de la bandeja al webhook de n8n (Agent Bot). El nodo **Mensaje de Chatwoot** solo deja pasar mensajes del cliente en conversaciones pendientes; el resto no genera ejecuciones.
2. El nodo **Decidir respuesta del menú** decide la respuesta y devuelve las llamadas a la API de Chatwoot.
3. El nodo **Llamar API de Chatwoot** las ejecuta en orden: enviar mensaje, guardar el menú actual, asignar equipo, pasar a agentes o resolver.

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

1. **Crear el bot en Chatwoot.** Configuración → Bots → Agregar bot. Nombre "Menú Xplus" y URL del webhook `https://n8n-chat.xplusapp.org/webhook/xplus-menu`. Al guardarlo, copiá el **token de acceso** del bot.
2. **Credencial en n8n.** Abrí el workflow, nodo *Llamar API de Chatwoot*, credencial nueva "Chatwoot Bot Xplus" con la plantilla de headers `{"headers":{"api_access_token":"{{api_key}}"}}` y como `api_key` el token del paso 1. Usá el token del **bot**, no el de un usuario: con un usuario los mensajes salen a nombre de un agente y cuentan como respuesta humana.
3. **Publicar.** Publicá el workflow (botón *Publish*). La URL del paso 1 es la Production URL del nodo *Mensaje de Chatwoot*.
4. Si usás el archivo `menu-xplus.n8n.json` en otra instancia: Workflows → Import from file, y en el paso 2 podés usar una credencial **Header Auth** (Name `api_access_token`, Value = token del bot).
5. **Conectar a la bandeja.** Configuración → Bandejas → la bandeja (por ejemplo WhatsApp) → pestaña **Bot** → elegí "Menú Xplus" y guardá.

A partir de ese momento, las conversaciones nuevas de esa bandeja entran al menú. Para desactivarlo, quitá el bot de la bandeja.

## Configurar textos, submenús y equipos

Todo está arriba del código del nodo **Decidir respuesta del menú**:

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
