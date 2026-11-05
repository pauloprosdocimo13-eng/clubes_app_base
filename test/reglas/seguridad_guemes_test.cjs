const {before,after,test}=require('node:test');
const fs=require('node:fs'), path=require('node:path');
const {initializeTestEnvironment,assertSucceeds,assertFails}=require('@firebase/rules-unit-testing');
const {doc,setDoc,getDoc,getDocs,collection,updateDoc,serverTimestamp,setLogLevel}=require('firebase/firestore');
setLogLevel('silent');
if(process.env.FIRESTORE_EMULATOR_HOST!=='127.0.0.1:8185') throw Error('Solo emulador local');
let env;
before(async()=>{
 env=await initializeTestEnvironment({projectId:'demo-seguridad-guemes',firestore:{host:'127.0.0.1',port:8185,rules:fs.readFileSync(path.join(__dirname,'../../firestore.rules'),'utf8')}});
 await env.clearFirestore();
 await env.withSecurityRulesDisabled(async c=>{
  const d=c.firestore();
  for(const rol of ['admin','tesoreria','deportes','administracion','institucional','ingreso']) await setDoc(doc(d,`permisos_admin/${rol}@test.com`),{rol});
  await setDoc(doc(d,'permisos_admin/inactivo@test.com'),{rol:'admin',activo:false});
  for(const col of ['sorteos','prode_votos','socios','movimientos','auditoria_socios','reservas','sugerencias','_seguridad_carnet_publico']) await setDoc(doc(d,`${col}/privado`),{dni:'11222333',email:'privado'});
  await setDoc(doc(d,'noticias/publica'),{titulo:'Noticia'});
  await setDoc(doc(d,'configuracion/general'),{nombre:'Club'});
  await setDoc(doc(d,'configuracion/seguridad'),{clave_egresos:'no-publicar'});
  await setDoc(doc(d,'prode_fechas/abierta'),{estado:'ABIERTA'});
  await setDoc(doc(d,'prode_fechas/cerrada'),{estado:'CERRADA'});
 });
});
after(async()=>{if(env) await env.cleanup();});
const db=rol=>env.authenticatedContext(rol,{email:`${rol}@test.com`}).firestore();
test('anónimos, cuentas sin rol e inactivas no leen datos privados',async()=>{
 for(const d of [env.unauthenticatedContext().firestore(),db('desconocido'),db('inactivo')]) {
  for(const col of ['sorteos','prode_votos','socios','movimientos','auditoria_socios','reservas','sugerencias','permisos_admin','_seguridad_carnet_publico']) await assertFails(getDocs(collection(d,col)));
  await assertFails(getDoc(doc(d,'configuracion/seguridad')));
  await assertFails(setDoc(doc(d,'socios/nuevo'),{nombre:'No'}));
  await assertSucceeds(getDoc(doc(d,'noticias/publica')));
  await assertSucceeds(getDoc(doc(d,'configuracion/general')));
 }
});
test('caja opera socios y movimientos pero no roles ni deportes',async()=>{
 const d=db('tesoreria');
 await assertSucceeds(getDocs(collection(d,'socios')));
 await assertSucceeds(setDoc(doc(d,'movimientos/hoy'),{tipo:'ingreso',fecha:serverTimestamp()}));
 await assertFails(setDoc(doc(d,'permisos_admin/tesoreria@test.com'),{rol:'admin'}));
 await assertFails(setDoc(doc(d,'configuracion/permisos_roles'),{tesoreria:['Gestionar Plantel']}));
 await assertFails(setDoc(doc(d,'partidos/nuevo'),{rival:'No'}));
});
test('deportes no accede a caja; ingreso solo consulta socios y registra asistencia',async()=>{
 await assertFails(getDocs(collection(db('deportes'),'movimientos')));
 await assertFails(setDoc(doc(db('deportes'),'socios/nuevo'),{nombre:'No'}));
 await assertSucceeds(setDoc(doc(db('deportes'),'partidos_en_vivo/baby'),{activo:true}));
 await assertSucceeds(getDocs(collection(db('ingreso'),'socios')));
 await assertSucceeds(setDoc(doc(db('ingreso'),'asistencias/hoy'),{dni:'11222333'}));
 await assertFails(updateDoc(doc(db('ingreso'),'socios/privado'),{dni:'0'}));
});
test('matriz permite delegar un módulo; revocación se aplica a sesión existente',async()=>{
 const d=db('deportes');
 await assertSucceeds(setDoc(doc(db('admin'),'configuracion/permisos_roles'),{deportes:['Gestionar Plantel']}));
 await assertSucceeds(setDoc(doc(d,'jugadores/uno'),{nombre:'Jugador'}));
 await assertFails(setDoc(doc(d,'partidos_en_vivo/baby'),{activo:false}));
 await assertSucceeds(updateDoc(doc(db('admin'),'permisos_admin/deportes@test.com'),{activo:false}));
 await assertFails(setDoc(doc(d,'jugadores/dos'),{nombre:'No'}));
});
test('portal público no escribe reservas ni altera votaciones directamente',async()=>{
 const d=env.unauthenticatedContext().firestore();
 await assertFails(setDoc(doc(d,'reservas/turno'),{estado:'confirmada'}));
 await assertFails(setDoc(doc(d,'votaciones/partido'),{candidatos:[],total_votos:999}));
 await assertSucceeds(setDoc(doc(d,'sugerencias/una'),{texto:'Idea',fecha:serverTimestamp(),usuario_id:'anonimo',usuario_email:'Sin email',leido:false}));
 await assertFails(setDoc(doc(d,'sugerencias/otra'),{texto:'Idea',fecha:serverTimestamp(),leido:true}));
 const voto={fecha_id:'abierta',user_id:'dispositivo',nombre_usuario:'Prueba',predicciones:{},fecha_voto:serverTimestamp(),puntos:0};
 await assertFails(setDoc(doc(d,'prode_votos/uno'),voto));
 await assertFails(setDoc(doc(d,'prode_votos/dos'),{...voto,puntos:100}));
 await assertFails(setDoc(doc(d,'prode_votos/tres'),{...voto,fecha_id:'cerrada'}));
});

test('auditoría no admite suplantación ni modificación posterior',async()=>{
 const d=db('tesoreria');
 await assertSucceeds(setDoc(doc(d,'auditoria_socios/nueva'),{usuario_uid:'tesoreria',fecha:serverTimestamp(),accion:'modificacion'}));
 await assertFails(setDoc(doc(d,'auditoria_socios/falsa'),{usuario_uid:'admin',fecha:serverTimestamp()}));
 await assertFails(updateDoc(doc(d,'auditoria_socios/nueva'),{accion:'otra'}));
 await assertFails(getDoc(doc(d,'configuracion/seguridad')));
});

test('rifas y Prode conservan administración autorizada sin publicar compradores ni participantes',async()=>{
 const invitado=env.unauthenticatedContext().firestore();
 for(const col of ['sorteos','prode_votos']) {
  await assertFails(getDoc(doc(invitado,`${col}/privado`)));
  await assertSucceeds(getDocs(collection(db('admin'),col)));
 }
 await assertSucceeds(setDoc(doc(db('tesoreria'),'sorteos/rifa'),{compradores:{}}));
 await assertFails(setDoc(doc(db('tesoreria'),'prode_votos/voto'),{puntos:100}));
 await assertSucceeds(setDoc(doc(db('admin'),'configuracion/permisos_roles'),{institucional:['Gestión Prode']}));
 await assertSucceeds(setDoc(doc(db('institucional'),'prode_votos/voto'),{puntos:100}));
 await assertFails(getDocs(collection(db('institucional'),'sorteos')));
});
