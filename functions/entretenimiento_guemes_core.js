const crypto = require('node:crypto');
const hash = s => crypto.createHash('sha256').update(s).digest('hex');
const texto = v => typeof v === 'string' ? v.trim() : '';
const idValido = v => typeof v === 'string' && /^[^/]{1,150}$/.test(v);
const error = (status,mensaje) => Object.assign(new Error(mensaje),{status});
function sorteoPublico(id,data) {
  const cantidad = Number.isInteger(data.cantidad_numeros) && data.cantidad_numeros > 0 && data.cantidad_numeros <= 10000 ? data.cantidad_numeros : 100;
  return {id,titulo:texto(data.titulo),premio:texto(data.premio),precio:typeof data.precio==='number' && Number.isFinite(data.precio) && data.precio>=0 ? data.precio : 0,
    cantidad_numeros:cantidad,numeros_vendidos:[...new Set((Array.isArray(data.numeros_vendidos)?data.numeros_vendidos:[]).filter(n=>Number.isInteger(n)&&n>=0&&n<cantidad))],
    fecha_sorteo_ms: typeof data.fecha_sorteo?.toMillis==='function'?data.fecha_sorteo.toMillis():0};
}
function validarPronostico(fecha,predicciones) {
  if(fecha.estado!=='ABIERTA' || fecha.bloqueado===true) throw error(409,'El Prode está cerrado.');
  const partidos=fecha.partidos;
  if(!Array.isArray(partidos) || !partidos.length || partidos.length>100) throw error(409,'La fecha no está disponible.');
  if(!predicciones || typeof predicciones!=='object' || Array.isArray(predicciones)) throw error(400,'Pronóstico inválido.');
  const ids=partidos.map(p=>p.id);
  if(new Set(ids).size!==ids.length || !ids.every(idValido)) throw error(409,'La fecha no está disponible.');
  const claves=Object.keys(predicciones);
  if(claves.length!==ids.length || !claves.every(k=>ids.includes(k))) throw error(400,'Completá todos los partidos de esta fecha.');
  return Object.fromEntries(ids.map(id=>{
    const p=predicciones[id];
    if(!p || Array.isArray(p) || Object.keys(p).length!==2 || !['gl','gv'].every(k=>Number.isInteger(p[k]) && p[k]>=0 && p[k]<=99)) throw error(400,'Los goles deben ser enteros entre 0 y 99.');
    return [id,{gl:p.gl,gv:p.gv}];
  }));
}
function crearManejador({db,FieldValue,Timestamp,proyecto}) {
 return async (req,res)=>{
  res.set('Access-Control-Allow-Origin','*');res.set('Access-Control-Allow-Headers','Content-Type');res.set('Access-Control-Allow-Methods','POST, OPTIONS');res.set('Cache-Control','no-store');res.set('X-Content-Type-Options','nosniff');
  if(req.method==='OPTIONS') return res.status(204).send('');
  if(req.method!=='POST') return res.status(405).json({ok:false});
  if(proyecto()!=='club-guemes-2') return res.status(403).json({ok:false});
  const body=req.body;
  if(!body || typeof body!=='object' || Array.isArray(body) || Buffer.byteLength(JSON.stringify(body))>24000) return res.status(400).json({ok:false,mensaje:'Solicitud inválida.'});
  try {
    // Control compartido por IP sin guardar direcciones en claro.
    const limite=db.collection('_seguridad_entretenimiento').doc(hash((req.ip||'')+'|'+Math.floor(Date.now()/600000)));
    await db.runTransaction(async tx=>{
      const snap=await tx.get(limite);const intentos=snap.data()?.intentos||0;
      if(intentos>=300) throw error(429,'Esperá unos minutos antes de intentar nuevamente.');
      tx.set(limite,{intentos:intentos+1,expira_en:Timestamp.fromMillis(Date.now()+1200000)});
    });
    if(body.accion==='rifas') {
      let documentos;
      if(body.sorteoId!==undefined) {
        if(!idValido(body.sorteoId)) throw error(400,'Sorteo inválido.');
        const doc=await db.collection('sorteos').doc(body.sorteoId).get();
        documentos=doc.exists && doc.data().activo===true?[doc]:[];
      } else {
        documentos=(await db.collection('sorteos').where('activo','==',true).limit(100).get()).docs;
      }
      const rifas=documentos.map(d=>sorteoPublico(d.id,d.data())).sort((a,b)=>b.fecha_sorteo_ms-a.fecha_sorteo_ms);
      const config=(await db.collection('configuracion').doc('general').get()).data()||{};
      const telefono=texto(config.telefono_ventas||config.telefono_contacto).replace(/[^0-9]/g,'');
      return res.json({ok:true,rifas,telefono});
    }
    if(!['mi_prode','enviar_prode'].includes(body.accion) || !idValido(body.fechaId) || typeof body.token!=='string' || !/^[a-f0-9]{64}$/.test(body.token)) throw error(400,'Solicitud inválida.');
    const votoRef=db.collection('prode_votos').doc('seg_'+hash(body.fechaId+'|'+body.token));
    if(body.accion==='mi_prode') {
      const voto=(await votoRef.get()).data();
      return res.json({ok:true,voto:voto?{predicciones:voto.predicciones,puntos:voto.puntos||0}:null});
    }
    if(Object.keys(body).some(k=>!['accion','fechaId','token','nombre','predicciones'].includes(k))) throw error(400,'Solicitud inválida.');
    const nombre=texto(body.nombre);
    if(!nombre || nombre.length>100) throw error(400,'Ingresá un nombre válido.');
    const fechaRef=db.collection('prode_fechas').doc(body.fechaId);
    await db.runTransaction(async tx=>{
      const [fecha,voto]=await Promise.all([tx.get(fechaRef),tx.get(votoRef)]);
      if(voto.exists) throw error(409,'Ya registraste tu pronóstico en esta fecha.');
      if(!fecha.exists) throw error(404,'La fecha no existe.');
      const predicciones=validarPronostico(fecha.data(),body.predicciones);
      tx.create(votoRef,{fecha_id:body.fechaId,user_id:hash(body.token),nombre_usuario:nombre,predicciones,puntos:0,fecha_voto:FieldValue.serverTimestamp(),origen:'portal_seguro'});
    });
    return res.json({ok:true});
  } catch(e) {
    return res.status(e.status||503).json({ok:false,mensaje:e.status?e.message:'No se pudo completar la operación.'});
  }
 };
}
module.exports={crearManejador,sorteoPublico,validarPronostico};
