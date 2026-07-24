# WRITER FIGHTER — Plan de diseño y roadmap (v0.1)

> Juego de lucha 2D en pixel art estilo Street Fighter II, protagonizado por escritores reales de la literatura española. Combate + capa educativa (wiki en pixel art de cada autor).
>
> Equipo: 2 personas (programación + arte). Referencia de diseño: manual de Street Fighter II (USA).

---

## 1. Visión

- **Qué es:** un juego de lucha 1v1 en 2D, pixel art, con la estructura arcade clásica de SF2: eliges luchador, encadenas combates contra rivales con su propio escenario y estilo, y ganas el "campeonato".
- **El giro:** los luchadores son escritores, y sus golpes, especiales y escenarios nacen de su obra, su biografía y su carácter público. Ganar combates desbloquea la **wiki pixel art** de cada autor: es un juego que se ríe con la literatura y a la vez te la enseña.
- **Tono:** parodia cariñosa y gamberra, tipo caricatura de prensa. Se ríe de los personajes públicos, no humilla a las personas.

## 2. Alcance de la v1 (y lo que NO entra)

**Nota de alcance:** el brief dice "3 escritores famosos" pero lista 4 (Uclés, Reverte, Cela, Etxebarria). El plan asume **4 oponentes** como objetivo de la v1, con Uclés marcado como el más recortable si hay que reducir (es el diseño de moveset más especulativo). Decidir en la reunión de arranque.

### Entra en la v1
- 1 personaje jugable: **Cristina Morales**.
- 4 oponentes controlados por IA: **Pérez-Reverte, Cela, Lucía Etxebarria, David Uclés**.
- Modo arcade: 4 combates sucesivos (orden de dificultad), al mejor de 3 asaltos, con pantalla de victoria/derrota y "clasificación" final (puntuación + rango con nombre literario: de "Becario de suplemento cultural" a "Premio Nacional").
- 5 escenarios (uno por escritor, incluido el de Cristina para el futuro modo VS).
- 3-4 especiales + 1 súper por personaje.
- **Wiki pixel art**: una ficha por escritor (retrato, bibliografía, 3-5 curiosidades, cita célebre), desbloqueable al vencerlo.
- Música chiptune por escenario (o licencia/colaboración; ver riesgos).
- Plataforma: **PC (Windows/Linux/Mac), distribución en itch.io**. Mando y teclado.

### NO entra en la v1 (queda para después)
- Multijugador local y online.
- Más personajes jugables (todos los oponentes son candidatos a DLC jugable).
- Fases bonus (romper la furgoneta de reparto de libros, corregir galeradas contrarreloj…).
- Modo historia con diálogos, tienda, logros, Steam.

**Regla de oro anti-scope-creep:** toda idea nueva que surja durante el desarrollo va a la sección 11 (backlog futuro), no a la v1.

## 3. Diseño de juego

### Controles (simplificados respecto a SF2)
SF2 usa 6 botones; para nuestro alcance recomiendo **4 + entradas clásicas**:

| Botón | Acción |
|---|---|
| A | Puñetazo débil (rápido, poco daño) |
| B | Puñetazo fuerte (lento, más daño) |
| X | Patada débil |
| Y | Patada fuerte |

- Movimiento: 8 direcciones (andar, salto, agacharse). Bloqueo: dirección atrás (como SF2).
- Especiales: medias lunas (↓↘→ + botón), cargas (←…→ + botón) y "dragón" (→↓↘ + botón). Máximo 2 tipos de entrada por personaje para que la IA y el jugador los aprendan rápido.
- **Modo accesible (opción):** especiales con un solo botón + dirección. Barato de implementar y abre el juego a gente no jugona (importante por la capa educativa).

### Sistemas de combate v1
- Vida + 2 rondas ganadas para vencer, temporizador de 99s (clásico).
- **Medidor de Tinta** (equivalente a la barra de súper): se llena al dar y recibir golpes; llena, permite el súper ("la Obra Maestra" de cada autor).
- Hitstun, blockstun, knockdown, throw básico. Sin parry, sin cancels avanzados, sin juggle complejo en v1 — SF2 original tampoco los tenía y funciona.
- Combos: por enlace natural de frames (como SF2), no sistemas de cancel elaborados. 2-3 combos "de manual" por personaje, documentados en su wiki (¡la wiki también es el modo tutorial!).
- IA por niveles: patrones simples con agresividad/reacción creciente por combate.

## 4. Personajes y movesets

> Principio de diseño: cada escritor es un **arquetipo clásico de juego de lucha** que encaja con su naturaleza literaria. Nombres de movimientos = títulos y motivos de su obra.

### CRISTINA MORALES — jugable. Arquetipo: *rushdown* ágil (Chun-Li/Cammy)
Bailarina y coreógrafa, punk, anarquista, prosa combativa. Rápida, presión constante, poca vida: si paras de atacar, sufres.
- **Danza Bruta** (↓↘→+P): avance de danza-contacto en varios golpes.
- **Lectura Fácil** (↓↘→+K): proyectil-panfleto lento que aturde brevemente (el rival "se pone a leer").
- **Asamblea** (↓↙←+P): contraataque; si absorbe un golpe, responde con patada okupa.
- **Súper — Los Combatientes:** su banda punk irrumpe en el escenario y ella remata con una coreografía demoledora a pantalla completa.

### ARTURO PÉREZ-REVERTE — Oponente 1 (fácil). Arquetipo: *zoner disciplinado de carga* (Guile)
Espadachín de honor, académico de la RAE, francotirador en Twitter. Sólido, paciente, castiga desde media distancia.
- **Tuit Incendiario** (←carga→+P): proyectil rápido y horizontal.
- **Estocada Alatriste** (←carga→+K): dash con acero toledano.
- **Limpia, Fija y da Esplendor** (↓↓+P): golpe de diccionario de la RAE hacia arriba (antiaéreo).
- **Súper — Cabo Trafalgar:** andanada de cañones navales desde el fondo del escenario.

### LUCÍA ETXEBARRIA — Oponente 2. Arquetipo: *zoner de control y estados* (Dhalsim/mago)
Reina de la polémica y de los premios. Te derrota alterándote antes de tocarte.
- **Polémica Viral** (↓↘→+P): nube de tuits que hace daño por segundo en un área.
- **Prozac** (↓↘→+K): proyectil que invierte los controles del rival 2 segundos.
- **Me Voy de Twitter** (↓↙←+K): desaparece y reaparece a la espalda del rival (teleport)… porque siempre vuelve.
- **Súper — Triple Corona:** lluvia de premios Nadal, Primavera y Planeta desde el cielo.

### DAVID UCLÉS — Oponente 3. Arquetipo: *trampero de ilusiones* (personaje técnico)
Realismo mágico, acordeonista, la península fantasmal. Controla el espacio y desconcierta.
- **Acordeón** (↓↘→+P): onda sonora expansiva de corto alcance.
- **Casas Vacías** (↓↘→+K): invoca una casa que cae del cielo en la vertical del rival (trampa retardada).
- **Realismo Mágico** (↓↙←+P): durante 3 segundos, el escenario flota y la gravedad de ambos cambia.
- **Súper — La Península:** el escenario entero se vacía y se vuelve espectral; los golpes de Uclés atraviesan el bloqueo mientras dura.

### CAMILO JOSÉ CELA — Jefe final. Arquetipo: *grappler tremendo* (Zangief/jefe)
Tremendismo hecho carne: lento, enorme, cada golpe es un capítulo de Pascual Duarte. Premio Nobel y censor: autoridad aplastante.
- **Pascual Duarte** (media luna completa+P): agarre brutal a corta distancia, el más dañino del juego.
- **La Colmena** (↓↘→+P): invoca un enjambre de personajes del café que avanza como muro.
- **Viaje a la Alcarria** (→→): caminata-embestida con superarmadura (no se inmuta con golpes débiles).
- **Absorción** (↓↙←+P): postura que absorbe cualquier proyectil y lo convierte en Tinta (guiño a su anécdota televisiva más célebre).
- **Súper — Nobel:** medallazo orbital precedido de discurso que congela el tiempo.

## 5. Escenarios

Como en SF2, cada escenario cuenta quién es el dueño, con 2-3 elementos animados de fondo:

1. **Morales — Centro social okupa (Barcelona):** local de ensayo, pancartas, conciertos punk al fondo.
2. **Reverte — Cubierta de galeón:** mar embravecido, gaviotas, un móvil que vibra sin parar sobre un barril.
3. **Etxebarria — Plató de TV / timeline gigante:** pantallas con tuits pasando, público que aplaude y abuchea.
4. **Uclés — Pueblo de Jaén surrealista:** olivos flotantes, casas semitransparentes, luz de atardecer imposible.
5. **Cela — Café de La Colmena (Madrid, años 50):** humo, mármol, tertulianos que se giran a mirar los golpes.

## 6. Capa educativa: la Wiki pixel art

- Accesible desde el menú principal ("Biblioteca") y como recompensa: **vencer a un escritor desbloquea su ficha completa** (antes del combate se ve una versión parcial: retrato + una línea, como los perfiles del manual de SF2).
- Cada ficha: retrato pixel art grande, años/lugares clave, **bibliografía seleccionada (5-8 obras con año y una frase de por qué importa)**, 3-5 curiosidades, una cita célebre, y la explicación de sus movimientos ("por qué su especial se llama así") — esto conecta juego y literatura.
- Formato técnico: fichas como datos (JSON/Resource), render único. Añadir un escritor nuevo = añadir datos + retrato. **Esto es la clave de la escalabilidad DLC.**
- Futuro: enlaces "quieres leer más" (primera obra recomendada), línea temporal comparada, modo quiz.

## 7. Tecnología

**Recomendación: Godot 4** (GDScript).
- Gratis y open source, excelente en 2D/pixel art, exporta a PC/web/móvil/consolas, ligero para un equipo de 2.
- Todo lo que necesita un juego de lucha (state machines, hitboxes por frame, input buffer) se implementa de forma razonable, y hay addons maduros (p. ej. rollback netcode de Snopek) para el online futuro.
- Alternativa considerada: **IKEMEN GO** (motor open source heredero de MUGEN) — prototipa combates rapidísimo, pero encorseta la wiki, los menús propios y la distribución futura. Descartado para el producto, útil como referencia de "game feel".

Decisiones técnicas de arranque:
- Resolución interna **480×270** (escala entera ×4 a 1080p y ×8 a 4K), sprites de personaje de **~120-128 px de alto**.
  - Referencia: SF2 corría a 384×224 con sprites de ~90-110 px. A 480×270 nuestros personajes ocupan proporcionalmente MÁS pantalla que en SF2 — aspecto "hi-bit" moderno, no retro-crudo.
  - Por qué no más: el coste de arte crece ~cuadráticamente con el tamaño del sprite, y 128 px es además el techo práctico de generación de PixelLab (ver §8) — a 480×270 herramienta y resolución encajan. 640×360 (sprites ~170 px) queda como opción solo si el test de Fase 0 sobra de tiempo.
- Hitboxes/hurtboxes definidas por frame en datos (no hardcodeadas) → los movesets se ajustan sin tocar código.
- Personajes como "paquete" autocontenido (sprites + datos de movimientos + ficha wiki) desde el día 1 → un DLC es literalmente una carpeta nueva.
- Repositorio Git desde el día 1 (también para el arte).

## 8. Pipeline de arte (el cuello de botella real)

El coste dominante del proyecto es la animación. Presupuesto por personaje (estilo SF2, frames contados):

| Bloque | Animaciones | ~Frames |
|---|---|---|
| Locomoción (idle, andar ×2, salto, agacharse, giro) | 6 | 24-30 |
| Golpes normales (4 de pie + 2 agachado + 1 aéreo) | 7 | 21-28 |
| Especiales + súper | 4-5 | 25-35 |
| Reacciones (hit, block, caída, levantarse, KO, victoria) | 6 | 18-24 |
| **Total por personaje** | **~23** | **~90-120** |

- 5 personajes ≈ **500-600 frames** + 5 escenarios + retratos + UI. Sigue siendo EL trabajo del proyecto, pero el pipeline con IA (abajo) cambia la economía: el rol del artista pasa de "dibujar cada frame" a "dirigir, corregir y rematar".

### Pipeline con PixelLab (IA) + Aseprite
Flujo: **PixelLab genera → el artista corrige en Aseprite → export a Godot** (PixelLab tiene extensión oficial para Aseprite v1.3+, con generación e inpainting directamente sobre el archivo abierto).

Dónde ayuda mucho (estimación: **40-60 % menos tiempo** en estos bloques):
- **Locomoción y reacciones** (idle, andar, salto, hit, caída…): animación genérica que PixelLab resuelve bien con esqueleto/texto; el artista limpia y unifica.
- **Consistencia de estilo:** inpainting para retocar sin romper la paleta; el mismo personaje base alimenta todas sus animaciones.
- **Iteración barata:** probar 3 diseños de Cela en una tarde antes de comprometerse.

Dónde ayuda poco (sigue siendo trabajo de artista):
- **Poses clave de los golpes y especiales**: la personalidad del juego vive ahí (anticipación, smears, siluetas legibles a golpe de vista). La IA hace in-betweens, no la pose que hace gracia.
- **Control de calidad frame a frame:** coherencia entre frames (parpadeos, detalles que bailan) y legibilidad de hitbox.

Datos prácticos a tener en cuenta:
- PixelLab rinde mejor cuanto MÁS grande el sprite (mal por debajo de 32 px), pero **128×128 es su techo práctico** y a ese tamaño cada petición devuelve solo ~4 frames → generar es barato en tiempo, no gratis en créditos. Presupuestad la suscripción como coste del proyecto.
- **Revisar los términos de licencia comercial** de los assets generados antes de publicar (no está claro en su web pública; mirar ToS del plan de pago). Añadido a riesgos (§10).
- El test de validación del pipeline es parte de la **Fase 0** (ver roadmap): mismo personaje, mismas animaciones, con y sin PixelLab, cronometrado. La decisión de resolución final (480×270 vs 640×360) se toma con ese dato.
- Truco de producción (sigue valiendo): los 5 comparten esqueleto de proporciones → locomoción y reacciones se calcan entre personajes y se re-visten; solo golpes y especiales son 100 % únicos.

## 9. Roadmap

> Supuesto: dedicación a tiempo parcial (~10 h/semana por persona). Si es más, comprimid proporcionalmente. Cada fase termina en un hito jugable/enseñable — nunca meses de trabajo sin nada que probar.

### Fase 0 — Preproducción (2-3 semanas)
- Cerrar este documento entre los dos: lista definitiva de oponentes (¿3 o 4?), movesets, tono del humor.
- **Biblia de arte:** el artista produce 1 hoja de estilo (paleta, proporciones, un retrato de prueba) y la animación idle + andar de Cristina.
- **Test del pipeline PixelLab (crítico):** idle + andar + un golpe de Cristina a 128 px, generado con PixelLab y rematado en Aseprite, cronometrado contra hacerlo a mano. Con ese dato se fijan resolución definitiva (480×270 vs 640×360) y la estimación real de la Fase 3.
- Programador: proyecto Godot, resolución, input, escena de combate vacía, Git.
- ✅ **Hito: GDD firmado + Cristina camina por una pantalla + veredicto del pipeline de arte.**

### Fase 1 — Prototipo gris (4-6 semanas)
- Todo el sistema de combate **con rectángulos de colores**, sin arte: movimiento, salto, 4 golpes, bloqueo, hitstun, daño, rondas, temporizador, KO, throw, medidor de Tinta, 1 especial de prueba de cada tipo de entrada.
- IA tonta (agresiva aleatoria) para poder probar solo.
- ✅ **Hito: dos rectángulos se pegan y ES DIVERTIDO.** (Si no es divertido en gris, no lo arregla el pixel art — se itera aquí hasta que lo sea.)

### Fase 2 — Vertical slice (6-8 semanas)
- **Cristina Morales vs Pérez-Reverte**, ambos con arte y moveset completos, en el escenario del galeón, con su música, pantalla de título, selección, victoria/derrota y **las 2 primeras fichas wiki**.
- Esta fase valida TODO el pipeline (arte→motor→datos→wiki) y produce el material de anuncio (GIFs para redes).
- ✅ **Hito: demo de 1 combate completa y pulida, jugable por terceros.** Sacadla a probar con amigos.

### Fase 3 — Producción (10-14 semanas)
- Los 3 personajes restantes + sus escenarios + fichas wiki, en este orden: **Etxebarria → Cela → Uclés** (Cela necesita madurez del motor por el grappler/jefe; Uclés es el más experimental y el recortable).
- Modo arcade completo: secuencia de 4 combates, dificultad creciente, continues, clasificación final.
- IA por niveles.
- ✅ **Hito: se puede jugar el arcade de principio a fin.**

### Fase 4 — Pulido y lanzamiento (4-6 semanas)
- Game feel: hitstop, screenshake, partículas, sonidos de golpe.
- Balance (que la gente lo pruebe), bugs, opciones (volumen, remapeo, modo accesible).
- Página de itch.io, tráiler/GIFs, build Win/Linux/Mac.
- ✅ **Hito: v1.0 publicada en itch.io.**

**Total estimado: 6-9 meses a tiempo parcial.** El riesgo de desviación está casi todo en la Fase 3 (arte); el plan de contingencia es recortar a 3 oponentes (fuera Uclés) sin tocar nada más.

## 10. Riesgos y avisos

1. **Derechos de imagen (el importante):** Reverte, Etxebarria, Morales y Uclés son personas vivas; Cela tiene herederos activos en lo jurídico. La parodia/caricatura de personajes públicos tiene amparo, pero el uso **comercial** de la imagen de una persona es terreno delicado en España (LO 1/1982). Recomendaciones: tono caricatura evidente (nunca fotorealista), disclaimers de parodia, empezar **gratis o "paga lo que quieras"** en itch.io, y valorar contactar a los autores — a más de uno puede hacerle gracia y convertirse en el mejor marketing posible. Decisión consciente antes de cobrar por el juego.
2. **Scope creep:** es el proyecto perfecto para morir de ideas ("¡y Lorca! ¡y modo online!"). Antídoto: la regla de oro de la sección 2 y los hitos cerrados por fase.
3. **El arte manda:** si el artista se satura, se recortan personajes, no calidad ni sistemas.
4. **Licencia de assets IA:** verificar los términos comerciales de PixelLab (propiedad y uso de lo generado) antes de publicar; guardad también los archivos fuente del artista para poder demostrar el trabajo humano sobre lo generado.
5. **Música y citas:** nada de letras/canciones reales sin licencia; chiptune original. Las citas de obras en la wiki: cortas y con atribución (derecho de cita).
6. **Contenido sensible:** Cela y la Guerra Civil (Uclés) tocan memoria histórica; el humor va sobre los autores y sus obras, no sobre las víctimas de nada.

## 11. Backlog futuro (escalabilidad)

- **VS local 2 jugadores** — casi gratis: la arquitectura de la v1 ya lo permite (es quitar la IA del jugador 2). Candidato a v1.1.
- **Oponentes → jugables** (rebalanceo + IA rival para Cristina).
- **DLC de escritores** (cada uno = carpeta de personaje + ficha wiki): Lorca, Emilia Pardo Bazán, Valle-Inclán, Quevedo vs Góngora como pack doble…
- **Fases bonus** estilo SF2 (el coche → la furgoneta de reparto; los barriles → pilas de manuscritos rechazados).
- **Modo historia** con diálogos previos al combate (pullas literarias entre autores).
- **Online con rollback** (addon de Godot; requiere motor determinista — decisión a tomar ya en Fase 1: física propia con números enteros/fixed-point, nada de física del motor).
- **Modo quiz / aula:** la wiki como material educativo para institutos.
- Steam, web (HTML5 en itch), móvil.

---

*Documento vivo — v0.1. Siguiente paso: reunión de arranque para cerrar la Fase 0.*
