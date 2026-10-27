const {before,after,test} = require('node:test');
const fs = require('node:fs');
const path = require('node:path');
const {initializeTestEnvironment,assertSucceeds,assertFails} = require('@firebase/rules-unit-testing');
const {doc,setDoc,getDoc,collection,getDocs,updateDoc,setLogLevel} = require('firebase/firestore');
setLogLevel('silent');
if (!/^127\.0\.0\.1:8185$/.test(process.env.FIRESTORE_EMULATOR_HOST || '')) throw new Error('Solo ejecutar contra el emulador local 127.0.0.1:8185.');
let env;
before(async()=>{
 env=await initializeTestEnvironment({projectId:'demo-equipo',firestore:{host:'127.0.0.1',port:8185,rules:fs.readFileSync(path.join(__dirname,'../../firestore.tusede.rules'),'utf8')}});
 await env.clearFirestore();
 await env.withSecurityRulesDisabled(async ctx=>{
  const db=ctx.firestore();
  await Promise.all(Object.entries({
   'usuarios/admin':{rol:'admin',activo:true,clubIds:['demo']},
   'usuarios/super':{rol:'superadmin',activo:true,clubIds:[]},
   'usuarios/deporte':{rol:'deportes',activo:true,clubIds:['demo']},
   'usuarios/comunica':{rol:'institucional',activo:true,clubIds:['demo']},
   'usuarios/entrada':{rol:'ingreso',activo:true,clubIds:['demo']},
   'usuarios/caja':{rol:'tesoreria',activo:true,clubIds:['demo']},
   'usuarios/inactivo':{rol:'deportes',activo:false,clubIds:['demo']},
   'usuarios/ajeno':{rol:'admin',activo:true,clubIds:['otro']},
   'clubes/demo':{activo:true,origenDatos:'central'},
   'clubes/demo/configuracion/permisos_roles':{deportes:['Gestionar Plantel'],institucional:['Publicar Noticia'],ingreso:['Escanear Ingreso'],tesoreria:['Caja y Finanzas']},
   'clubes/demo/configuracion/general':{nombre:'Demo'},
   'clubes/demo/socios/uno':{nombre:'Socio'},
  }).map(([ruta,datos])=>setDoc(doc(db,ruta),datos)));
 });
});
after(async()=>{if(env) await env.cleanup();});
const db=uid=>env.authenticatedContext(uid).firestore();
test('deportes puede operar plantel pero no finanzas, socios ni otro club',async()=>{
 const d=db('deporte');
 await assertSucceeds(setDoc(doc(d,'clubes/demo/jugadores/uno'),{nombre:'Jugador'}));
 await assertSucceeds(getDocs(collection(d,'clubes/demo/jugadores')));
 await assertFails(getDocs(collection(d,'clubes/demo/socios')));
 await assertFails(setDoc(doc(d,'clubes/demo/movimientos/uno'),{importe:1}));
 await assertFails(setDoc(doc(d,'clubes/otro/jugadores/uno'),{nombre:'Otro'}));
});
test('comunicación restringida a noticias y acceso común a configuración',async()=>{
 const d=db('comunica');
 await assertSucceeds(setDoc(doc(d,'clubes/demo/noticias/uno'),{titulo:'Noticia'}));
 await assertSucceeds(getDoc(doc(d,'clubes/demo/configuracion/general')));
 await assertFails(setDoc(doc(d,'clubes/demo/jugadores/uno'),{nombre:'No'}));
 await assertFails(getDoc(doc(d,'clubes/demo/configuracion/pagos')));
});
test('control de ingreso lee socios pero no puede modificarlos',async()=>{
 const d=db('entrada');await assertSucceeds(getDoc(doc(d,'clubes/demo/socios/uno')));
 await assertFails(updateDoc(doc(d,'clubes/demo/socios/uno'),{nombre:'Alterado'}));
 await assertSucceeds(setDoc(doc(d,'clubes/demo/asistencias/una'),{presente:true}));
});
test('tesorería permite finanzas y socios; no puede elevar sus privilegios',async()=>{
 const d=db('caja');await assertSucceeds(setDoc(doc(d,'clubes/demo/movimientos/uno'),{importe:1}));
 await assertFails(updateDoc(doc(d,'usuarios/caja'),{rol:'superadmin'}));
 await assertFails(setDoc(doc(d,'clubes/demo/configuracion/permisos_roles'),{tesoreria:['Gestionar Plantel']}));
 await assertFails(getDocs(collection(d,'usuarios')));
});
test('admins pueden guardar matriz; ajenos e inactivos no operan el club',async()=>{
 await assertSucceeds(updateDoc(doc(db('admin'),'clubes/demo/configuracion/permisos_roles'),{administracion:['Padrón Socios']}));
 for(const uid of ['ajeno','inactivo']) await assertFails(getDocs(collection(db(uid),'clubes/demo/jugadores')));
 await assertFails(getDocs(collection(env.unauthenticatedContext().firestore(),'clubes/demo/socios')));
 await assertSucceeds(setDoc(doc(db('super'),'clubes/demo/configuracion/test'),{ok:true}));
});
test('cambio de rol y suspensión se aplican con sesión existente',async()=>{
 const d=db('deporte');await assertSucceeds(getDocs(collection(d,'clubes/demo/jugadores')));
 await env.withSecurityRulesDisabled(ctx=>updateDoc(doc(ctx.firestore(),'usuarios/deporte'),{activo:false}));
 await assertFails(getDocs(collection(d,'clubes/demo/jugadores')));
 await env.withSecurityRulesDisabled(ctx=>updateDoc(doc(ctx.firestore(),'usuarios/deporte'),{activo:true,rol:'institucional'}));
 await assertFails(getDocs(collection(d,'clubes/demo/jugadores')));
 await assertSucceeds(getDocs(collection(d,'clubes/demo/noticias')));
});
test('eliminación bloquea incluso al administrador',async()=>{
 await env.withSecurityRulesDisabled(ctx=>setDoc(doc(ctx.firestore(),'eliminaciones_club/demo'),{estado:'usuarios'}));
 await assertFails(setDoc(doc(db('admin'),'clubes/demo/socios/nuevo'),{nombre:'No'}));
 await assertFails(getDocs(collection(db('super'),'clubes/demo/socios')));
});
