// ------------------------------
// IMPORTS
// ------------------------------
const { onDocumentUpdated, onDocumentCreated } = require("firebase-functions/v2/firestore");
const { getMessaging } = require("firebase-admin/messaging");
const { initializeApp } = require("firebase-admin/app");

initializeApp();

// --- CONFIGURACIÓN ---
// Para Güemes usa: 'guemes_general'
// Para la Genérica usa: 'general'
// IMPORTANTE: Asegúrate que coincida con lo que la App escucha en main.dart
const TEMA_NOTIFICACION = 'general'; 

// ==================================================================
// FUNCIÓN 1: NOTIFICAR PARTIDOS (Goles, Final, Suspensión)
// ==================================================================
exports.notificarGolODetalle = onDocumentUpdated(
  'partidos_en_vivo/{partidoId}',
  async (event) => {

    const nuevo = event.data.after.data();
    const viejo = event.data.before.data();
    const partidoId = event.params.partidoId;

    // Si el partido no está activo y tampoco finalizado → no notificamos
    if (!nuevo.activo && nuevo.estado !== 'FINALIZADO') return;

    const categoria = nuevo.categoria || 'Primera';
    const rival = nuevo.rival || 'Rival';

    let titulo = '';
    let cuerpo = '';
    let hayNotificacion = false;

    // 1. GOL LOCAL
    if (nuevo.goles_local > viejo.goles_local) {
      titulo = `⚽ ¡GOL DEL CLUB!`;
      cuerpo = `Cat. ${categoria}: Vamos ganando ${nuevo.goles_local} a ${nuevo.goles_visita} contra ${rival}!`;
      hayNotificacion = true;
    }

    // 2. GOL VISITANTE
    if (nuevo.goles_visita > viejo.goles_visita) {
      titulo = `⚠️ Gol de ${rival}`;
      cuerpo = `Cat. ${categoria}: El partido va ${nuevo.goles_local} - ${nuevo.goles_visita}.`;
      hayNotificacion = true;
    }

    // 3. FINAL DEL PARTIDO
    if (nuevo.estado === 'FINALIZADO' && viejo.estado !== 'FINALIZADO') {
      const gL = nuevo.goles_local;
      const gV = nuevo.goles_visita;

      let resultado = 'Empate';
      if (gL > gV) resultado = '¡GANAMOS!';
      if (gL < gV) resultado = 'Final del partido';

      titulo = `🏁 ${resultado}`;
      cuerpo = `Cat. ${categoria} terminó: Nosotros ${gL} - ${gV} ${rival}.`;
      hayNotificacion = true;
    }

    // 4. PARTIDO SUSPENDIDO
    if (nuevo.estado === 'SUSPENDIDO' && viejo.estado !== 'SUSPENDIDO') {
      titulo = `⛔ Partido Suspendido`;
      cuerpo = `El partido de la Cat. ${categoria} ha sido suspendido.`;
      hayNotificacion = true;
    }

    // 5. ENVIAR NOTIFICACIÓN
    if (hayNotificacion) {
      await enviarMensajePush(titulo, cuerpo, 'partido', partidoId);
    }

    return;
  }
);

// ==================================================================
// FUNCIÓN 3: NOTIFICAR NUEVAS NOTICIAS (AGREGADO)
// ==================================================================
exports.notificarNuevaNoticia = onDocumentCreated(
  'noticias/{noticiaId}',
  async (event) => {
    const noticia = event.data.data();

    if (!noticia) return;
    // Si la noticia tiene un campo 'visible' y es falso, ignoramos
    if (noticia.visible === false) return;

    // Título de la notificación
    const titulo = '📰 Nueva Noticia';
    // Cuerpo: Usamos el título de la noticia o el copete
    // Si es muy largo, Firebase lo corta solo, pero mejor mandamos el título que suele ser corto
    const cuerpo = noticia.titulo || noticia.copete || 'Entra para leer las últimas novedades del club.';
    const noticiaId = event.params.noticiaId;

    console.log(`Nueva noticia detectada: ${noticia.titulo}`);

    await enviarMensajePush(titulo, cuerpo, 'noticia', noticiaId);
  }
);

// ==================================================================
// FUNCIÓN NUEVA: NOTIFICAR AVISOS URGENTES
// ==================================================================
exports.notificarNuevoAviso = onDocumentCreated(
  'avisos/{avisoId}',
  async (event) => {
    const aviso = event.data.data();

    if (!aviso) return;

    // Título: Si es importante, le ponemos emojis de alerta
    let titulo = aviso.importante ? '🚨 AVISO URGENTE' : '📢 Nuevo Aviso';
    
    // Si el aviso tiene un título propio corto, lo usamos
    if (aviso.titulo) {
        titulo = `${titulo}: ${aviso.titulo}`;
    }

    // Cuerpo del mensaje
    const cuerpo = aviso.mensaje || 'Información importante del club.';
    const avisoId = event.params.avisoId;

    console.log(`Nuevo aviso detectado: ${titulo}`);

    // Enviamos usando la misma función auxiliar que ya tenías
    await enviarMensajePush(titulo, cuerpo, 'aviso', avisoId);
  }
);


// ==================================================================
// FUNCIÓN AUXILIAR
// ==================================================================
async function enviarMensajePush(titulo, cuerpo, tipo, idReferencia) {
  const mensaje = {
    notification: {
      title: titulo,
      body: cuerpo,
    },
    topic: TEMA_NOTIFICACION,
    data: {
      click_action: 'FLUTTER_NOTIFICATION_CLICK',
      tipo: tipo, // 'partido', 'aviso', 'noticia'
      id: idReferencia
    }
  };

  try {
    await getMessaging().send(mensaje);
    console.log(`Notificación enviada exitosamente: ${titulo}`);
  } catch (error) {
    console.error('Error enviando notificación:', error);
  }
}