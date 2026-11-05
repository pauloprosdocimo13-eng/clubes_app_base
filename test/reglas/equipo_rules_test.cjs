const {before,after,test} = require('node:test');
const fs = require('node:fs');
const path = require('node:path');
const {initializeTestEnvironment,assertSucceeds,assertFails} = require('@firebase/rules-unit-testing');
const {doc,setDoc,getDoc,deleteDoc,collection,getDocs,updateDoc,setLogLevel,Timestamp,serverTimestamp} = require('firebase/firestore');
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
test('respaldos privados y recuperación bloqueada hasta finalizar',async()=>{
 await env.withSecurityRulesDisabled(async ctx=>{
  await setDoc(doc(ctx.firestore(),'respaldos_club/prueba'),{estado:'imagenes'});
  await setDoc(doc(ctx.firestore(),'restauraciones_club/demo'),{operacion:'prueba'});
 });
 for(const uid of ['admin','super','entrada']) {
  await assertFails(getDoc(doc(db(uid),'respaldos_club/prueba')));
  await assertFails(setDoc(doc(db(uid),'restauraciones_club/demo'),{operacion:'otra'}));
  await assertFails(setDoc(doc(db(uid),'clubes/demo/socios/nuevo'),{nombre:'No'}));
  await assertFails(getDocs(collection(db(uid),'clubes/demo/socios')));
 }
 await env.withSecurityRulesDisabled(ctx=>deleteDoc(doc(ctx.firestore(),'restauraciones_club/demo')));
 await assertSucceeds(getDocs(collection(db('super'),'clubes/demo/socios')));
});

test('eliminación bloquea incluso al administrador',async()=>{
 await env.withSecurityRulesDisabled(ctx=>setDoc(doc(ctx.firestore(),'eliminaciones_club/demo'),{estado:'usuarios'}));
 await assertFails(setDoc(doc(db('admin'),'clubes/demo/socios/nuevo'),{nombre:'No'}));
 await assertFails(getDocs(collection(db('super'),'clubes/demo/socios')));
});


test('ingresos sin permiso delegado: solo admin imputa otro día; auditoría inmutable', async()=>{
 await env.withSecurityRulesDisabled(ctx=>deleteDoc(doc(ctx.firestore(),'eliminaciones_club/demo')));
 const caja=db('caja'), admin=db('admin');
 const ayer=Timestamp.fromMillis(Date.now()-86400000);
 const manana=Timestamp.fromMillis(Date.now()+86400000);
 const datos=(uid,fecha)=>({tipo:'ingreso',origen:'manual',fecha,fecha_registro:serverTimestamp(),admin_uid:uid,monto:100});
 const ref=doc(caja,'clubes/demo/movimientos/fecha-caja');
 await assertSucceeds(setDoc(ref,datos('caja',serverTimestamp())));
 await assertFails(setDoc(doc(caja,'clubes/demo/movimientos/ayer'),datos('caja',ayer)));
 await assertFails(setDoc(doc(caja,'clubes/demo/movimientos/manana'),datos('caja',manana)));
 await assertFails(setDoc(doc(caja,'clubes/demo/movimientos/suplantado'),datos('admin',serverTimestamp())));
 await assertFails(setDoc(doc(caja,'clubes/demo/movimientos/sin-auditoria'),{tipo:'ingreso',origen:'manual',fecha:serverTimestamp()}));
 await assertSucceeds(setDoc(doc(admin,'clubes/demo/movimientos/retroactivo'),datos('admin',ayer)));
 await assertFails(updateDoc(ref,{fecha:ayer}));
 await assertFails(updateDoc(ref,{tipo:'egreso'}));
 await assertSucceeds(updateDoc(ref,{concepto:'Corrección de texto'}));
 await assertFails(updateDoc(doc(admin,'clubes/demo/movimientos/fecha-caja'),{fecha_registro:ayer}));
 await assertSucceeds(updateDoc(doc(admin,'clubes/demo/movimientos/fecha-caja'),{fecha:ayer}));
 await assertFails(setDoc(doc(db('ajeno'),'clubes/demo/movimientos/ajeno'),datos('ajeno',ayer)));
 await assertFails(setDoc(doc(env.unauthenticatedContext().firestore(),'clubes/demo/movimientos/publico'),datos('caja',serverTimestamp())));
 // Los cobros del padrón siguen funcionando con su timestamp del servidor.
 await assertSucceeds(setDoc(doc(caja,'clubes/demo/movimientos/cuota'),{tipo:'ingreso',fecha:serverTimestamp(),monto:10}));
});

test('fechas configurables por club para tesorería y otros roles; revocación inmediata',async()=>{
 const admin=db('admin'), ayer=Timestamp.fromMillis(Date.now()-86400000);
 const matriz=doc(admin,'clubes/demo/configuracion/permisos_roles');
 for(const [uid,rol] of [['caja','tesoreria'],['comunica','institucional']]) {
  await assertSucceeds(updateDoc(matriz,{[rol]:['Caja y Finanzas','Cambiar fecha de ingresos']}));
  const destino=doc(db(uid),`clubes/demo/movimientos/delegado-${uid}`);
  const data={tipo:'ingreso',origen:'manual',fecha:ayer,fecha_registro:serverTimestamp(),admin_uid:uid};
  await assertSucceeds(setDoc(destino,data));
  await assertSucceeds(updateDoc(destino,{fecha:Timestamp.fromMillis(Date.now()-172800000)}));
  await assertFails(updateDoc(destino,{fecha_registro:ayer}));
  await assertFails(updateDoc(destino,{tipo:'egreso'}));
  await assertFails(setDoc(doc(db(uid),'clubes/otro/movimientos/ajeno'),data));
  await assertFails(updateDoc(doc(db(uid),'clubes/demo/configuracion/permisos_roles'),{[rol]:[]}));
  await assertSucceeds(updateDoc(matriz,{[rol]:['Caja y Finanzas']}));
  await assertFails(setDoc(doc(db(uid),`clubes/demo/movimientos/revocado-${uid}`),data));
  await assertFails(updateDoc(destino,{fecha:ayer}));
 }
 await assertSucceeds(updateDoc(matriz,{tesoreria:['Cambiar fecha de ingresos']}));
 await assertFails(setDoc(doc(db('caja'),'clubes/demo/movimientos/sin-caja'),{tipo:'ingreso',fecha:ayer}));
});
