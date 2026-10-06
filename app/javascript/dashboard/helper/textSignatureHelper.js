// Short plain-text signature ("enviado por Fabián") that is always added to outgoing
// replies, configured per user in Profile settings and stored in ui_settings.text_signature.
//
// type:     'original' (feature off, the classic markdown signature applies),
//           'visible'  (pre-filled in the editor so the agent sees and can edit it),
//           'hidden'   (added only when the message is sent).
// position: 'start' (own line before the text), 'start_inline' (same line, before the text),
//           'end' (own line after the text).

export const TEXT_SIGNATURE_TYPES = ['original', 'visible', 'hidden'];
export const TEXT_SIGNATURE_POSITIONS = ['start', 'start_inline', 'end'];

export const DEFAULT_TEXT_SIGNATURE = {
  type: 'original',
  position: 'end',
  text: '',
};

export const getTextSignatureSettings = uiSettings => ({
  ...DEFAULT_TEXT_SIGNATURE,
  ...(uiSettings?.text_signature || {}),
});

export const isTextSignatureActive = settings =>
  settings.type !== 'original' && !!settings.text?.trim();

export const hasTextSignature = (body, settings) =>
  !!settings.text?.trim() && (body || '').includes(settings.text.trim());

/**
 * Returns the body with the signature placed according to the position.
 * A body that already contains the signature is returned untouched, so the
 * agent can move or keep it when it was pre-filled in the editor.
 */
export const applyTextSignature = (body, settings) => {
  if (!isTextSignatureActive(settings)) return body;

  const text = settings.text.trim();
  const content = (body || '').trim();
  if (content.includes(text)) return body;
  if (!content) return text;

  switch (settings.position) {
    case 'start':
      return `${text}\n\n${content}`;
    case 'start_inline':
      return `${text} ${content}`;
    default:
      return `${content}\n\n${text}`;
  }
};

/**
 * Editor content to start a new reply with when the signature is visible.
 */
export const textSignaturePrefill = settings => {
  if (!isTextSignatureActive(settings) || settings.type !== 'visible') {
    return '';
  }

  const text = settings.text.trim();
  switch (settings.position) {
    case 'start':
      return `${text}\n\n`;
    case 'start_inline':
      return `${text} `;
    default:
      return `\n\n${text}`;
  }
};

export const removeTextSignature = (body, settings) => {
  const text = settings.text?.trim();
  if (!text) return body || '';
  return (body || '').replace(text, '');
};
