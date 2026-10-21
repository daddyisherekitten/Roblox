--!strict
-- Technical navigation fallback, kept outside the website catalog.
return {
	Name = "Seite nicht gefunden",
	URL = "http://localhost:8000/not-found/index.html",
	Options = {},
	HTML = [==[<!doctype html>
<html lang="de"><head><meta charset="utf-8"><meta name="viewport" content="width=device-width, initial-scale=1"><title>Seite nicht gefunden</title></head><body><main><p>404</p><h1>Diese Adresse ist nicht erreichbar.</h1><p>Die Seite wurde entfernt oder die Adresse ist unvollständig.</p><p>Prüfe die Adresse oder öffne einen neuen Tab.</p></main></body></html>]==],
	CSS = "body{margin:0;padding:48px;background:#0a0c0c;color:#b5b7b0;font-family:monospace;font-size:14px;line-height:1.6}main{max-width:640px;margin:40px auto}h1{font-size:24px;color:#d0d3c8}a{color:#94a978;text-decoration:underline}",
}
