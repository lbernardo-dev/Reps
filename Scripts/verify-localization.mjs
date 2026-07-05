import fs from "node:fs";
import path from "node:path";

const root = path.resolve(path.dirname(new URL(import.meta.url).pathname), "..");

const catalogPaths = [
  "Reps/Resources/Localizable.xcstrings",
  "Reps/Resources/InfoPlist.xcstrings",
  "RepsWidgets/InfoPlist.xcstrings",
  "RepsWatch/InfoPlist.xcstrings",
];

const errors = [];

function readJSON(relativePath) {
  return JSON.parse(fs.readFileSync(path.join(root, relativePath), "utf8"));
}

function walk(dir, files = []) {
  for (const entry of fs.readdirSync(dir, { withFileTypes: true })) {
    const fullPath = path.join(dir, entry.name);
    if (entry.isDirectory()) {
      if (![".git", "DerivedData"].includes(entry.name)) walk(fullPath, files);
    } else if (entry.name.endsWith(".swift")) {
      files.push(fullPath);
    }
  }
  return files;
}

function extractSwiftStrings(source) {
  const strings = [];
  let i = 0;
  while (i < source.length) {
    if (source[i] !== "\"") {
      i += 1;
      continue;
    }

    i += 1;
    let value = "";
    let escaped = false;
    while (i < source.length) {
      const char = source[i];
      if (escaped) {
        value += char;
        escaped = false;
        i += 1;
        continue;
      }
      if (char === "\\") {
        value += char;
        escaped = true;
        i += 1;
        continue;
      }
      if (char === "\"") {
        i += 1;
        strings.push(value);
        break;
      }
      value += char;
      i += 1;
    }
  }
  return strings;
}

const spanishSignal = /[\u00C1\u00C9\u00CD\u00D3\u00DA\u00D1\u00E1\u00E9\u00ED\u00F3\u00FA\u00F1\u00BF\u00A1]|\b(entreno|entrenos|sesion|sesiones|serie|series|siguiente|guardar|cancelar|cerrar|peso|altura|fecha|agua|descanso|ejercicio|objetivo|permiso|anade|anadir|metricas|cuerpo|gimnasio|notificaciones|microfono|camara|fotos|semana|semanales|dias|calorias|duracion|distancia|notas|compartir|biblioteca|progreso|rutina|programa|activa|mostrar|marcar|perfil|salud|logros|recibos|calendario|volver|empezar|plantillas|hoy|ayer)\b/i;
const strongSpanishInEnglish = /[\u00C1\u00C9\u00CD\u00D3\u00DA\u00D1\u00E1\u00E9\u00ED\u00F3\u00FA\u00F1\u00BF\u00A1]|\b(dias|semana|semanales|duracion|entrenado|directas|ultimos|recomienda|ejercicios|descanso|objetivo|previo|entreno|sesion)\b/i;

const catalogs = catalogPaths.map((relativePath) => [relativePath, readJSON(relativePath)]);
const localizable = readJSON("Reps/Resources/Localizable.xcstrings");
const localizableKeys = new Set(Object.keys(localizable.strings));

function placeholders(value) {
  return [...value.matchAll(/%(?:\d+\$)?(?:\.\d+)?[@dfisu]/g)].map((match) =>
    match[0].replace(/^\%(\d+\$)?(?:\.\d+)?/, "%")
  );
}

function samePlaceholders(a, b) {
  const left = placeholders(a).sort();
  const right = placeholders(b).sort();
  return left.length === right.length && left.every((value, index) => value === right[index]);
}

for (const [relativePath, catalog] of catalogs) {
  if (catalog.sourceLanguage !== "es") {
    errors.push(`${relativePath}: expected sourceLanguage "es", got "${catalog.sourceLanguage}"`);
  }
  let staleCount = 0;
  for (const [key, entry] of Object.entries(catalog.strings)) {
    const isStale = entry.extractionState === "stale";
    if (entry.extractionState === "stale") {
      staleCount += 1;
    }

    if (isStale) continue;

    for (const language of ["en", "es"]) {
      const unit = entry.localizations?.[language]?.stringUnit;
      if (!unit?.value) {
        errors.push(`${relativePath}: key "${key}" is missing ${language}`);
      } else if (unit.state !== "translated") {
        errors.push(`${relativePath}: key "${key}" has ${language} state "${unit.state}"`);
      }
    }
    const english = entry.localizations?.en?.stringUnit?.value ?? "";
    if (strongSpanishInEnglish.test(english)) {
      errors.push(`${relativePath}: English value still looks Spanish for key "${key}" -> "${english}"`);
    }
    const spanish = entry.localizations?.es?.stringUnit?.value ?? "";
    if (english && spanish && !samePlaceholders(english, spanish)) {
      errors.push(`${relativePath}: placeholder mismatch for key "${key}"`);
    }
  }
  if (staleCount > 0) {
    console.warn(`${relativePath}: ${staleCount} stale entries ignored by release gate; schedule catalog cleanup.`);
  }
}

const project = fs.readFileSync(path.join(root, "Reps.xcodeproj/project.pbxproj"), "utf8");
const localizableResourceCount = (project.match(/Localizable\.xcstrings in Resources/g) ?? []).length;
const infoPlistResourceCount = (project.match(/InfoPlist\.xcstrings in Resources/g) ?? []).length;
if (!project.includes("developmentRegion = es;")) {
  errors.push("Reps.xcodeproj/project.pbxproj: developmentRegion is not es");
}
if (localizableResourceCount < 3) {
  errors.push(`Expected Localizable.xcstrings in at least 3 resource phases, found ${localizableResourceCount}`);
}
if (infoPlistResourceCount < 3) {
  errors.push(`Expected InfoPlist.xcstrings in at least 3 resource phases, found ${infoPlistResourceCount}`);
}

for (const swiftFile of walk(root)) {
  const relativePath = path.relative(root, swiftFile);
  if (relativePath.startsWith("Scripts/")) continue;
  const source = fs.readFileSync(swiftFile, "utf8");
  for (const value of extractSwiftStrings(source)) {
    if (spanishSignal.test(value) && !localizableKeys.has(value)) {
      errors.push(`${relativePath}: Spanish literal is not present in Localizable.xcstrings -> "${value}"`);
    }
  }
}

if (errors.length > 0) {
  console.error(errors.join("\n"));
  process.exit(1);
}

console.log("Localization verification passed.");
