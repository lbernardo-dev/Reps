import Foundation

/// Static, bundled catalog of rehabilitation exercises — no network fetch,
/// no downloaded images/video, no third-party dataset. Content is original
/// copy informed by widely-published, non-proprietary rehabilitation
/// principles (isometric/eccentric tendon loading, controlled joint
/// mobility, post-injury muscle activation); see each exercise's
/// `referenceNote` for the specific principle it draws on. Mirrors the
/// "pure Swift catalog, no JSON" pattern already used by `SeedData.exercises`.
enum RehabSeedData {
    static let disclaimer = RehabLocalizedText(
        en: "This section is educational and does not replace an in-person evaluation by a physical therapist or physician. Stop and seek professional care if you have sharp, worsening, or persistent pain, swelling, numbness, or a recent acute injury.",
        es: "Esta sección es educativa y no sustituye la valoración presencial de un fisioterapeuta o médico. Detente y busca atención profesional si tienes dolor agudo, que empeora o persiste, hinchazón, entumecimiento, o una lesión aguda reciente."
    )

    static let exercises: [RehabExercise] = [
        // MARK: - Shoulder

        RehabExercise(
            id: UUID(uuidString: "10000000-0000-0000-0000-000000000001")!,
            name: RehabLocalizedText(en: "Isometric External Rotation Hold", es: "Rotación Externa Isométrica"),
            bodyRegion: .shoulder,
            structureFocus: .tendon,
            protocolType: .isometricHold,
            stage: .subacute,
            sets: 5,
            reps: nil,
            holdSeconds: 45,
            restSeconds: 60,
            instructions: [
                RehabLocalizedText(en: "Anchor a light resistance band at elbow height and stand side-on to it.", es: "Ancla una banda de resistencia ligera a la altura del codo y colócate de lado."),
                RehabLocalizedText(en: "Tuck your elbow against your side, bent to 90°, holding the band across your body.", es: "Pega el codo al costado, doblado a 90°, sujetando la banda cruzada frente al cuerpo."),
                RehabLocalizedText(en: "Without letting the elbow drift from your side, rotate your forearm outward against the band.", es: "Sin dejar que el codo se separe del costado, rota el antebrazo hacia afuera contra la banda."),
                RehabLocalizedText(en: "Hold at a comfortable end-range for the target time, then release slowly.", es: "Mantén la posición al final del rango cómodo durante el tiempo objetivo y suelta despacio.")
            ],
            painGuidance: RehabLocalizedText(
                en: "Mild-to-moderate discomfort (up to about 4/10) during the hold is commonly considered acceptable. Reduce the hold intensity or duration if pain climbs above 4/10, and stop for the day if it doesn't settle within a few minutes of resting.",
                es: "Una molestia leve a moderada (hasta unos 4/10) durante el mantenido suele considerarse aceptable. Reduce la intensidad o el tiempo si el dolor supera 4/10, y detente por hoy si no cede tras unos minutos de descanso."
            ),
            cautions: [
                RehabLocalizedText(en: "Avoid overhead positions while shoulder pain is acute.", es: "Evita posiciones por encima de la cabeza mientras el dolor de hombro sea agudo."),
                RehabLocalizedText(en: "Stop if you feel numbness, tingling, or sharp pain down the arm.", es: "Detente si sientes entumecimiento, hormigueo o dolor agudo que baja por el brazo.")
            ],
            referenceNote: RehabLocalizedText(
                en: "Based on isometric loading for pain modulation used in early-stage rotator cuff tendinopathy rehab (Rio et al.).",
                es: "Basado en la carga isométrica para modulación del dolor usada en fases tempranas de rehabilitación de tendinopatía del manguito rotador (Rio et al.)."
            )
        ),

        RehabExercise(
            id: UUID(uuidString: "10000000-0000-0000-0000-000000000002")!,
            name: RehabLocalizedText(en: "Pendulum Swings", es: "Balanceos Pendulares"),
            bodyRegion: .shoulder,
            structureFocus: .joint,
            protocolType: .mobility,
            stage: .acute,
            sets: 3,
            reps: 10,
            holdSeconds: nil,
            restSeconds: 30,
            instructions: [
                RehabLocalizedText(en: "Lean forward slightly, supporting yourself on a table or chair with your uninjured arm.", es: "Inclínate ligeramente hacia adelante, apoyándote en una mesa o silla con el brazo sano."),
                RehabLocalizedText(en: "Let the affected arm hang relaxed toward the floor.", es: "Deja que el brazo afectado cuelgue relajado hacia el suelo."),
                RehabLocalizedText(en: "Gently sway your body to swing the arm in small circles, letting gravity do the work.", es: "Balancea suavemente el cuerpo para que el brazo trace círculos pequeños, dejando que la gravedad haga el trabajo."),
                RehabLocalizedText(en: "Reverse direction halfway through the set.", es: "Cambia de dirección a la mitad de la serie.")
            ],
            painGuidance: RehabLocalizedText(
                en: "This should feel like gentle motion, not stretching into pain — keep it under 3/10 discomfort.",
                es: "Debe sentirse como un movimiento suave, no un estiramiento doloroso — mantén la molestia por debajo de 3/10."
            ),
            cautions: [
                RehabLocalizedText(en: "Do not actively swing the arm with muscle effort — motion should come from body sway only.", es: "No balancees el brazo activamente con esfuerzo muscular — el movimiento debe venir solo del balanceo del cuerpo.")
            ],
            referenceNote: RehabLocalizedText(
                en: "Passive pendular mobility is a long-standing staple of early post-immobilization shoulder rehabilitation protocols.",
                es: "La movilidad pendular pasiva es un recurso clásico en protocolos tempranos de rehabilitación de hombro tras inmovilización."
            )
        ),

        // MARK: - Elbow

        RehabExercise(
            id: UUID(uuidString: "10000000-0000-0000-0000-000000000003")!,
            name: RehabLocalizedText(en: "Isometric Wrist Extension Hold", es: "Extensión de Muñeca Isométrica"),
            bodyRegion: .elbow,
            structureFocus: .tendon,
            protocolType: .isometricHold,
            stage: .subacute,
            sets: 5,
            reps: nil,
            holdSeconds: 45,
            restSeconds: 60,
            instructions: [
                RehabLocalizedText(en: "Rest your forearm on a table, palm facing down, wrist just past the edge.", es: "Apoya el antebrazo en una mesa, palma hacia abajo, con la muñeca justo pasando el borde."),
                RehabLocalizedText(en: "With your other hand, press down gently on the back of your hand.", es: "Con la otra mano, presiona suavemente el dorso de la mano."),
                RehabLocalizedText(en: "Resist by trying to lift your hand upward without actually moving it.", es: "Resiste intentando levantar la mano hacia arriba sin llegar a moverla."),
                RehabLocalizedText(en: "Hold steady tension for the target time, then rest fully before the next set.", es: "Mantén la tensión estable durante el tiempo objetivo y descansa por completo antes de la siguiente serie.")
            ],
            painGuidance: RehabLocalizedText(
                en: "Working discomfort up to about 4/10 during the hold is generally acceptable for tendon pain. Ease off the pressure if it goes higher, and stop the session if pain doesn't drop back down within a few minutes.",
                es: "Una molestia de trabajo de hasta unos 4/10 durante el mantenido suele ser aceptable en dolor tendinoso. Reduce la presión si sube más, y detén la sesión si el dolor no baja en pocos minutos."
            ),
            cautions: [
                RehabLocalizedText(en: "Avoid gripping activities that reproduce sharp elbow pain until this feels easier.", es: "Evita actividades de agarre que reproduzcan dolor agudo en el codo hasta que esto se sienta más fácil.")
            ],
            referenceNote: RehabLocalizedText(
                en: "Based on isometric analgesic loading protocols studied for lateral elbow tendinopathy (\"tennis elbow\").",
                es: "Basado en protocolos de carga isométrica analgésica estudiados para la tendinopatía lateral de codo (\"codo de tenista\")."
            )
        ),

        RehabExercise(
            id: UUID(uuidString: "10000000-0000-0000-0000-000000000004")!,
            name: RehabLocalizedText(en: "Isometric Wrist Flexion Hold", es: "Flexión de Muñeca Isométrica"),
            bodyRegion: .elbow,
            structureFocus: .tendon,
            protocolType: .isometricHold,
            stage: .subacute,
            sets: 5,
            reps: nil,
            holdSeconds: 45,
            restSeconds: 60,
            instructions: [
                RehabLocalizedText(en: "Rest your forearm on a table, palm facing up, wrist just past the edge.", es: "Apoya el antebrazo en una mesa, palma hacia arriba, con la muñeca justo pasando el borde."),
                RehabLocalizedText(en: "With your other hand, press down gently on your palm.", es: "Con la otra mano, presiona suavemente la palma."),
                RehabLocalizedText(en: "Resist by trying to curl your hand upward without actually moving it.", es: "Resiste intentando curvar la mano hacia arriba sin llegar a moverla."),
                RehabLocalizedText(en: "Hold steady tension for the target time.", es: "Mantén la tensión estable durante el tiempo objetivo.")
            ],
            painGuidance: RehabLocalizedText(
                en: "Same guidance as other tendon holds: up to ~4/10 discomfort is generally fine, stop if it spikes sharply or lingers.",
                es: "Misma pauta que otros mantenidos tendinosos: hasta ~4/10 de molestia suele estar bien, detente si aumenta bruscamente o persiste."
            ),
            cautions: [
                RehabLocalizedText(en: "Avoid heavy gripping or lifting with a bent wrist until symptoms improve.", es: "Evita agarres pesados o levantar objetos con la muñeca doblada hasta que mejoren los síntomas.")
            ],
            referenceNote: RehabLocalizedText(
                en: "Mirrors the isometric loading approach used for medial elbow tendinopathy (\"golfer's elbow\").",
                es: "Refleja el enfoque de carga isométrica usado para la tendinopatía medial de codo (\"codo de golfista\")."
            )
        ),

        // MARK: - Wrist

        RehabExercise(
            id: UUID(uuidString: "10000000-0000-0000-0000-000000000005")!,
            name: RehabLocalizedText(en: "Wrist Circles & Tendon Glides", es: "Círculos de Muñeca y Deslizamiento Tendinoso"),
            bodyRegion: .wrist,
            structureFocus: .joint,
            protocolType: .mobility,
            stage: .acute,
            sets: 2,
            reps: 10,
            holdSeconds: nil,
            restSeconds: 30,
            instructions: [
                RehabLocalizedText(en: "Extend your arm and make a loose fist.", es: "Extiende el brazo y forma un puño relajado."),
                RehabLocalizedText(en: "Slowly circle the wrist 10 times in each direction.", es: "Circunda la muñeca lentamente 10 veces en cada dirección."),
                RehabLocalizedText(en: "Then open the hand fully, straighten fingers, and slide through a hook, full, and straight-fist position.", es: "Luego abre la mano por completo, estira los dedos y desliza por una posición en gancho, puño completo y puño recto."),
                RehabLocalizedText(en: "Move slowly and stay within a pain-free range.", es: "Muévete despacio y mantente dentro de un rango libre de dolor.")
            ],
            painGuidance: RehabLocalizedText(
                en: "This is mobility work, not a strength challenge — keep it under 3/10 and never force the range.",
                es: "Esto es trabajo de movilidad, no un reto de fuerza — mantente por debajo de 3/10 y nunca fuerces el rango."
            ),
            cautions: [
                RehabLocalizedText(en: "Stop if you feel catching, locking, or sharp pain in a specific finger or the wrist.", es: "Detente si sientes bloqueo, enganche o dolor agudo en un dedo concreto o en la muñeca.")
            ],
            referenceNote: RehabLocalizedText(
                en: "Tendon gliding sequences are a standard early mobility technique in hand/wrist rehabilitation.",
                es: "Las secuencias de deslizamiento tendinoso son una técnica estándar de movilidad temprana en la rehabilitación de mano/muñeca."
            )
        ),

        // MARK: - Knee

        RehabExercise(
            id: UUID(uuidString: "10000000-0000-0000-0000-000000000006")!,
            name: RehabLocalizedText(en: "Isometric Spanish Squat Hold", es: "Sentadilla Española Isométrica"),
            bodyRegion: .knee,
            structureFocus: .tendon,
            protocolType: .isometricHold,
            stage: .subacute,
            sets: 5,
            reps: nil,
            holdSeconds: 45,
            restSeconds: 90,
            instructions: [
                RehabLocalizedText(en: "Loop a strong band around a sturdy anchor at knee height and around the back of both knees.", es: "Pasa una banda resistente alrededor de un anclaje firme a la altura de la rodilla y por detrás de ambas rodillas."),
                RehabLocalizedText(en: "Stand facing away from the anchor with feet hip-width apart, leaning back slightly into the band.", es: "Ponte de pie de espaldas al anclaje, con los pies separados al ancho de la cadera, apoyándote ligeramente hacia atrás en la banda."),
                RehabLocalizedText(en: "Bend your knees to a comfortable mid-range squat, keeping your torso upright.", es: "Flexiona las rodillas hasta un ángulo medio cómodo, manteniendo el torso erguido."),
                RehabLocalizedText(en: "Hold the position, keeping tension through the front of the knee, then stand back up.", es: "Mantén la posición, con tensión en la parte delantera de la rodilla, y luego vuelve a ponerte de pie.")
            ],
            painGuidance: RehabLocalizedText(
                en: "Up to ~4/10 pain during the hold is commonly considered acceptable for patellar tendon pain; it should settle back to baseline within 24 hours.",
                es: "Hasta ~4/10 de dolor durante el mantenido suele considerarse aceptable en dolor de tendón rotuliano; debe volver al nivel basal en 24 horas."
            ),
            cautions: [
                RehabLocalizedText(en: "Avoid jumping or deep squatting sports until this feels comfortable.", es: "Evita saltar o hacer sentadillas profundas en deporte hasta que esto se sienta cómodo.")
            ],
            referenceNote: RehabLocalizedText(
                en: "Based on the isometric protocol studied for in-season patellar tendinopathy pain relief (Rio et al.).",
                es: "Basado en el protocolo isométrico estudiado para el alivio del dolor de tendinopatía rotuliana en temporada (Rio et al.)."
            )
        ),

        RehabExercise(
            id: UUID(uuidString: "10000000-0000-0000-0000-000000000007")!,
            name: RehabLocalizedText(en: "Heel Slides", es: "Deslizamiento de Talón"),
            bodyRegion: .knee,
            structureFocus: .joint,
            protocolType: .mobility,
            stage: .acute,
            sets: 3,
            reps: 12,
            holdSeconds: nil,
            restSeconds: 30,
            instructions: [
                RehabLocalizedText(en: "Lie on your back with legs straight.", es: "Túmbate boca arriba con las piernas estiradas."),
                RehabLocalizedText(en: "Slowly slide your heel toward your glutes, bending the knee as far as comfortable.", es: "Desliza lentamente el talón hacia los glúteos, doblando la rodilla hasta donde sea cómodo."),
                RehabLocalizedText(en: "Hold briefly at end range, then slide back to straight.", es: "Mantén brevemente al final del rango y luego desliza de vuelta a la posición estirada.")
            ],
            painGuidance: RehabLocalizedText(
                en: "A mild pulling or stretching sensation is expected; keep sharp pain out of the movement.",
                es: "Se espera una sensación leve de tirantez o estiramiento; evita que el movimiento produzca dolor agudo."
            ),
            cautions: [
                RehabLocalizedText(en: "Do not force the bend past a point of resistance — regain range gradually over sessions.", es: "No fuerces la flexión más allá de un punto de resistencia — recupera el rango gradualmente a lo largo de las sesiones.")
            ],
            referenceNote: RehabLocalizedText(
                en: "Standard early-phase knee mobility drill after injury or surgery to restore flexion range.",
                es: "Ejercicio estándar de movilidad temprana de rodilla tras lesión o cirugía para recuperar el rango de flexión."
            )
        ),

        RehabExercise(
            id: UUID(uuidString: "10000000-0000-0000-0000-000000000008")!,
            name: RehabLocalizedText(en: "Quad Set", es: "Activación de Cuádriceps (Quad Set)"),
            bodyRegion: .knee,
            structureFocus: .muscle,
            protocolType: .activation,
            stage: .acute,
            sets: 3,
            reps: 10,
            holdSeconds: 5,
            restSeconds: 30,
            instructions: [
                RehabLocalizedText(en: "Sit or lie with the leg straight, a small rolled towel under the knee.", es: "Siéntate o túmbate con la pierna estirada, con una toalla enrollada bajo la rodilla."),
                RehabLocalizedText(en: "Press the back of the knee down into the towel, tightening the muscle on top of the thigh.", es: "Presiona la parte trasera de la rodilla contra la toalla, tensando el músculo delantero del muslo."),
                RehabLocalizedText(en: "Hold, then relax fully between reps.", es: "Mantén y luego relaja por completo entre repeticiones.")
            ],
            painGuidance: RehabLocalizedText(
                en: "This should feel like effort, not pain — keep discomfort under 3/10.",
                es: "Esto debe sentirse como esfuerzo, no como dolor — mantén la molestia por debajo de 3/10."
            ),
            cautions: [
                RehabLocalizedText(en: "Stop if the knee swells or feels warmer than usual after sessions.", es: "Detente si la rodilla se hincha o se siente más caliente de lo habitual después de las sesiones.")
            ],
            referenceNote: RehabLocalizedText(
                en: "A standard early quadriceps-activation drill used broadly in post-injury and post-surgical knee rehabilitation.",
                es: "Un ejercicio estándar de activación temprana de cuádriceps, ampliamente usado en rehabilitación de rodilla post-lesión y post-quirúrgica."
            )
        ),

        // MARK: - Ankle / Achilles

        RehabExercise(
            id: UUID(uuidString: "10000000-0000-0000-0000-000000000009")!,
            name: RehabLocalizedText(en: "Eccentric Heel Drop", es: "Bajada Excéntrica de Talón"),
            bodyRegion: .ankle,
            structureFocus: .tendon,
            protocolType: .eccentric,
            stage: .returnToActivity,
            sets: 3,
            reps: 15,
            holdSeconds: nil,
            restSeconds: 60,
            instructions: [
                RehabLocalizedText(en: "Stand on the edge of a step with your heels off the back, using a rail for balance.", es: "Ponte de pie en el borde de un escalón con los talones fuera, sujetándote a una barandilla para el equilibrio."),
                RehabLocalizedText(en: "Rise onto the toes of both feet.", es: "Elévate sobre las puntas de ambos pies."),
                RehabLocalizedText(en: "Shift your weight onto the affected leg and slowly lower the heel below step level over about 3 seconds.", es: "Traslada el peso a la pierna afectada y baja el talón lentamente por debajo del nivel del escalón durante unos 3 segundos."),
                RehabLocalizedText(en: "Use the other leg to help rise back up, then repeat. Do one set with the knee straight and, if prescribed, one with the knee slightly bent.", es: "Usa la otra pierna para ayudarte a subir y repite. Haz una serie con la rodilla recta y, si se indica, otra con la rodilla ligeramente flexionada.")
            ],
            painGuidance: RehabLocalizedText(
                en: "Pain up to ~4/10 during the lowering phase is generally considered acceptable in established loading protocols; it should ease within a day, not build up session over session.",
                es: "Un dolor de hasta ~4/10 durante la fase de bajada suele considerarse aceptable en protocolos de carga establecidos; debe aliviarse en un día, no acumularse sesión tras sesión."
            ),
            cautions: [
                RehabLocalizedText(en: "Do not perform after a suspected Achilles rupture or acute tear — get that assessed first.", es: "No lo realices tras una sospecha de rotura o desgarro agudo del Aquiles — haz que lo evalúen primero."),
                RehabLocalizedText(en: "Progress the daily volume gradually; this protocol is traditionally built up over several weeks.", es: "Progresa el volumen diario de forma gradual; este protocolo tradicionalmente se construye a lo largo de varias semanas.")
            ],
            referenceNote: RehabLocalizedText(
                en: "Based on Alfredson's heavy-load eccentric calf-raise protocol for Achilles tendinopathy (Alfredson et al., 1998).",
                es: "Basado en el protocolo excéntrico de carga alta de Alfredson para la tendinopatía aquílea (Alfredson et al., 1998)."
            )
        ),

        RehabExercise(
            id: UUID(uuidString: "10000000-0000-0000-0000-00000000000a")!,
            name: RehabLocalizedText(en: "Isometric Calf Raise Hold", es: "Elevación de Talón Isométrica"),
            bodyRegion: .ankle,
            structureFocus: .tendon,
            protocolType: .isometricHold,
            stage: .acute,
            sets: 5,
            reps: nil,
            holdSeconds: 30,
            restSeconds: 60,
            instructions: [
                RehabLocalizedText(en: "Stand holding onto a support, feet flat.", es: "Ponte de pie sujetándote a un apoyo, con los pies planos."),
                RehabLocalizedText(en: "Rise onto the balls of both feet to a comfortable mid-range height.", es: "Elévate sobre la punta de ambos pies hasta una altura media cómoda."),
                RehabLocalizedText(en: "Hold steady, keeping tension through the calf and Achilles.", es: "Mantén la posición estable, con tensión en el gemelo y el Aquiles."),
                RehabLocalizedText(en: "Lower under control and rest fully before the next hold.", es: "Baja de forma controlada y descansa por completo antes del siguiente mantenido.")
            ],
            painGuidance: RehabLocalizedText(
                en: "A gentler starting point than the eccentric drop — keep discomfort around 3–4/10 while symptoms are more irritable.",
                es: "Un punto de partida más suave que la bajada excéntrica — mantén la molestia entre 3 y 4/10 mientras los síntomas son más irritables."
            ),
            cautions: [
                RehabLocalizedText(en: "Use this version when the tendon is too irritable for the full eccentric drop below.", es: "Usa esta versión cuando el tendón está demasiado irritable para la bajada excéntrica completa.")
            ],
            referenceNote: RehabLocalizedText(
                en: "Isometric loading is used as a lower-irritability entry point before progressing to eccentric/heavy-slow protocols for tendinopathy.",
                es: "La carga isométrica se usa como punto de entrada de menor irritabilidad antes de progresar a protocolos excéntricos o de carga lenta pesada en tendinopatías."
            )
        ),

        RehabExercise(
            id: UUID(uuidString: "10000000-0000-0000-0000-00000000000b")!,
            name: RehabLocalizedText(en: "Ankle Alphabet", es: "Alfabeto con el Tobillo"),
            bodyRegion: .ankle,
            structureFocus: .joint,
            protocolType: .mobility,
            stage: .acute,
            sets: 2,
            reps: 1,
            holdSeconds: nil,
            restSeconds: 30,
            instructions: [
                RehabLocalizedText(en: "Sit with the leg extended and the ankle relaxed off a support.", es: "Siéntate con la pierna extendida y el tobillo relajado fuera de un apoyo."),
                RehabLocalizedText(en: "Using only your foot, \"draw\" each letter of the alphabet in the air.", es: "Usando solo el pie, \"dibuja\" en el aire cada letra del alfabeto."),
                RehabLocalizedText(en: "Move slowly and stay within a comfortable range.", es: "Muévete despacio y mantente dentro de un rango cómodo.")
            ],
            painGuidance: RehabLocalizedText(
                en: "Mild stiffness is normal after a sprain; keep this under 3/10 and avoid forcing any direction.",
                es: "Una rigidez leve es normal tras un esguince; mantente por debajo de 3/10 y evita forzar cualquier dirección."
            ),
            cautions: [
                RehabLocalizedText(en: "Avoid weight-bearing versions until cleared if there was a recent fracture.", es: "Evita versiones con carga de peso hasta ser autorizado si hubo una fractura reciente.")
            ],
            referenceNote: RehabLocalizedText(
                en: "A widely used low-load multi-directional mobility drill for early ankle sprain rehabilitation.",
                es: "Un ejercicio de movilidad multidireccional de baja carga, muy usado en rehabilitación temprana de esguinces de tobillo."
            )
        ),

        // MARK: - Hip

        RehabExercise(
            id: UUID(uuidString: "10000000-0000-0000-0000-00000000000c")!,
            name: RehabLocalizedText(en: "Isometric Bridge Hold", es: "Puente Isométrico"),
            bodyRegion: .hip,
            structureFocus: .tendon,
            protocolType: .isometricHold,
            stage: .subacute,
            sets: 4,
            reps: nil,
            holdSeconds: 30,
            restSeconds: 60,
            instructions: [
                RehabLocalizedText(en: "Lie on your back with knees bent, feet flat on the floor.", es: "Túmbate boca arriba con las rodillas dobladas y los pies apoyados en el suelo."),
                RehabLocalizedText(en: "Squeeze your glutes and lift your hips to a comfortable mid-range height.", es: "Aprieta los glúteos y eleva la cadera hasta una altura media cómoda."),
                RehabLocalizedText(en: "Hold steady, avoiding any pinching at the front of the hip.", es: "Mantén la posición estable, evitando cualquier pellizco en la parte delantera de la cadera."),
                RehabLocalizedText(en: "Lower slowly and rest before the next hold.", es: "Baja lentamente y descansa antes del siguiente mantenido.")
            ],
            painGuidance: RehabLocalizedText(
                en: "Up to ~4/10 in the buttock/tendon area is generally acceptable; front-of-hip pinching pain means the range is too deep.",
                es: "Hasta ~4/10 en la zona glútea/tendinosa suele ser aceptable; un pellizco doloroso en la parte delantera de la cadera indica que el rango es demasiado profundo."
            ),
            cautions: [
                RehabLocalizedText(en: "Reduce the height of the bridge if you feel hip pinching rather than muscle/tendon work.", es: "Reduce la altura del puente si sientes pellizco en la cadera en lugar de trabajo muscular/tendinoso.")
            ],
            referenceNote: RehabLocalizedText(
                en: "Applies isometric tendon-loading principles (as used for patellar/Achilles tendinopathy) to proximal hamstring and hip tendon irritation.",
                es: "Aplica los principios de carga isométrica tendinosa (como en tendinopatía rotuliana/aquílea) a la irritación del tendón proximal de isquiotibiales y cadera."
            )
        ),

        RehabExercise(
            id: UUID(uuidString: "10000000-0000-0000-0000-00000000000d")!,
            name: RehabLocalizedText(en: "90/90 Hip Switch", es: "Cambio de Cadera 90/90"),
            bodyRegion: .hip,
            structureFocus: .joint,
            protocolType: .mobility,
            stage: .subacute,
            sets: 3,
            reps: 8,
            holdSeconds: nil,
            restSeconds: 30,
            instructions: [
                RehabLocalizedText(en: "Sit on the floor with both knees bent to 90°, one leg in front and one out to the side.", es: "Siéntate en el suelo con ambas rodillas dobladas a 90°, una pierna delante y la otra hacia el lado."),
                RehabLocalizedText(en: "Keeping your seat on the floor, slowly rotate both legs to the other side, ending in the mirrored position.", es: "Manteniendo los glúteos en el suelo, rota lentamente ambas piernas hacia el otro lado, terminando en la posición espejo."),
                RehabLocalizedText(en: "Move slowly and use your hands on the floor for support as needed.", es: "Muévete despacio y apóyate con las manos en el suelo si lo necesitas.")
            ],
            painGuidance: RehabLocalizedText(
                en: "Expect a stretching sensation in the hip, not joint pain; keep it under 3–4/10.",
                es: "Espera una sensación de estiramiento en la cadera, no dolor articular; mantente por debajo de 3–4/10."
            ),
            cautions: [
                RehabLocalizedText(en: "Reduce the range if you feel pinching at the front of the hip.", es: "Reduce el rango si sientes pellizco en la parte delantera de la cadera.")
            ],
            referenceNote: RehabLocalizedText(
                en: "A standard controlled hip-rotation mobility drill used in hip and lower-back rehabilitation programs.",
                es: "Un ejercicio estándar de movilidad rotacional de cadera controlada, usado en programas de rehabilitación de cadera y zona lumbar."
            )
        ),

        RehabExercise(
            id: UUID(uuidString: "10000000-0000-0000-0000-00000000000e")!,
            name: RehabLocalizedText(en: "Side-Lying Clamshell", es: "Almeja Tumbado de Lado"),
            bodyRegion: .hip,
            structureFocus: .muscle,
            protocolType: .activation,
            stage: .subacute,
            sets: 3,
            reps: 15,
            holdSeconds: nil,
            restSeconds: 45,
            instructions: [
                RehabLocalizedText(en: "Lie on your side with hips and knees bent, feet together, in line with your body.", es: "Túmbate de lado con las caderas y rodillas dobladas, los pies juntos, alineado con el cuerpo."),
                RehabLocalizedText(en: "Keeping your feet together, lift the top knee like opening a clamshell.", es: "Manteniendo los pies juntos, eleva la rodilla de arriba como si abrieras una almeja."),
                RehabLocalizedText(en: "Avoid rolling your hips backward — keep the movement isolated to the hip.", es: "Evita rotar la cadera hacia atrás — mantén el movimiento aislado en la cadera."),
                RehabLocalizedText(en: "Lower under control and repeat.", es: "Baja de forma controlada y repite.")
            ],
            painGuidance: RehabLocalizedText(
                en: "This should feel like muscular effort in the side of the hip, not joint pain — keep under 3/10.",
                es: "Debe sentirse como esfuerzo muscular en el lateral de la cadera, no dolor articular — mantente por debajo de 3/10."
            ),
            cautions: [
                RehabLocalizedText(en: "Stop rolling the hips backward if you notice it creeping in — that usually means fatigue has set in.", es: "Deja de rotar la cadera hacia atrás si notas que empieza a aparecer — suele indicar fatiga.")
            ],
            referenceNote: RehabLocalizedText(
                en: "A standard gluteus medius activation exercise used broadly in hip, knee, and lower-back rehabilitation.",
                es: "Un ejercicio estándar de activación del glúteo medio, muy usado en rehabilitación de cadera, rodilla y zona lumbar."
            )
        ),

        // MARK: - Lower back

        RehabExercise(
            id: UUID(uuidString: "10000000-0000-0000-0000-00000000000f")!,
            name: RehabLocalizedText(en: "Cat-Camel Mobility", es: "Movilidad Gato-Camello"),
            bodyRegion: .lowerBack,
            structureFocus: .joint,
            protocolType: .mobility,
            stage: .acute,
            sets: 2,
            reps: 10,
            holdSeconds: nil,
            restSeconds: 30,
            instructions: [
                RehabLocalizedText(en: "Start on hands and knees, spine neutral.", es: "Comienza a cuatro patas, con la columna neutra."),
                RehabLocalizedText(en: "Slowly round your back toward the ceiling, tucking chin and pelvis.", es: "Redondea lentamente la espalda hacia el techo, metiendo la barbilla y la pelvis."),
                RehabLocalizedText(en: "Then slowly arch the other way, lifting chest and tailbone.", es: "Luego arquea lentamente hacia el otro lado, levantando el pecho y el coxis."),
                RehabLocalizedText(en: "Move through a comfortable range at a slow, controlled pace.", es: "Muévete dentro de un rango cómodo a un ritmo lento y controlado.")
            ],
            painGuidance: RehabLocalizedText(
                en: "This should feel like easy motion; keep any discomfort under 3/10 and avoid pushing into a sharp or radiating pain.",
                es: "Debe sentirse como un movimiento sencillo; mantén cualquier molestia por debajo de 3/10 y evita forzar hacia un dolor agudo o irradiado."
            ),
            cautions: [
                RehabLocalizedText(en: "Stop if pain radiates down a leg or arm — that needs a professional assessment.", es: "Detente si el dolor irradia hacia una pierna o brazo — eso requiere una valoración profesional.")
            ],
            referenceNote: RehabLocalizedText(
                en: "A classic gentle spinal mobility drill used across low-back rehabilitation programs.",
                es: "Un ejercicio clásico de movilidad espinal suave, usado en programas de rehabilitación lumbar."
            )
        ),

        RehabExercise(
            id: UUID(uuidString: "10000000-0000-0000-0000-000000000010")!,
            name: RehabLocalizedText(en: "Bird-Dog", es: "Bird-Dog"),
            bodyRegion: .lowerBack,
            structureFocus: .muscle,
            protocolType: .activation,
            stage: .subacute,
            sets: 3,
            reps: 8,
            holdSeconds: 5,
            restSeconds: 45,
            instructions: [
                RehabLocalizedText(en: "Start on hands and knees, spine neutral, core gently braced.", es: "Comienza a cuatro patas, columna neutra, core ligeramente activado."),
                RehabLocalizedText(en: "Slowly extend one arm forward and the opposite leg back, keeping your hips level.", es: "Extiende lentamente un brazo hacia adelante y la pierna opuesta hacia atrás, manteniendo las caderas niveladas."),
                RehabLocalizedText(en: "Hold briefly, then return with control and switch sides.", es: "Mantén brevemente y regresa con control, luego cambia de lado."),
                RehabLocalizedText(en: "Avoid rotating or dropping the hips throughout the movement.", es: "Evita rotar o dejar caer las caderas durante el movimiento.")
            ],
            painGuidance: RehabLocalizedText(
                en: "Expect low-back and core effort, not sharp pain; keep discomfort under 3/10.",
                es: "Espera esfuerzo lumbar y de core, no dolor agudo; mantén la molestia por debajo de 3/10."
            ),
            cautions: [
                RehabLocalizedText(en: "If you can't keep your hips level, reduce the range (e.g. arm only, or leg only) until control improves.", es: "Si no puedes mantener las caderas niveladas, reduce el rango (solo brazo, o solo pierna) hasta que mejore el control.")
            ],
            referenceNote: RehabLocalizedText(
                en: "A core-stability exercise widely used in evidence-based low-back rehabilitation programs.",
                es: "Un ejercicio de estabilidad del core, ampliamente usado en programas de rehabilitación lumbar basados en evidencia."
            )
        ),

        RehabExercise(
            id: UUID(uuidString: "10000000-0000-0000-0000-000000000011")!,
            name: RehabLocalizedText(en: "Dead Bug", es: "Dead Bug"),
            bodyRegion: .lowerBack,
            structureFocus: .muscle,
            protocolType: .activation,
            stage: .subacute,
            sets: 3,
            reps: 10,
            holdSeconds: nil,
            restSeconds: 45,
            instructions: [
                RehabLocalizedText(en: "Lie on your back, arms reaching toward the ceiling, hips and knees bent to 90°.", es: "Túmbate boca arriba, brazos hacia el techo, caderas y rodillas dobladas a 90°."),
                RehabLocalizedText(en: "Gently brace your core so your lower back stays in contact with the floor.", es: "Activa suavemente el core para que la zona lumbar permanezca en contacto con el suelo."),
                RehabLocalizedText(en: "Slowly lower one arm overhead and the opposite leg toward the floor.", es: "Baja lentamente un brazo por encima de la cabeza y la pierna opuesta hacia el suelo."),
                RehabLocalizedText(en: "Return to start with control and switch sides, keeping the back flat throughout.", es: "Vuelve al inicio con control y cambia de lado, manteniendo la espalda plana en todo momento.")
            ],
            painGuidance: RehabLocalizedText(
                en: "This should feel like controlled core effort; if your lower back arches or pain rises above 3/10, reduce the range.",
                es: "Debe sentirse como un esfuerzo controlado del core; si la zona lumbar se arquea o el dolor sube de 3/10, reduce el rango."
            ),
            cautions: [
                RehabLocalizedText(en: "Keep the range small enough that the lower back never lifts off the floor.", es: "Mantén el rango lo bastante pequeño para que la zona lumbar nunca se despegue del suelo.")
            ],
            referenceNote: RehabLocalizedText(
                en: "A standard anti-extension core-stability drill used in low-back rehabilitation programs.",
                es: "Un ejercicio estándar anti-extensión de estabilidad del core, usado en programas de rehabilitación lumbar."
            )
        ),

        // MARK: - Neck

        RehabExercise(
            id: UUID(uuidString: "10000000-0000-0000-0000-000000000012")!,
            name: RehabLocalizedText(en: "Chin Tuck", es: "Retracción de Barbilla"),
            bodyRegion: .neck,
            structureFocus: .joint,
            protocolType: .mobility,
            stage: .acute,
            sets: 3,
            reps: 10,
            holdSeconds: 5,
            restSeconds: 30,
            instructions: [
                RehabLocalizedText(en: "Sit or stand tall, looking straight ahead.", es: "Siéntate o ponte de pie erguido, mirando al frente."),
                RehabLocalizedText(en: "Gently draw your chin straight back, as if making a \"double chin\", without tilting your head down.", es: "Lleva suavemente la barbilla hacia atrás, como haciendo \"doble mentón\", sin inclinar la cabeza hacia abajo."),
                RehabLocalizedText(en: "Hold briefly, feeling a gentle stretch at the base of the skull.", es: "Mantén brevemente, sintiendo un estiramiento suave en la base del cráneo."),
                RehabLocalizedText(en: "Release slowly back to neutral.", es: "Suelta lentamente de vuelta a la posición neutra.")
            ],
            painGuidance: RehabLocalizedText(
                en: "Expect a mild stretch, not pain; keep it under 3/10 and stop if you feel dizziness.",
                es: "Espera un estiramiento leve, no dolor; mantente por debajo de 3/10 y detente si sientes mareo."
            ),
            cautions: [
                RehabLocalizedText(en: "Stop if you feel dizziness, tingling in the arms, or a sharp increase in headache.", es: "Detente si sientes mareo, hormigueo en los brazos o un aumento agudo del dolor de cabeza.")
            ],
            referenceNote: RehabLocalizedText(
                en: "A standard deep neck flexor activation and postural mobility drill used in cervical rehabilitation programs.",
                es: "Un ejercicio estándar de activación de flexores profundos del cuello y movilidad postural, usado en programas de rehabilitación cervical."
            )
        )
    ]
}
