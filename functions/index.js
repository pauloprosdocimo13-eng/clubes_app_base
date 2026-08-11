const { onDocumentCreated, onDocumentUpdated, onDocumentWritten } = require("firebase-functions/v2/firestore");
const { getMessaging } = require("firebase-admin/messaging");
const { initializeApp } = require("firebase-admin/app");
const { getFirestore } = require("firebase-admin/firestore");

initializeApp();

async function obtenerPrefijoNotificaciones() {
    try {
        const doc = await getFirestore().doc("configuracion/general").get();
        if (doc.exists) {
            const data = doc.data() || {};
            if (data.prefijo_notificaciones) return data.prefijo_notificaciones;
            if (data.prefijo_coleccion) return data.prefijo_coleccion;
        }
    } catch (e) {
        console.error("Error leyendo prefijo de notificaciones:", e);
    }
    return "guemes";
}

async function topicGeneral(fallback) {
    if (fallback) return fallback;
    const prefijo = await obtenerPrefijoNotificaciones();
    if (prefijo === "generico") return "general";
    return `${prefijo}_general`;
}

async function topicPartidos() {
    const prefijo = await obtenerPrefijoNotificaciones();
    if (prefijo === "generico") return "general_partidos";
    return `${prefijo}_partidos`;
}

// 1. FUNCIÓN PARA AVISOS
exports.notificarNuevoAviso = onDocumentCreated("avisos/{avisoId}", async (event) => {
    const aviso = event.data.data();
    if (!aviso || aviso.enviar_push === false) return;

    const tituloFinal = aviso.titulo
        ? (aviso.importante ? `🚨 ${aviso.titulo}` : aviso.titulo)
        : (aviso.importante ? "🚨 AVISO URGENTE" : "📢 Nuevo Aviso");

    const cuerpoFinal = aviso.mensaje || "Tenés información nueva en el club.";

    const payload = {
        notification: {
            title: tituloFinal,
            body: cuerpoFinal
        },
        topic: await topicGeneral(aviso.topic_destino),
        data: {
            click_action: "FLUTTER_NOTIFICATION_CLICK",
            tipo: "aviso",
            id: event.params.avisoId
        },
        android: { notification: { sound: "default" } },
        apns: { payload: { aps: { sound: "default" } } }
    };

    try {
        await getMessaging().send(payload);
        console.log(`✅ Push enviado: ${tituloFinal}`);
    } catch (e) { console.error("❌ Error en Aviso:", e); }
});

// 2. FUNCIÓN PARA NOTICIAS
exports.notificarNuevaNoticia = onDocumentCreated("noticias/{noticiaId}", async (event) => {
    const noticia = event.data.data();
    if (!noticia) return;
    if (noticia.enviar_push === false) return;

    const tituloNoticia = noticia.titulo || "Nueva Noticia";
    const cuerpoNoticia = noticia.resumen || noticia.bajada || "Leé la última novedad del club.";

    const payload = {
        notification: {
            title: `📰 ${tituloNoticia}`,
            body: cuerpoNoticia
        },
        topic: await topicGeneral(noticia.topic_destino),
        data: {
            click_action: "FLUTTER_NOTIFICATION_CLICK",
            tipo: "noticia",
            id: event.params.noticiaId
        },
        android: { notification: { sound: "default" } }
    };

    try {
        await getMessaging().send(payload);
        console.log(`✅ Push de noticia enviado: ${tituloNoticia}`);
    } catch (e) { console.error("❌ Error en Noticia:", e); }
});

/* =======================================================================
   3. FUNCIÓN PARA PARTIDOS EN VIVO (COMENTADA TEMPORALMENTE)
   Se desactiva porque la app ahora es institucional y no queremos 
   enviar notificaciones del minuto a minuto a todos los socios.
   ======================================================================= */
/*
exports.notificarEventoPartido = onDocumentWritten("partidos_en_vivo/{partidoId}", async (event) => {
    // Si el partido se borró (ej. al limpiar historial), no hacemos nada
    if (!event.data.after.exists) return;

    const despues = event.data.after.data();
    // Verificamos si ya existía antes para saber si es un partido nuevo o una actualización
    const antes = event.data.before.exists ? event.data.before.data() : null;

    let titulo = "";
    let cuerpo = "";

    const estadoAntes = antes ? antes.estado : null;
    const estadoDespues = despues.estado;

    // Solo disparamos la notificación si el estado del tiempo cambió
    if (estadoAntes !== estadoDespues) {
        if (estadoDespues === "1T") {
            titulo = "⚽ ¡Arranca el partido!";
            cuerpo = `El equipo ya está jugando contra ${despues.rival}.`;
        } else if (estadoDespues === "ENTRETIEMPO") {
            titulo = "⏱️ Entretiempo";
            cuerpo = `Resultado parcial: Güemes ${despues.goles_local} - ${despues.goles_visita} ${despues.rival}`;
        } else if (estadoDespues === "FINALIZADO" || estadoDespues === "FIN") {
            titulo = "🏁 Final del partido";
            cuerpo = `Resultado final: Güemes ${despues.goles_local} - ${despues.goles_visita} ${despues.rival}`;
        }
    }

    // Si hay un título armado, mandamos la notificación push
    if (titulo !== "") {
        const payload = {
            notification: { title: titulo, body: cuerpo },
            topic: await topicPartidos(),
            data: {
                click_action: "FLUTTER_NOTIFICATION_CLICK",
                tipo: "minuto_a_minuto",
                id: event.params.partidoId
            },
            android: { notification: { sound: "default" } }
        };
        try {
            await getMessaging().send(payload);
            console.log(`✅ Push de Partido enviado: ${titulo}`);
        } catch (e) { 
            console.error("❌ Error en Partido:", e); 
        }
    }
});
*/