const carpetas = {
  socios:'Padrón Socios', socios_hijos:'Padrón Socios', espacios:'Configurar Espacios',
  jugadores:'Gestionar Plantel', noticias:'Publicar Noticia', galeria:'Subir Fotos',
  publicidad:'Publicidad', avisos_popup:'Configurar Pop-up', tienda:'Tienda Oficial',
  escudos_rivales:'Rivales y Ubicaciones',
};
const predeterminados = {
  tesoreria:['Caja y Finanzas','Padrón Socios','Escanear Ingreso','Config. Precios','Configurar Pagos','Tienda Oficial','Gestionar Rifas'],
  administracion:['Caja y Finanzas','Padrón Socios','Escanear Ingreso','Agenda / Reservas','Publicar Noticia','Configurar Pop-up','Configurar Espacios','Tienda Oficial','Gestionar Rifas','Configuración Club'],
  deportes:['Tomar Asistencia','Consola en VIVO','Configurar Streaming','Publicar Noticia'],
  institucional:['Publicar Noticia','Votación Figura','Agenda / Reservas','Tienda Oficial'],
  ingreso:['Escanear Ingreso','Tomar Asistencia'],
};
function permitido(perfil, matriz, carpeta) {
  if(!Object.hasOwn(carpetas,carpeta) || !perfil || (Object.hasOwn(perfil,'activo') && perfil.activo !== true)) return false;
  if(perfil.rol === 'admin') return true;
  if(!Object.hasOwn(predeterminados,perfil.rol)) return false;
  const modulos = Object.hasOwn(matriz,perfil.rol) ? matriz[perfil.rol] : predeterminados[perfil.rol];
  return Array.isArray(modulos) && modulos.includes(carpetas[carpeta]);
}
function crearAutorizador({auth,db,proyecto}) {
 return async (req,res)=>{
  res.set('Cache-Control','no-store');
  if(req.method !== 'POST') return res.status(405).json({ok:false});
  if(proyecto() !== 'club-guemes-2') return res.status(403).json({ok:false});
  const header = req.get('Authorization') || '';
  if(!/^Bearer [^ ]+$/.test(header)) return res.status(401).json({ok:false});
  let identidad;
  try { identidad=await auth.verifyIdToken(header.slice(7),true); }
  catch { return res.status(401).json({ok:false}); }
  if(typeof identidad.email !== 'string' || identidad.email.includes('/')) return res.status(403).json({ok:false});
  try {
    const [perfil,matriz]=await Promise.all([
      db.collection('permisos_admin').doc(identidad.email).get(),
      db.collection('configuracion').doc('permisos_roles').get(),
    ]);
    const ok=permitido(perfil.data(),matriz.data() || {},req.body?.carpeta);
    return res.status(ok?200:403).json({ok});
  } catch { return res.status(503).json({ok:false}); }
 };
}
module.exports={crearAutorizador,permitido};
