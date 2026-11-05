const functions = require('firebase-functions/v1');
const {getAuth} = require('firebase-admin/auth');
const {getFirestore} = require('firebase-admin/firestore');
const {crearAutorizador} = require('./autorizar_imagen_guemes_core');
exports.autorizarImagenGuemes = functions.region('southamerica-east1')
  .runWith({timeoutSeconds:15,maxInstances:5}).https.onRequest(crearAutorizador({
    auth:getAuth(), db:getFirestore(), proyecto:()=>process.env.GCLOUD_PROJECT || process.env.GOOGLE_CLOUD_PROJECT,
  }));
