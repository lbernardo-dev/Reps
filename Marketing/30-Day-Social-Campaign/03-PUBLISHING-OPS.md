# Publishing Operations

## Cadencia recomendada

Publicar una pieza principal diaria y adaptar, no duplicar literalmente, en el resto de redes. Horario inicial de prueba: Instagram/Reels 19:00; TikTok 20:00; LinkedIn 09:00; X 12:30; Facebook 19:30, hora local de la audiencia. Ajustar tras dos semanas con datos propios.

## Formatos

- Carrusel Instagram/Facebook: 1080×1350, 5–7 slides.
- Reel/TikTok: 1080×1920, 15–30 s, subtítulos incrustados y zona segura.
- LinkedIn: 1080×1350 o documento 1080×1350.
- X: 1600×900 o captura vertical con fondo de marca.
- Stories: 1080×1920.

Las capturas fuente no deben deformarse. Colocarlas enteras dentro de un lienzo con fondo de marca; no reconstruir UI ni ocultar elementos esenciales. Se permiten recorte, ampliación, flechas y etiquetas, pero no alterar datos para aparentar funciones inexistentes.

## Checklist antes de publicar

- [ ] Copy en un único idioma y revisado por un hablante competente.
- [ ] La pantalla corresponde al idioma del copy.
- [ ] El activo figura en `ASSET-MANIFEST.md` o lleva `CAPTURE REQUIRED` resuelto.
- [ ] No hay datos personales, ubicación real, notificaciones ni identificadores visibles.
- [ ] No hay afirmaciones médicas, resultados garantizados ni cifras inventadas.
- [ ] Texto alternativo añadido.
- [ ] CTA y enlace funcionan.
- [ ] Música, tipografías y cualquier recurso externo tienen licencia.
- [ ] Respuestas preparadas para preguntas sobre HealthKit, Pro y privacidad.

## Captura nueva desde simulador

1. Usar el seed de demo premium realista disponible en el menú Developer.
2. Fijar idioma con `-demoLanguage es` o `-demoLanguage en` cuando corresponda.
3. Usar un iPhone de referencia consistente; ocultar datos sensibles.
4. Capturar PNG nativo con `xcrun simctl io <UDID> screenshot <archivo.png>`.
5. Guardar pareja ES/EN con el mismo nombre en `assets/simulator`.
6. Añadir origen, fecha, pantalla y alt text al manifiesto.

## Métricas semanales

| Red | Reach | Saves | Shares | Comments | Profile visits | Link clicks | Downloads |
|---|---:|---:|---:|---:|---:|---:|---:|
| Instagram | | | | | | | |
| TikTok | | | | | | | |
| LinkedIn | | | | | | | |
| X | | | | | | | |
| Facebook | | | | | | | |

Decisión semanal: mantener el mejor tema, reescribir el mejor hook y retirar formatos con baja retención; no cambiar más de una variable por prueba.
