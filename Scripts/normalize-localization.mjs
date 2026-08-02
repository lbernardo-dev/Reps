import crypto from "node:crypto";
import fs from "node:fs";
import path from "node:path";

const root = path.resolve(path.dirname(new URL(import.meta.url).pathname), "..");
const catalogPath = path.join(root, "Reps/Resources/Localizable.xcstrings");
const catalog = JSON.parse(fs.readFileSync(catalogPath, "utf8"));
const roots = ["Reps", "RepsShared", "RepsWidgets", "RepsWatch"];
const files = [];

function walk(relativeDirectory) {
    for (const entry of fs.readdirSync(path.join(root, relativeDirectory), { withFileTypes: true })) {
        const relative = path.join(relativeDirectory, entry.name);
        if (entry.isDirectory()) walk(relative);
        else if (entry.name.endsWith(".swift")) files.push(relative);
    }
}

roots.forEach(walk);
const sources = new Map(files.map(file => [file, fs.readFileSync(path.join(root, file), "utf8")]));

function stripAccents(value) {
    return value.normalize("NFD").replace(/[\u0300-\u036f]/g, "");
}

function snake(value) {
    const normalized = stripAccents(value)
        .replace(/\\\([^)]*\\\)/g, " value ")
        .replace(/%\d+\$?[@dfisu]/g, " value ")
        .replace(/%@|%lld|%ld|%d|%f/g, " value ")
        .replace(/[^A-Za-z0-9]+/g, " ")
        .trim()
        .toLowerCase()
        .replace(/\s+/g, "_");
    return normalized || "text";
}

function hash(value) {
    return crypto.createHash("sha1").update(value).digest("hex").slice(0, 8);
}

function canonicalKey(oldKey, entry) {
    const english = entry?.localizations?.en?.stringUnit?.value || oldKey;
    const base = snake(english);
    const formatOnly = !/[A-Za-z]{2}/.test(english) || /^value(_value)*$/.test(base);
    const candidate = formatOnly ? "format_" + hash(oldKey) : base;
    return /^[a-z]/.test(candidate) ? candidate : "text_" + candidate;
}

function unit(value) {
    return { stringUnit: { state: "translated", value } };
}

function humanize(key) {
    return key.replace(/^text_/, "").replace(/_/g, " ").replace(/\b\w/g, char => char.toUpperCase());
}

function sourceValue(entry, language, oldKey) {
    return entry?.localizations?.[language]?.stringUnit?.value
        || (language === "en" ? oldKey : entry?.localizations?.en?.stringUnit?.value || oldKey);
}

const contextPattern = /(?:localizedString|localizedKey|localizedFormat|localizedCatalogValue|onboardingLocalizedString|settingsDisplayText|settingsFormatText|Text|Label|Button|Section|Toggle|Picker|TextField|navigationTitle|accessibilityLabel|alert|confirmationDialog)\(\s*"([^"]*)"/g;
const localizedUsages = new Set();
for (const source of sources.values()) {
    for (const match of source.matchAll(contextPattern)) localizedUsages.add(match[1]);
    for (const match of source.matchAll(/\b(?:localizedString|localizedKey|localizedFormat|onboardingLocalizedString|settingsDisplayText|settingsFormatText)\("([^"]+)"\)/g)) {
        localizedUsages.add(match[1]);
    }
    for (const match of source.matchAll(/(?:key|titleKey|subtitleKey)\s*:\s*"([^"]+)"/g)) localizedUsages.add(match[1]);
    for (const match of source.matchAll(/RehabLocalizedText\(key:\s*"([^"]+)"/g)) localizedUsages.add(match[1]);
    for (const match of source.matchAll(/String\(localized:\s*"([^"]*)"/g)) localizedUsages.add(match[1]);
    for (const match of source.matchAll(/LocalizedStringResource\((?:stringLiteral:\s*)?"([^"]*)"/g)) localizedUsages.add(match[1]);
}

const entries = new Map();
const mappings = new Map();
const usedKeys = new Set();

function addEntry(key, entry, oldKey) {
    let finalKey = key;
    if (entries.has(finalKey) && JSON.stringify(entries.get(finalKey)) !== JSON.stringify(entry)) {
        finalKey = key + "_" + hash(oldKey);
    }
    entries.set(finalKey, entry);
    usedKeys.add(finalKey);
    return finalKey;
}

for (const [oldKey, entry] of Object.entries(catalog.strings)) {
    if (!localizedUsages.has(oldKey)) continue;
    const key = /^[a-z][a-z0-9]*(_[a-z0-9]+)*$/.test(oldKey) ? oldKey : canonicalKey(oldKey, entry);
    const normalized = {
        localizations: {
            en: unit(sourceValue(entry, "en", oldKey)),
            es: unit(sourceValue(entry, "es", oldKey))
        }
    };
    if (entry.comment) normalized.comment = entry.comment;
    mappings.set(oldKey, addEntry(key, normalized, oldKey));
}

// Exercise labels and guidance are resolved from deterministic runtime keys
// (for example `exercise_barbell_bench_press`), so no individual literal is
// present at the call site for the scanner to find. They are still release
// content and must survive normalization.
for (const [oldKey, entry] of Object.entries(catalog.strings)) {
    if (!/^(?:exercise|muscle|equipment|workout_title|workout_subtitle)_/.test(oldKey) || mappings.has(oldKey)) continue;
    const normalized = {
        localizations: {
            en: unit(sourceValue(entry, "en", oldKey)),
            es: unit(sourceValue(entry, "es", oldKey))
        }
    };
    if (entry.comment) normalized.comment = entry.comment;
    mappings.set(oldKey, addEntry(oldKey, normalized, oldKey));
}

for (const usage of localizedUsages) {
    if (usage.includes("\\n") || usage.length === 0 || usage.includes("://")) continue;
    if (mappings.has(usage)) continue;
    const key = /^[a-z][a-z0-9]*(_[a-z0-9]+)*$/.test(usage) ? usage : canonicalKey(usage);
    mappings.set(usage, addEntry(key, {
        localizations: {
            en: unit(humanize(key)),
            es: unit(humanize(key))
        }
    }, usage));
}

// Keep source code aligned with the catalog contract. Only rewrite literal
// arguments passed to localization APIs; SwiftUI expressions and ordinary
// string values are deliberately left untouched for manual migration.
for (const [relativeFile, originalSource] of sources) {
    const source = originalSource.replace(
        /\b(String\(localized:\s*|LocalizedStringResource\(\s*(?:stringLiteral:\s*)?|localizedString\(\s*|localizedKey\(\s*|localizedFormat\(\s*)("((?:\\.|[^"\\])*)")/g,
        (match, prefix, quoted, key) => {
            const mapped = mappings.get(key);
            return mapped && mapped !== key ? prefix + JSON.stringify(mapped) : match;
        }
    );
    if (source !== originalSource) fs.writeFileSync(path.join(root, relativeFile), source);
}

const rehabFiles = ["Reps/Models/RehabModels.swift", "Reps/Models/RehabSeedData.swift"];
const rehabPattern = /RehabLocalizedText\(\s*en:\s*"((?:\\.|[^"\\])*)"\s*,\s*es:\s*"((?:\\.|[^"\\])*)"\s*\)/g;
const decodeSwift = raw => raw
    .replace(/\\"/g, "\"")
    .replace(/\\\\/g, "\\")
    .replace(/\\n/g, "\n")
    .replace(/\\t/g, "\t");
for (const relativeFile of rehabFiles) {
    const absoluteFile = path.join(root, relativeFile);
    let source = fs.readFileSync(absoluteFile, "utf8");
    source = source.replace(rehabPattern, (match, rawEnglish, rawSpanish) => {
        const english = decodeSwift(rawEnglish);
        const spanish = decodeSwift(rawSpanish);
        const key = "rehab_" + snake(english).slice(0, 72).replace(/_+$/, "");
        entries.set(key, { localizations: { en: unit(english), es: unit(spanish) } });
        return "RehabLocalizedText(key: \"" + key + "\")";
    });
    fs.writeFileSync(absoluteFile, source);
}

const ordered = Object.fromEntries([...entries.entries()].sort(([a], [b]) => a.localeCompare(b)));
fs.writeFileSync(catalogPath, JSON.stringify({ sourceLanguage: "en", version: "1.0", strings: ordered }, null, 2) + "\n");
const sharedPath = path.join(root, "RepsShared/WorkoutShared.swift");
let shared = fs.readFileSync(sharedPath, "utf8").replace(
    /\n    private static let localizedFallbacks\s*:\s*\[[\s\S]*?\n    \]\n\n    private static func normalizedSupportedLanguage/,
    "\n    private static func normalizedSupportedLanguage"
);
shared = shared.replace(
    /\n        if let fallback = localizedFallbacks\[activeLanguage\]\?\[key\] \?\? localizedFallbacks\["en"\]\?\[key\] \{\n            return fallback\n        \}/,
    ""
);
fs.writeFileSync(sharedPath, shared);
console.log("Localization normalized safely: " + usedKeys.size + " active keys.");
