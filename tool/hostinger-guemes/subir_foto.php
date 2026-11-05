<?php
declare(strict_types=1);
// Publicar en public_html/api/subir_foto.php SOLO después de actualizar clientes.
header('Access-Control-Allow-Origin: *');
header('Access-Control-Allow-Headers: Authorization, Content-Type');
header('Access-Control-Allow-Methods: POST, OPTIONS');
header('Content-Type: application/json; charset=UTF-8');
header('Cache-Control: no-store');
header('X-Content-Type-Options: nosniff');
function responder(int $code, string $message): void {
    http_response_code($code);
    echo json_encode(['status' => 'error', 'message' => $message]);
    exit;
}
if ($_SERVER['REQUEST_METHOD'] === 'OPTIONS') { http_response_code(204); exit; }
if ($_SERVER['REQUEST_METHOD'] !== 'POST') responder(405, 'Método no permitido.');
$authorization = $_SERVER['HTTP_AUTHORIZATION'] ?? $_SERVER['REDIRECT_HTTP_AUTHORIZATION'] ?? '';
if (!preg_match('/^Bearer [A-Za-z0-9_.-]{20,8192}$/D', $authorization)) responder(401, 'Iniciá sesión para subir imágenes.');
$carpeta = $_POST['carpeta'] ?? '';
if (!is_string($carpeta) || !in_array($carpeta, ['socios','socios_hijos','espacios','jugadores','noticias','galeria','publicidad','avisos_popup','tienda','escudos_rivales'], true)) responder(400, 'Destino inválido.');
if (!function_exists('curl_init') || !class_exists('finfo') || !function_exists('imagecreatefromstring')) responder(503, 'Servicio de imágenes no configurado.');
// Firebase verifica firma, vencimiento, revocación y permisos actuales.
$curl = curl_init('https://southamerica-east1-club-guemes-2.cloudfunctions.net/autorizarImagenGuemes');
curl_setopt_array($curl, [CURLOPT_POST => true, CURLOPT_RETURNTRANSFER => true,
    CURLOPT_FOLLOWLOCATION => false, CURLOPT_CONNECTTIMEOUT => 5, CURLOPT_TIMEOUT => 20,
    CURLOPT_SSL_VERIFYPEER => true, CURLOPT_SSL_VERIFYHOST => 2,
    CURLOPT_HTTPHEADER => ['Content-Type: application/json', 'Authorization: '.$authorization],
    CURLOPT_POSTFIELDS => json_encode(['carpeta' => $carpeta])]);
$response = curl_exec($curl);
$status = curl_getinfo($curl, CURLINFO_HTTP_CODE);
curl_close($curl);
$result = is_string($response) ? json_decode($response, true) : null;
if ($status !== 200 || !is_array($result) || ($result['ok'] ?? false) !== true) {
    responder(in_array($status, [401,403], true) ? $status : 503,
        in_array($status, [401,403], true) ? 'Tu sesión no tiene permiso para subir esta imagen.' : 'No se pudo verificar el permiso. Intentá nuevamente.');
}
$file = $_FILES['imagen'] ?? null;
if (!is_array($file) || ($file['error'] ?? null) !== UPLOAD_ERR_OK || !is_string($file['tmp_name'] ?? null) || !is_uploaded_file($file['tmp_name'])) responder(400, 'No llegó una imagen válida.');
$size = filesize($file['tmp_name']);
if ($size === false || $size < 1 || $size > 4 * 1024 * 1024) responder(413, 'La imagen debe pesar hasta 4 MB.');
$mime = (new finfo(FILEINFO_MIME_TYPE))->file($file['tmp_name']);
$types = ['image/jpeg' => 'jpg', 'image/png' => 'png', 'image/webp' => 'webp'];
$info = @getimagesize($file['tmp_name']);
if (!isset($types[$mime]) || $info === false || ($info['mime'] ?? '') !== $mime || $info[0] < 1 || $info[1] < 1 || $info[0] > 4096 || $info[1] > 4096 || $info[0] * $info[1] > 16000000) responder(400, 'Usá una imagen JPG, PNG o WebP de hasta 4096 píxeles por lado.');
if ($mime === 'image/webp' && !function_exists('imagewebp')) responder(400, 'Usá una imagen JPG o PNG.');
$image = @imagecreatefromstring(file_get_contents($file['tmp_name']));
if ($image === false) responder(400, 'No se pudo procesar la imagen.');
imagealphablending($image, false);
imagesavealpha($image, true);
$directory = __DIR__.'/../uploads/';
if (!is_dir($directory) || !is_writable($directory)) responder(503, 'Directorio de imágenes no disponible.');
// Nunca usar nombre enviado por el cliente, DNI ni rutas elegidas por el usuario.
try { $name = bin2hex(random_bytes(16)).'.'.$types[$mime]; }
catch (Throwable $e) { responder(503, 'No se pudo guardar la imagen.'); }
$path = $directory.$name;
$handle = @fopen($path, 'xb'); // Creación exclusiva: nunca reemplaza otra foto.
if ($handle === false) responder(503, 'No se pudo guardar la imagen.');
$ok = false;
try {
    // Recodificar elimina contenido adjunto y evita guardar el archivo recibido tal cual.
    if ($mime === 'image/jpeg') $ok = imagejpeg($image, $handle, 85);
    elseif ($mime === 'image/png') $ok = imagepng($image, $handle, 6);
    else $ok = imagewebp($image, $handle, 85);
} catch (Throwable $e) { $ok = false; }
fclose($handle);
imagedestroy($image);
clearstatcache(true, $path);
if (!$ok || filesize($path) === 0) { @unlink($path); responder(503, 'No se pudo guardar la imagen.'); }
@chmod($path, 0644);
echo json_encode(['status' => 'ok', 'url' => 'https://martinguemes.site/uploads/'.$name]);
