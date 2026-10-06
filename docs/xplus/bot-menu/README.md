# Menú de atención con n8n

Cuando un cliente escribe, el bot le muestra el menú de sectores, navega los submenús y, según la opción, pasa la conversación a un equipo o la cierra con un mensaje. Mientras el cliente está en el menú, la conversación queda en **Pendientes** y los agentes no la reciben.

Está armado en dos partes, las dos ya creadas en https://n8n-chat.xplusapp.org (proyecto personal Xplus Admin):

- **La tabla "Menú Xplus"** (Overview → pestaña *Data tables*): los menús, una fila por opción. Es lo único que se edita en el día a día.
- **El workflow "Xplus - Menú de atención (Chatwoot)"** (https://n8n-chat.xplusapp.org/workflow/rY4GXXHjSkMQULCt, sin publicar): una línea recta que lee la tabla, decide la respuesta y llama a Chatwoot. No hace falta tocarlo.

Copias de respaldo en este repo: `menu-xplus.n8n.json` (el workflow) y `menu-xplus-tabla.csv` (la tabla).

## Editar el menú

Cada fila de la tabla es una opción:

| Columna | Qué es |
|---|---|
| `menu` | En qué menú aparece. `inicio` es el menú principal. |
| `opcion` | El número que escribe el cliente. |
| `texto` | Lo que se lee en el menú, al lado del número. |
| `accion` | `menu`: abre el menú de `abre_menu`. `equipo`: pasa la conversación a un agente. `cerrar`: manda `mensaje` y resuelve la conversación. |
| `abre_menu` | Solo con `accion` = `menu`: qué menú se abre. |
| `equipo_id` | Solo con `accion` = `equipo`: ID del equipo en Chatwoot. Vacío = cualquier agente de la bandeja. |
| `mensaje` | Lo que se le manda al cliente. Con `equipo`, si queda vacío se usa el texto de transferencia general. |

Además, cada menú tiene una fila con `accion` = `titulo`: su `texto` es el encabezado del menú. `\n` dentro del texto es un salto de línea.

- **Agregar una opción:** una fila nueva con el `menu`, el número y la acción.
- **Agregar un submenú:** filas nuevas con una clave nueva en `menu` (por ejemplo `planes`, con su fila `titulo` y sus opciones), y en el menú padre una opción con `accion` = `menu` y `abre_menu` = `planes`.
- **El `[ 0 ] - Voltar`** se agrega solo en todos los submenús y vuelve al menú principal. Para que vuelva a otro lado, agregá una fila con `opcion` = `0`, `accion` = `menu` y el `abre_menu` que quieras.

Los cambios en la tabla aplican al instante, sin guardar ni publicar el workflow.

**ID de un equipo:** en Chatwoot, Configuración → Equipos → abrí el equipo; el número está en la URL (`/settings/teams/3/edit` → `3`). Cuando el equipo y la bandeja tienen la asignación automática activada, la conversación se asigna a un agente **online** de ese equipo.

**Textos generales** (pie del menú, opción inválida, transferencia, despedida), máximo de respuestas inválidas y equipo para quien se equivoca demasiado: nodo **Configuración** del workflow.

## Cómo funciona

1. Chatwoot manda cada mensaje de la bandeja al webhook de n8n (Agent Bot). El nodo **Mensaje de Chatwoot** solo deja pasar mensajes del cliente en conversaciones pendientes; el resto no genera ejecuciones.
2. **Leer menús** trae las filas de la tabla y **Decidir respuesta** elige qué contestar según el menú en el que está el cliente.
3. **Enviar mensaje al cliente** y **Guardar menú del cliente** responden y guardan el menú actual en los atributos de la conversación (`menu_actual`, `menu_intentos`).
4. **¿Qué hacer después?** pasa la conversación a un agente (asignando el equipo si hay uno), la cierra, o espera la próxima respuesta del cliente.

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
2. **Credencial en n8n.** En el workflow, nodo *Enviar mensaje al cliente*, credencial nueva "Chatwoot Bot Xplus" con la plantilla de headers `{"headers":{"api_access_token":"{{api_key}}"}}` y como `api_key` el token del paso 1. Elegí la misma credencial en los otros cuatro nodos HTTP (*Guardar menú del cliente*, *Asignar equipo*, *Pasar a los agentes*, *Cerrar conversación*). Usá el token del **bot**, no el de un usuario: con un usuario los mensajes salen a nombre de un agente y cuentan como respuesta humana.
3. **Publicar** el workflow (botón *Publish*).
4. **Conectar a la bandeja.** Configuración → Bandejas → la bandeja (por ejemplo WhatsApp) → pestaña **Bot** → elegí "Menú Xplus" y guardá.

Para otra instancia de n8n: creá la tabla "Menú Xplus" importando `menu-xplus-tabla.csv`, importá `menu-xplus.n8n.json` (Workflows → Import from file), elegí la tabla en el nodo *Leer menús* y seguí los pasos de arriba.

Para desactivar el menú, quitá el bot de la bandeja.

## Probar sin afectar a los clientes

Conectá el bot a una bandeja de prueba (por ejemplo la del sitio web) antes de la de WhatsApp. En n8n, la pestaña **Executions** muestra cada mensaje procesado y las llamadas a Chatwoot.

En local, `docker/xplus/docker-compose.local.yaml` ya permite que Chatwoot llame a servicios de la red privada (`SAFE_FETCH_ALLOW_PRIVATE_NETWORK`). En producción no hace falta, porque n8n se llama por su URL pública.

## A tener en cuenta

- **Si n8n se cae**, las conversaciones nuevas quedan en Pendientes sin respuesta. Revisá Pendientes o configurá un workflow de errores en n8n que avise.
- **Fuera de horario**, el mensaje automático de Chatwoot sale igual. El menú sigue funcionando y la conversación espera en la cola del equipo hasta que haya agentes online.
- Los agentes ven las conversaciones del menú en el filtro **Pendientes**. Si toman una manualmente, el bot deja de responder en ella.
