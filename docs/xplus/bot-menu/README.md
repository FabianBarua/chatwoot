# Menú de atención con n8n

Cuando un cliente escribe, el bot le muestra el menú de sectores, navega los submenús y, según la opción, pasa la conversación a un equipo o la cierra con un mensaje. Mientras el cliente está en el menú, la conversación queda en **Pendientes** y los agentes no la reciben.

El workflow ya está creado en n8n: **Xplus - Menú de atención (Chatwoot)**, en https://n8n-chat.xplusapp.org/workflow/QGezeMrx6nn7LzvM (proyecto personal Xplus Admin, sin publicar). Es visual: cada menú y cada opción es un nodo, sin código.

`menu-xplus.n8n.json` es la copia de respaldo, para importar en otra instancia de n8n.

## Cómo funciona

El canvas está dividido en tres zonas de colores:

1. **Entrada.** Chatwoot manda cada mensaje de la bandeja al webhook de n8n (Agent Bot). El nodo **Mensaje de Chatwoot** solo deja pasar mensajes del cliente en conversaciones pendientes; el resto no genera ejecuciones. **Normalizar mensaje** limpia el texto y lee en qué menú está el cliente; **¿Qué pidió el cliente?** separa *Encerrar*, *Menu* o primer mensaje, y la elección de una opción; **¿En qué menú está?** manda a las opciones del menú actual.
2. **Menús.** Un nodo **Opciones de …** por menú, con una salida por número (y *Opción inválida*). Cada salida va a un nodo de acción: **Mostrar menú …** (abre ese menú), **Card 1: …** (pasa a un equipo) o **Card 2: …** (manda un texto y cierra). Las inválidas pasan por **Contar opción inválida** y, a la 3.ª, a un agente.
3. **Enviar a Chatwoot.** Manda el mensaje, guarda el menú actual y, según la acción, asigna el equipo y pasa a los agentes, o resuelve la conversación.

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
2. **Credencial en n8n.** Abrí el workflow, nodo *Enviar mensaje al cliente*, credencial nueva "Chatwoot Bot Xplus" con la plantilla de headers `{"headers":{"api_access_token":"{{api_key}}"}}` y como `api_key` el token del paso 1. Elegí la misma credencial en los otros cuatro nodos HTTP (*Guardar menú del cliente*, *Asignar equipo*, *Pasar a los agentes*, *Cerrar conversación*). Usá el token del **bot**, no el de un usuario: con un usuario los mensajes salen a nombre de un agente y cuentan como respuesta humana.
3. **Publicar.** Publicá el workflow (botón *Publish*). La URL del paso 1 es la Production URL del nodo *Mensaje de Chatwoot*.
4. Si usás el archivo `menu-xplus.n8n.json` en otra instancia: Workflows → Import from file, y en el paso 2 creá la misma credencial en los cinco nodos HTTP.
5. **Conectar a la bandeja.** Configuración → Bandejas → la bandeja (por ejemplo WhatsApp) → pestaña **Bot** → elegí "Menú Xplus" y guardá.

A partir de ese momento, las conversaciones nuevas de esa bandeja entran al menú. Para desactivarlo, quitá el bot de la bandeja.

## Configurar textos, submenús y equipos

Todo se edita abriendo nodos en el canvas:

- **Configuración**: URL de Chatwoot, pie del menú, textos de opción inválida, transferencia y despedida, `max_invalidas` (errores antes de pasar a un agente) y `equipo_fallback` (equipo para quien se equivoca demasiado; vacío = cualquier agente).
- **Mostrar menú …**: el texto que ve el cliente en cada menú, con la lista de opciones.
- **Nodos de acción** (*Card 1: …*, *Live 2: …*, etc.): cada uno tiene `accion`, `mensaje` y `equipo_id`.
  - `accion = equipo`: manda `mensaje` y pasa la conversación al equipo `equipo_id`. Vacío = cualquier agente de la bandeja.
  - `accion = cerrar`: manda `mensaje` y resuelve la conversación.

**Agregar una opción a un menú** (ejemplo: `3` en Card):

1. En **Opciones de Card**, agregá una regla `numero` es igual a `3` y renombrá la salida (*Rename Output*).
2. Duplicá un nodo de acción (por ejemplo *Card 1*), cambiale nombre, mensaje y equipo, y conectá la nueva salida a ese nodo y ese nodo a **Respuesta lista**.
3. En **Mostrar menú Card**, agregá la línea ` [ 3 ] - …` al texto.

**Agregar un submenú**: duplicá un **Mostrar menú …** y un **Opciones de …**; en el nuevo *Mostrar menú* poné `menu_siguiente` con una clave nueva (por ejemplo `card_planes`), agregá esa clave como regla en **¿En qué menú está?** y en **Volver a mostrar el menú**, conectadas al nuevo *Opciones de …* y al nuevo *Mostrar menú* respectivamente, y conectá la opción del menú padre al nuevo *Mostrar menú*. La salida `0 · Voltar` del nuevo *Opciones de …* va al *Mostrar menú* del padre.

**ID de un equipo:** Configuración → Equipos → abrí el equipo; el número está en la URL (`/settings/teams/3/edit` → `3`). Cuando un equipo tiene la asignación automática activada y la bandeja también, la conversación se asigna a un agente **online** de ese equipo.

Después de editar, guardá y volvé a publicar el workflow; el cambio aplica al instante, sin deploy de Chatwoot.

## Probar sin afectar a los clientes

Conectá el bot a una bandeja de prueba (por ejemplo la del sitio web) antes de la de WhatsApp. En n8n, la pestaña **Executions** muestra cada mensaje procesado y las llamadas a Chatwoot.

En local, `docker/xplus/docker-compose.local.yaml` ya permite que Chatwoot llame a servicios de la red privada (`SAFE_FETCH_ALLOW_PRIVATE_NETWORK`). En producción no hace falta, porque n8n se llama por su URL pública.

## A tener en cuenta

- **Si n8n se cae**, las conversaciones nuevas quedan en Pendientes sin respuesta. Revisá Pendientes o configurá un workflow de errores en n8n que avise.
- **Fuera de horario**, el mensaje automático de Chatwoot sale igual. El menú sigue funcionando y la conversación espera en la cola del equipo hasta que haya agentes online.
- Los agentes ven las conversaciones del menú en el filtro **Pendientes**. Si toman una manualmente, el bot deja de responder en ella.
