// Menú de atención Xplus para n8n (nodo Code, "Run Once for All Items").
// Recibe el webhook del Agent Bot de Chatwoot y devuelve, en orden, las llamadas
// a la API de Chatwoot que el nodo HTTP siguiente ejecuta.
//
// Para cambiar textos, opciones o equipos: editá CONFIG, TEXTOS y MENUS.

// ===================== CONFIGURACIÓN =====================
const CONFIG = {
  chatwootUrl: 'https://chatwoot.website',
  // Respuestas inválidas seguidas antes de pasar la conversación a un agente
  maxInvalidas: 3,
  // Equipo para quien se equivoca maxInvalidas veces (null = cualquier agente de la bandeja)
  equipoFallback: null,
};

const TEXTOS = {
  rodape:
    'A qualquer momento você pode digitar *Menu* para voltar ao menu principal ou *Encerrar* para finalizar o atendimento.',
  invalida: '❗ Opção inválida. Responda apenas com o *número* da opção desejada.',
  transferindo: 'Certo! Em instantes um atendente do setor vai te responder. 😊',
  encerrar: 'Atendimento encerrado. Obrigado pelo contato! 💙',
};

// Cada menú: titulo + opciones. Cada opción tiene un texto y UNA acción:
//   ir:      'clave'                 -> abre otro menú
//   equipo:  ID del equipo (o null)  -> pasa la conversación a ese equipo de Chatwoot
//   cerrar:  'texto'                 -> manda el texto y finaliza la conversación
// La opción 0 "Voltar" se agrega sola a todos los submenús (vuelve a `volver`, por defecto 'inicio').
// Los IDs de equipo están en Chatwoot: Configuración → Equipos (número en la URL).
const MENUS = {
  inicio: {
    titulo: 'Por gentileza, selecione *CORRETAMENTE* o setor desejado abaixo:',
    opciones: {
      1: { texto: 'Código Card / Ativação', ir: 'card' },
      2: { texto: 'Suporte Técnico Live (tv/box)', ir: 'live' },
      3: { texto: 'Suporte Técnico Vod (tv/box)', ir: 'vod' },
      4: { texto: 'Xplus Sat/Ghost', ir: 'sat' },
      5: { texto: 'Xplus Express', ir: 'express' },
    },
  },
  card: {
    titulo: '*Código Card / Ativação*\nEscolha uma opção:',
    opciones: {
      1: { texto: 'Falar com um atendente', equipo: null, mensaje: 'Certo! Um atendente de *Ativação* vai te responder em instantes. 😊' },
      2: {
        texto: 'Como ativar meu código',
        cerrar: 'Para ativar seu código: abra o app, vá em *Ativar Card*, digite o código e confirme. Se precisar de ajuda, é só escrever *Menu*. 💙',
      },
    },
  },
  live: {
    titulo: '*Suporte Técnico Live (tv/box)*\nEscolha uma opção:',
    opciones: {
      1: { texto: 'Canais não abrem / travando', equipo: null },
      2: { texto: 'Falar com um atendente', equipo: null },
    },
  },
  vod: {
    titulo: '*Suporte Técnico Vod (tv/box)*\nEscolha uma opção:',
    opciones: {
      1: { texto: 'Filmes / séries não carregam', equipo: null },
      2: { texto: 'Falar com um atendente', equipo: null },
    },
  },
  sat: {
    titulo: '*Xplus Sat/Ghost*\nEscolha uma opção:',
    opciones: {
      1: { texto: 'Falar com um atendente', equipo: null },
    },
  },
  express: {
    titulo: '*Xplus Express*\nEscolha uma opção:',
    opciones: {
      1: { texto: 'Falar com um atendente', equipo: null },
    },
  },
};

// Atributos de conversación donde el bot guarda en qué menú está el cliente
const ATTR_MENU = 'menu_actual';
const ATTR_INTENTOS = 'menu_intentos';

// ===================== LÓGICA (no hace falta tocar) =====================
const body = $input.first().json.body ?? $input.first().json;

const normalizar = valor =>
  String(valor ?? '')
    .normalize('NFD')
    .replace(/[̀-ͯ]/g, '')
    .replace(/[*_~]/g, '')
    .trim()
    .toLowerCase();

const renderMenu = clave => {
  const menu = MENUS[clave];
  const lineas = Object.entries(menu.opciones).map(([num, op]) => ` [ ${num} ] - ${op.texto}`);
  if (clave !== 'inicio') lineas.push(' [ 0 ] - Voltar');
  return `${menu.titulo}\n\n${lineas.join('\n')}\n\n${TEXTOS.rodape}`;
};

// Solo mensajes del cliente en conversaciones que todavía están con el bot (pendientes).
// Si un agente ya la tomó, el bot no interviene.
const conversacion = body.conversation;
if (
  body.event !== 'message_created' ||
  body.message_type !== 'incoming' ||
  body.private ||
  !conversacion ||
  conversacion.status !== 'pending'
) {
  return [];
}

const base = `${CONFIG.chatwootUrl}/api/v1/accounts/${body.account.id}/conversations/${conversacion.id}`;
const llamadas = [];
const enviar = texto =>
  llamadas.push({ json: { method: 'POST', url: `${base}/messages`, body: { content: texto, message_type: 'outgoing', private: false } } });
const guardar = (menu, intentos = 0) =>
  llamadas.push({
    json: { method: 'POST', url: `${base}/custom_attributes`, body: { merge: true, custom_attributes: { [ATTR_MENU]: menu, [ATTR_INTENTOS]: intentos } } },
  });
const pasarAEquipo = equipoId => {
  if (equipoId) llamadas.push({ json: { method: 'POST', url: `${base}/assignments`, body: { team_id: equipoId } } });
  // Una conversación pendiente que el bot abre pasa a los agentes (handoff) y entra a la auto-asignación
  llamadas.push({ json: { method: 'POST', url: `${base}/toggle_status`, body: { status: 'open' } } });
};
const cerrar = () => llamadas.push({ json: { method: 'POST', url: `${base}/toggle_status`, body: { status: 'resolved' } } });

const atributos = conversacion.custom_attributes || {};
const menuActual = MENUS[atributos[ATTR_MENU]] ? atributos[ATTR_MENU] : null;
const intentos = Number(atributos[ATTR_INTENTOS] || 0);
const texto = normalizar(body.content);
const numero = (texto.match(/^\[?\s*(\d{1,2})\s*\]?[.)\-\s]*$/) || [])[1];

if (texto === 'encerrar' || texto === 'finalizar') {
  enviar(TEXTOS.encerrar);
  guardar('', 0);
  cerrar();
} else if (!menuActual || texto === 'menu' || texto === 'menú') {
  // Primer mensaje de la conversación, o el cliente pidió el menú
  enviar(renderMenu('inicio'));
  guardar('inicio', 0);
} else {
  const menu = MENUS[menuActual];
  const opcion = numero === '0' && menuActual !== 'inicio' ? { ir: menu.volver || 'inicio' } : menu.opciones[numero];

  if (!opcion) {
    if (intentos + 1 >= CONFIG.maxInvalidas) {
      enviar(TEXTOS.transferindo);
      guardar('', 0);
      pasarAEquipo(CONFIG.equipoFallback);
    } else {
      enviar(`${TEXTOS.invalida}\n\n${renderMenu(menuActual)}`);
      guardar(menuActual, intentos + 1);
    }
  } else if (opcion.ir) {
    enviar(renderMenu(opcion.ir));
    guardar(opcion.ir, 0);
  } else if ('equipo' in opcion) {
    enviar(opcion.mensaje || TEXTOS.transferindo);
    guardar('', 0);
    pasarAEquipo(opcion.equipo);
  } else if (opcion.cerrar) {
    enviar(opcion.cerrar);
    guardar('', 0);
    cerrar();
  }
}

return llamadas;
