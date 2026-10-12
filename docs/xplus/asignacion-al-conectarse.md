# Asignación automática al conectarse un agente

Chatwoot reparte una conversación solo en el momento en que se abre (cuando el bot la deriva) y solo entre los miembros de la bandeja que están **online en ese segundo**. Si no había nadie, la conversación quedaba en **No asignadas** hasta otro movimiento de la bandeja (otra conversación que se abre o se resuelve) o hasta el job de cada 30 minutos, que además solo recorre las bandejas con una política de asignación vinculada.

Xplus agrega el disparador que faltaba: cuando un agente pasa a estar disponible, se encola `AutoAssignment::AssignmentJob` para cada bandeja suya con asignación automática, y ese job reparte lo que estaba esperando (el mismo que corre en el handoff).

Dispara en dos casos:

- El agente cambia su estado a **Online** en el panel (`AccountUser#assign_waiting_conversations`).
- El agente vuelve a estar **presente** y su estado es Online: abre el panel, o la pestaña dormida vuelve a mandar el ping de presencia (`RoomChannel#update_subscription`). Con "auto offline" activado, la presencia vence a los 20 s sin ping (`PRESENCE_DURATION`), así que esto cubre las pestañas en segundo plano.

Lo hace `AutoAssignment::AgentOnlineService`. Solo actúa con `assignment_v2` activo (en Xplus lo está) y el job sigue coalescido por bandeja (una claim en Redis por job en vuelo), así que los pings cada 20 s no encolan de más.

## Lo que sigue siendo configuración, no código

- Los agentes tienen que ser **miembros de la bandeja** (Configuración → Bandejas → Colaboradores). La bandeja `SuporteOficialX` nació por API sin miembros y por eso nada se asignaba hasta el 12/10/2026.
- Cada agente tiene que ponerse **Online** al empezar el turno. Con "auto offline" desactivado el estado elegido se mantiene aunque cierre la pestaña.
- Vincular una **política de asignación** a la bandeja hace que el job de 30 minutos también la cubra.
