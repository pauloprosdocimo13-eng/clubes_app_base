const {before,after,test}=require('node:test');
const fs=require('node:fs');
const path=require('node:path');
const {initializeTestEnvironment,assertSucceeds,assertFails}=require('@firebase/rules-unit-testing');
const {doc,setDoc,updateDoc,getDoc,Timestamp,serverTimestamp,setLogLevel}=require('firebase/firestore');
setLogLevel('silent');
if(process.env.FIRESTORE_EMULATOR_HOST !== '127.0.0.1:8185') throw Error('Solo emulador local');
let env;
before(async()=>{
 env=await initializeTestEnvironment({projectId:'demo-fechas-legacy',firestore:{host:'127.0.0.1',port:8185,rules:fs.readFileSync(path.join(__dirname,'../../firestore.rules'),'utf8')}});
 await env.clearFirestore();
 await env.withSecurityRulesDisabled(async ctx=>{
  await setDoc(doc(ctx.firestore(),'configuracion/permisos_roles'),{tesoreria:['Caja y Finanzas'],administracion:['Caja y Finanzas']});
  for(const rol of ['admin','tesoreria','administracion']) await setDoc(doc(ctx.firestore(),`permisos_admin/${rol}@test.com`),{rol});
 });
});
after(async()=>{if(env) await env.cleanup();});
const db=rol=>env.authenticatedContext(rol,{email:`${rol}@test.com`}).firestore();
const movimiento=(uid,fecha)=>({tipo:'ingreso',origen:'manual',fecha,fecha_registro:serverTimestamp(),admin_uid:uid,monto:100});
test('Güemes limita a hoy al operador sin permiso de fecha',async()=>{
 const ayer=Timestamp.fromMillis(Date.now()-86400000);
 const manana=Timestamp.fromMillis(Date.now()+86400000);
 await assertSucceeds(setDoc(doc(db('tesoreria'),'movimientos/hoy'),movimiento('tesoreria',serverTimestamp())));
 await assertFails(setDoc(doc(db('tesoreria'),'movimientos/ayer'),movimiento('tesoreria',ayer)));
 await assertFails(setDoc(doc(db('tesoreria'),'movimientos/manana'),movimiento('tesoreria',manana)));
 await assertSucceeds(setDoc(doc(db('admin'),'movimientos/ayer'),movimiento('admin',ayer)));
 await assertFails(updateDoc(doc(db('tesoreria'),'movimientos/hoy'),{fecha:ayer}));
 await assertFails(updateDoc(doc(db('tesoreria'),'movimientos/hoy'),{tipo:'egreso'}));
 await assertFails(updateDoc(doc(db('admin'),'movimientos/hoy'),{fecha_registro:ayer}));
 await assertSucceeds(updateDoc(doc(db('admin'),'movimientos/hoy'),{fecha:ayer}));
 await assertFails(setDoc(doc(db('tesoreria'),'movimientos/suplantado'),movimiento('admin',serverTimestamp())));
 await assertSucceeds(setDoc(doc(db('tesoreria'),'movimientos/cuota'),{tipo:'ingreso',fecha:serverTimestamp()}));
 await assertSucceeds(setDoc(doc(db('tesoreria'),'movimientos/gasto'),{tipo:'egreso',fecha:ayer}));
 await assertSucceeds(updateDoc(doc(db('tesoreria'),'movimientos/gasto'),{fecha:manana}));
 await assertFails(updateDoc(doc(db('tesoreria'),'movimientos/gasto'),{tipo:'ingreso'}));
});
test('regla general no permite elevar rol ni escritura pública de caja',async()=>{
 await assertFails(updateDoc(doc(db('tesoreria'),'permisos_admin/tesoreria@test.com'),{rol:'admin'}));
 await assertFails(setDoc(doc(db('nuevo'),'permisos_admin/nuevo@test.com'),{rol:'admin'}));
 await assertSucceeds(setDoc(doc(db('admin'),'permisos_admin/nuevo@test.com'),{rol:'deportes'}));
 const publico=env.unauthenticatedContext().firestore();
 await assertFails(setDoc(doc(publico,'movimientos/publico'),movimiento('admin',serverTimestamp())));
 await assertFails(setDoc(doc(publico,'reservas/prueba'),{nombre:'Prueba'}));
 await assertSucceeds(setDoc(doc(db('tesoreria'),'socios/prueba'),{nombre:'Prueba'}));
});

test('administrador delega y revoca fechas sin dar rol admin',async()=>{
 const ayer=Timestamp.fromMillis(Date.now()-86400000);
 const matriz=doc(db('admin'),'configuracion/permisos_roles');
 for(const rol of ['tesoreria','administracion']) {
  await assertSucceeds(updateDoc(matriz,{[rol]:['Caja y Finanzas','Cambiar fecha de ingresos']}));
  const destino=doc(db(rol),`movimientos/delegado-${rol}`);
  await assertSucceeds(setDoc(destino,movimiento(rol,ayer)));
  await assertSucceeds(updateDoc(destino,{fecha:Timestamp.fromMillis(Date.now()-172800000)}));
  await assertFails(updateDoc(destino,{fecha_registro:ayer}));
  await assertFails(updateDoc(destino,{tipo:'egreso'}));
  await assertFails(updateDoc(doc(db(rol),'configuracion/permisos_roles'),{[rol]:['Caja y Finanzas']}));
  await assertSucceeds(updateDoc(matriz,{[rol]:['Caja y Finanzas']}));
  await assertFails(setDoc(doc(db(rol),`movimientos/revocado-${rol}`),movimiento(rol,ayer)));
  await assertFails(updateDoc(destino,{fecha:ayer}));
 }
 await assertSucceeds(updateDoc(matriz,{tesoreria:['Cambiar fecha de ingresos']}));
 await assertFails(setDoc(doc(db('tesoreria'),'movimientos/sin-caja'),movimiento('tesoreria',ayer)));
});
