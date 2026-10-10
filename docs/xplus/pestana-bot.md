# Pestaña "Bot" e integración con SuporteOficialX

La lista de conversaciones tiene una pestaña **Bot** (Mías · Por responder · Transferidas · Sin asignar · **Bot** · Todas) con las conversaciones que **un bot está llevando ahora mismo**. En Chatwoot eso es el estado `pending`: una conversación nace `pending` cuando la bandeja tiene un agent bot activo, y pasa a `open` cuando el bot la deriva (`toggle_status open` con el token del bot) o cuando un agente la asume.

## Qué hace la pestaña

- **Lista**: conversaciones `pending` de las bandejas del agente, **sin importar el filtro de estado** (Abiertas / Resueltas / …). Mientras la pestaña está activa, el menú de estado se oculta y la cabecera muestra "Pendientes".
- **Contador** `bot_count` en `GET /api/v1/accounts/:id/conversations/meta` (y en `index` / `search`). Se calcula sobre el mismo alcance que las otras pestañas (bandeja, equipo, etiquetas) pero antes de aplicar el estado.
- **Tarjeta**: insignia verde "Bot" cuando la conversación está `pending` y asignada a un agent bot. Si el bot escribió la etapa en el atributo de conversación `sox_step`, la insignia muestra la etapa (por ejemplo "Menu: Horários").
- **Banner en la conversación**: "SuporteOficialX está conduciendo esta conversa · etapa: …" con el botón **Asumir conversa**: abre la conversación (`toggle_status open`) y la asigna al agente actual. Chatwoot dispara `conversation_status_changed` y `conversation_updated` al webhook de la cuenta, y con eso SuporteOficialX detiene el bot.
- **Tiempo real**: las conversaciones nuevas llegan por ActionCable como siempre; al cambiar a `open` salen de la pestaña Bot y entran en Mías / Sin asignar.

Permisos: la ven administradores, agentes y roles personalizados con `conversation_manage` o `conversation_unassigned_manage` (las conversaciones del bot no tienen agente humano asignado).

## Cómo la usa SuporteOficialX

1. Al conectar, SuporteOficialX crea (una sola vez) el **agent bot "SuporteOficialX"** sin `outgoing_url`, lo asigna a la bandeja API (`POST /inboxes/:id/set_agent_bot`) y crea las definiciones de atributos de conversación `sox_step`, `sox_flow`, `sox_title` y `sox_panel` (enlace al panel).
2. Cada conversación del cliente se crea por la **Public API** de la bandeja → nace `pending` con el bot como asignado y aparece en la pestaña Bot.
3. Los mensajes del cliente entran por la Public API (incoming); los del bot con el **token del agent bot** (`api_access_token`, `POST /conversations/:id/messages`), así se ven con el nombre y avatar del bot. Tras cada paso el bot actualiza `sox_step` (`POST /conversations/:id/custom_attributes` con `merge=true`).
4. **Derivación**: nota privada con el resumen y los datos recogidos, etiquetas del flujo y `toggle_status open` con el token del bot (Chatwoot lo trata como `bot_handoff`: queda `open`, sin asignar, con `waiting_since`). La conversación pasa a Sin asignar.
5. **Fin del flujo** sin derivar: `toggle_status resolved` con el token del bot.
6. **Asumir desde Chatwoot**: abrir la conversación (botón Asumir, cambiar el estado o escribir) genera los webhooks de siempre; SuporteOficialX marca la conversación como atendida por humano y deja de ejecutar el bot.

Los mensajes que el propio bot envía vuelven por el webhook de la cuenta con `sender.type = agent_bot`; SuporteOficialX los ignora por el id del bot.

## Archivos

- `app/finders/conversation_finder.rb`: alcance `@bot_conversations` (antes del filtro de estado), `assignee_type=bot` y `bot_count`.
- `app/views/api/v1/accounts/conversations/{index,meta,search}.json.jbuilder`: `bot_count`.
- `app/javascript/dashboard/constants/{globals,permissions}.js`, `store/modules/{conversationPage,conversationStats}.js`, `store/modules/conversations/getters.js` (`getBotChats`).
- `app/javascript/dashboard/components/ChatList.vue`, `ChatListHeader.vue` (`statusFilterLocked`), `widgets/ChatTypeTabs.vue` (icono), `widgets/conversation/ConversationCard.vue` (insignia), `widgets/conversation/MessagesView.vue` (banner + Asumir).
- i18n: `chatlist.json` (`ASSIGNEE_TYPE_TABS.bot`, `BOT_BADGE`, `BOT_TOOLTIP`) y `conversation.json` (`BOT_HANDLING.*`) en `en`, `es`, `pt`, `pt_BR`.
- Specs: `spec/finders/conversation_finder_spec.rb`, `store/modules/specs/{conversationPage,conversationStats}`.

## Probar en local

`docker/xplus/setup_local.rb` crea la conversación "Rosa Con Bot" (pendiente, asignada al agent bot "SuporteOficialX", con `sox_step`). Con el stack local arriba (ver `DESARROLLO.md`, paso 3) tiene que verse en la pestaña Bot con la insignia "Menu: Horários", y el botón **Asumir conversa** tiene que pasarla a Mías.
