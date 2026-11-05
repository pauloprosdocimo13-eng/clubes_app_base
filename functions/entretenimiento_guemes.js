const functions=require('firebase-functions/v1');
const {getFirestore,FieldValue,Timestamp}=require('firebase-admin/firestore');
const {crearManejador}=require('./entretenimiento_guemes_core');
exports.entretenimientoGuemes=functions.region('southamerica-east1').runWith({timeoutSeconds:15,maxInstances:5}).https.onRequest(crearManejador({db:getFirestore(),FieldValue,Timestamp,proyecto:()=>process.env.GCLOUD_PROJECT||process.env.GOOGLE_CLOUD_PROJECT}));
