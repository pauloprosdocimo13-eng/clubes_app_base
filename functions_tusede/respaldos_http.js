"use strict";
const {onRequest} = require('firebase-functions/v2/https');
const {getAuth} = require('firebase-admin/auth');
const {getFirestore} = require('firebase-admin/firestore');
const {getStorage} = require('firebase-admin/storage');
const {crearServicioRespaldos} = require('./respaldos_club');
const {crearAdaptador} = require('./respaldo_adaptador');
const {PROJECT,SOURCE_BUCKET,BACKUP_BUCKET,ErrorRespaldo} = require('./respaldo_formato');
exports.administrarRespaldos = onRequest({region:'southamerica-east1',cors:true,timeoutSeconds:300,memory:'512MiB',maxInstances:3},async(req,res)=>{
  res.set('Cache-Control','no-store');
  if(req.method !== 'POST') return res.status(405).json({ok:false,mensaje:'Usá POST.'});
  if(process.env.GCLOUD_PROJECT !== PROJECT) return res.status(409).json({ok:false,mensaje:'Solo disponible en TuSede Central.'});
  let uid;
  try { const match=/^Bearer (.+)$/.exec(req.headers.authorization || ''); if(!match)throw Error(); uid=(await getAuth().verifyIdToken(match[1],true)).uid; }
  catch (_) { return res.status(401).json({ok:false,mensaje:'Iniciá sesión nuevamente.'}); }
  try {
    const db=getFirestore();
    const archivos=crearAdaptador({db,origen:getStorage().bucket(SOURCE_BUCKET),destino:getStorage().bucket(BACKUP_BUCKET)});
    const servicio=crearServicioRespaldos({db,archivos});
    const b=req.body || {}; let r;
    switch(b.accion){
      case 'listar': r=await servicio.listar(uid,b.antes); break;
      case 'crear': r=await servicio.crear(uid,b.clubId,b.operacionId); break;
      case 'continuar': r=await servicio.continuar(uid,b.operacionId); break;
      case 'restaurar': r=await servicio.restaurar(uid,b.respaldoId,b.destino,b.confirmacion); break;
      default: throw new ErrorRespaldo('Acción desconocida.',400);
    }
    return res.json({ok:true,...r});
  }catch(e){
    if(e instanceof ErrorRespaldo)return res.status(e.status).json({ok:false,mensaje:e.message});
    console.error('respaldos_club',e.code || e.name);
    return res.status(500).json({ok:false,mensaje:'No se completó el paso. Actualizá y retomá la operación. Si persiste, revisá la configuración del bucket y los registros del servicio.'});
  }
});
