"""Personaliza build/web después de compilar lib/main_guemes.dart para Hostinger."""
from pathlib import Path
import hashlib
import json
import re
import shutil
import struct

raiz = Path(__file__).resolve().parents[1]
web = raiz / "build/web"
if not (web / "main.dart.js").exists():
    raise SystemExit("Primero compilar: flutter build web --release --target lib/main_guemes.dart --base-href /")
logo = raiz / "assets/icon/icono_guemes.png"
shutil.copy2(logo, web / "guemes_logo.png")
ancho, alto = struct.unpack(">II", logo.read_bytes()[16:24])
p = web / "index.html"
s = p.read_text(encoding="utf-8")
s = s.replace("TuSede", "Club Martín Güemes")
s = s.replace("Plataforma de gestión para clubes e instituciones.", "Noticias, deportes y servicios para los socios.")
s = s.replace('src="tusede_logo.svg"', 'src="guemes_logo.png"')
s = s.replace("Gestión para clubes e instituciones", "Club Martín Güemes")
s = re.sub(r'href="icons/Icon-192.png[^"]*"', 'href="guemes_logo.png"', s)
s = re.sub(r'href="favicon.png[^"]*"', 'href="guemes_logo.png"', s)
s = s.replace("#0b1f27", "#210805").replace("#20584f", "#9c1c15").replace("#07151c", "#100403").replace("#b7f6cc", "#ffffff")
s = s.replace("width: min(76vw, 560px)", "width: min(48vw, 180px)").replace("width: min(86vw, 430px)", "width: min(48vw, 180px)")
p.write_text(s, encoding="utf-8")
p = web / "manifest.json"
manifest = json.loads(p.read_text(encoding="utf-8"))
manifest.update(name="Club Martín Güemes", short_name="Güemes", description="Noticias, deportes y servicios del Club Martín Güemes", background_color="#210805", theme_color="#d92316", icons=[{"src":"guemes_logo.png", "sizes":f"{ancho}x{alto}", "type":"image/png", "purpose":"any"}])
p.write_text(json.dumps(manifest, ensure_ascii=False, indent=2), encoding="utf-8")
# Si Flutter genera un service worker, actualizar los hashes tras personalizar.
sw = web / "flutter_service_worker.js"
if sw.exists():
    s = sw.read_text(encoding="utf-8")
    match = re.search(r"const RESOURCES = (\{.*?\});", s, re.S)
    if match:
        recursos = json.loads(match.group(1))
        for nombre in ["index.html", "manifest.json", "guemes_logo.png"]:
            recursos[nombre] = hashlib.md5((web / nombre).read_bytes()).hexdigest()
        if "/" in recursos:
            recursos["/"] = recursos["index.html"]
        s = s[:match.start(1)] + json.dumps(recursos) + s[match.end(1):]
        sw.write_text(s, encoding="utf-8")
    elif "self.registration.unregister()" in s and not re.search(
        r"addEventListener\(\s*['\"]fetch['\"]", s
    ):
        # Flutter puede emitir únicamente un worker de desregistro.
        # No tiene un manifiesto de caché que debamos actualizar.
        print("Service worker de limpieza: se conserva sin cambios.")
    else:
        raise SystemExit("No se reconoce el service worker: revisar antes de publicar.")
print("Web de Güemes preparada en", web)
