const functions = require('firebase-functions/v1');
const {getFirestore, FieldValue, Timestamp} = require('firebase-admin/firestore');
const crypto = require('node:crypto');
const hash = s => crypto.createHash('sha256').update(s).digest('hex');
exports.votarFiguraGuemes = functions.region('southamerica-east1').runWith({maxInstances: 5, timeoutSeconds: 15}).https.onRequest(async(req,res)=>{
  res.set('Access-Control-Allow-Origin','*');
  res.set('Access-Control-Allow-Headers','Content-Type');
  res.set('Access-Control-Allow-Methods','POST, OPTIONS');
  res.set('Cache-Control','no-store');
  if(req.method==='OPTIONS') return res.status(204).send('');
  if(req.method!=='POST') return res.status(405).json({ok:false});
  if((process.env.GCLOUD_PROJECT||process.env.GOOGLE_CLOUD_PROJECT)!=='club-guemes-2') return res.status(403).json({ok:false});
  const {votacionId,candidatoId,dispositivo}=req.body||{};
  if(![votacionId,candidatoId].every(v=>typeof v==='string' && /^[^/]{1,150}$/.test(v)) || typeof dispositivo!=='string' || !/^[a-zA-Z0-9_-]{16,150}$/.test(dispositivo)) return res.status(400).json({ok:false});
  const db=getFirestore();
  const ref=db.collection('votaciones').doc(votacionId);
  const marca=db.collection('_votos_figura').doc(hash(votacionId+'|'+dispositivo));
  const limite=db.collection('_seguridad_votos').doc(hash((req.ip||'')+'|'+Math.floor(Date.now()/600000)));
  try {
    await db.runTransaction(async tx=>{
      const [voto,anterior,contador]=await Promise.all([tx.get(ref),tx.get(marca),tx.get(limite)]);
      if(anterior.exists) throw Object.assign(Error('Ya registraste tu voto.'),{status:409});
      if((contador.data()?.intentos||0)>=60) throw Object.assign(Error('Esperá unos minutos antes de intentar nuevamente.'),{status:429});
      const data=voto.data();
      if(!data || data.estado!=='ABIERTA') throw Object.assign(Error('La votación no está abierta.'),{status:409});
      const candidatos=(data.candidatos||[]).map(c=>({...c}));
      const candidato=candidatos.find(c=>c.id_jugador===candidatoId);
      if(!candidato) throw Object.assign(Error('Candidato no disponible.'),{status:400});
      candidato.votos=(Number(candidato.votos)||0)+1;
      tx.update(ref,{candidatos,total_votos:(Number(data.total_votos)||0)+1});
      tx.create(marca,{fecha:FieldValue.serverTimestamp()});
      tx.set(limite,{intentos:(contador.data()?.intentos||0)+1,expira_en:Timestamp.fromMillis(Date.now()+1200000)});
    });
    return res.json({ok:true});
  } catch(e) {
    return res.status(e.status||503).json({ok:false,mensaje:e.status?e.message:'No se pudo registrar el voto.'});
  }
});
