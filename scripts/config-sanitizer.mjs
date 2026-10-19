#!/usr/bin/env node

import fs from 'node:fs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';

export const SECRET_MARKER = '__DOTFILES_LOCAL_SECRET__';
export const HOME_MARKER = '__DOTFILES_HOME__';

const OMIT = Symbol('omit');
const CLAUDE_PORTABLE_PREFERENCES = new Set([
  'ccAutoArchiveInactiveDays',
  'ccdScheduledTasksEnabled',
  'coworkBrowserToolsEnabled',
  'coworkHipaaRestricted',
  'coworkScheduledTasksEnabled',
  'coworkWebSearchEnabled',
  'dockBounceEnabled',
  'launchPreviewPersistedWorkspaces',
  'launchPreviewSessionScopedSessions',
  'menuBarEnabled',
  'orgWorkAcrossAppsDisabled',
  'sidebarMode',
]);

function normalizedKey(key) {
  return String(key)
    .replace(/([a-z0-9])([A-Z])/g, '$1_$2')
    .toLowerCase()
    .replace(/[:.-]+/g, '_');
}

export function isSensitiveKey(key) {
  const normalized = normalizedKey(key);
  if (normalized.includes('authorization')) return true;
  if (/^oauth_?token_cache(?:_v?2)?$/.test(normalized)) return true;
  return /(^|_)(auth_token|access_token|refresh_token|api_key|client_secret|secret|password|passwd|cookie|credentials?)(?=$|_)/.test(
    normalized,
  );
}

function replaceAll(value, search, replacement) {
  if (!search) return value;
  return value.split(search).join(replacement);
}

function clone(value) {
  return value === undefined ? undefined : structuredClone(value);
}

function sanitizeNode(value, home) {
  if (typeof value === 'string') return replaceAll(value, home, HOME_MARKER);
  if (Array.isArray(value)) return value.map((item) => sanitizeNode(item, home));
  if (!value || typeof value !== 'object') return value;

  const output = {};
  for (const [key, child] of Object.entries(value)) {
    output[key] = isSensitiveKey(key) ? SECRET_MARKER : sanitizeNode(child, home);
  }
  return output;
}

export function sanitizeJsonSecrets(value, home = '') {
  return sanitizeNode(value, home);
}

function renderTemplateNode(template, local, home) {
  if (template === SECRET_MARKER) {
    return local === undefined ? OMIT : clone(local);
  }
  if (typeof template === 'string') {
    return replaceAll(template, HOME_MARKER, home);
  }
  if (Array.isArray(template)) {
    const output = [];
    for (let index = 0; index < template.length; index += 1) {
      const rendered = renderTemplateNode(template[index], local?.[index], home);
      if (rendered !== OMIT) output.push(rendered);
    }
    return output;
  }
  if (!template || typeof template !== 'object') return template;

  const output = {};
  for (const [key, child] of Object.entries(template)) {
    const rendered = renderTemplateNode(child, local?.[key], home);
    if (rendered !== OMIT) output[key] = rendered;
  }
  return output;
}

export function mergeJsonSecrets(template, local = {}, home = '') {
  const rendered = renderTemplateNode(template, local, home);
  return rendered === OMIT ? {} : rendered;
}

function overlayTemplateNode(template, local, home) {
  if (template === SECRET_MARKER) {
    return local === undefined ? OMIT : clone(local);
  }
  if (typeof template === 'string') {
    return replaceAll(template, HOME_MARKER, home);
  }
  if (Array.isArray(template)) return renderTemplateNode(template, local, home);
  if (!template || typeof template !== 'object') return template;

  const output = local && typeof local === 'object' && !Array.isArray(local) ? clone(local) : {};
  for (const [key, child] of Object.entries(template)) {
    const rendered = overlayTemplateNode(child, local?.[key], home);
    if (rendered === OMIT) delete output[key];
    else output[key] = rendered;
  }
  return output;
}

export function mergeJsonOverlay(template, local = {}, home = '') {
  return overlayTemplateNode(template, local, home);
}

function parseTomlLine(line) {
  const match = line.match(
    /^(\s*)((?:"(?:[^"\\]|\\.)*"|'[^']*'|[A-Za-z0-9_.-]+))(\s*=\s*)(.*)$/,
  );
  if (!match) return null;
  const rawKey = match[2];
  const key =
    (rawKey.startsWith('"') && rawKey.endsWith('"')) ||
    (rawKey.startsWith("'") && rawKey.endsWith("'"))
      ? rawKey.slice(1, -1)
      : rawKey;
  return { indent: match[1], rawKey, separator: match[3], value: match[4], key };
}

function tomlSection(line, current) {
  const match = line.match(/^\s*(\[\[?[^\]]+\]\]?)\s*(?:#.*)?$/);
  return match ? match[1] : current;
}

function sanitizeTomlInlineValue(value) {
  return value.replace(
    /((?:"(?:[^"\\]|\\.)*"|'[^']*'|[A-Za-z0-9_.-]+)\s*=\s*)("(?:[^"\\]|\\.)*"|'[^']*'|[^,}\s]+)/g,
    (assignment, prefix, rawValue) => {
      const keyMatch = prefix.match(/^\s*("(?:[^"\\]|\\.)*"|'[^']*'|[A-Za-z0-9_.-]+)\s*=/);
      if (!keyMatch) return assignment;
      const rawKey = keyMatch[1];
      const key =
        (rawKey.startsWith('"') && rawKey.endsWith('"')) ||
        (rawKey.startsWith("'") && rawKey.endsWith("'"))
          ? rawKey.slice(1, -1)
          : rawKey;
      return isSensitiveKey(key) ? `${prefix}"${SECRET_MARKER}"` : `${prefix}${rawValue}`;
    },
  );
}

export function sanitizeToml(text, home = '') {
  let section = '';
  const lines = text.split('\n').map((line) => {
    section = tomlSection(line, section);
    const parsed = parseTomlLine(line);
    if (!parsed) return line;
    if (isSensitiveKey(parsed.key)) {
      return `${parsed.indent}${parsed.rawKey}${parsed.separator}"${SECRET_MARKER}"`;
    }
    const sanitizedValue = sanitizeTomlInlineValue(parsed.value);
    return `${parsed.indent}${parsed.rawKey}${parsed.separator}${sanitizedValue}`;
  });
  return replaceAll(lines.join('\n'), home, HOME_MARKER);
}

function tomlValueMap(text) {
  let section = '';
  const values = new Map();
  for (const line of text.split('\n')) {
    section = tomlSection(line, section);
    const parsed = parseTomlLine(line);
    if (parsed) values.set(`${section}\u0000${parsed.key}`, parsed.value);
  }
  return values;
}

export function renderToml(template, local = '', home = '') {
  const localValues = tomlValueMap(local);
  let section = '';
  const lines = [];
  for (const line of template.split('\n')) {
    section = tomlSection(line, section);
    const parsed = parseTomlLine(line);
    if (!parsed || !parsed.value.includes(SECRET_MARKER)) {
      lines.push(line);
      continue;
    }

    const localValue = localValues.get(`${section}\u0000${parsed.key}`);
    if (localValue === undefined) continue;
    lines.push(`${parsed.indent}${parsed.rawKey}${parsed.separator}${localValue}`);
  }
  return replaceAll(lines.join('\n'), HOME_MARKER, home);
}

function parseShellAssignment(line) {
  const match = line.match(/^(\s*(?:export\s+)?)([A-Za-z_][A-Za-z0-9_]*)(\s*=\s*)(.*)$/);
  if (!match) return null;
  return { prefix: match[1], key: match[2], separator: match[3], value: match[4] };
}

export function sanitizeShell(text, home = '') {
  const lines = text.split('\n').map((line) => {
    const parsed = parseShellAssignment(line);
    if (!parsed || !isSensitiveKey(parsed.key)) return line;
    return `${parsed.prefix}${parsed.key}${parsed.separator}"${SECRET_MARKER}"`;
  });
  return replaceAll(lines.join('\n'), home, HOME_MARKER);
}

function shellValueMap(text) {
  const values = new Map();
  for (const line of text.split('\n')) {
    const parsed = parseShellAssignment(line);
    if (parsed) values.set(parsed.key, parsed.value);
  }
  return values;
}

export function renderShell(template, local = '', home = '') {
  const localValues = shellValueMap(local);
  const lines = [];
  for (const line of template.split('\n')) {
    const parsed = parseShellAssignment(line);
    if (!parsed || !parsed.value.includes(SECRET_MARKER)) {
      lines.push(line);
      continue;
    }

    const localValue = localValues.get(parsed.key);
    if (localValue === undefined) continue;
    lines.push(`${parsed.prefix}${parsed.key}${parsed.separator}${localValue}`);
  }
  return replaceAll(lines.join('\n'), HOME_MARKER, home);
}

export function sanitizeTextHome(text, home = '') {
  return replaceAll(text, home, HOME_MARKER);
}

export function renderTextHome(template, home = '') {
  return replaceAll(template, HOME_MARKER, home);
}

export function selectClaudeDesktopPortable(source, home = '') {
  const portable = {};
  if (Object.hasOwn(source, 'deploymentMode')) portable.deploymentMode = source.deploymentMode;

  if (source.preferences && typeof source.preferences === 'object') {
    const preferences = {};
    for (const key of CLAUDE_PORTABLE_PREFERENCES) {
      if (Object.hasOwn(source.preferences, key)) preferences[key] = source.preferences[key];
    }
    if (Object.keys(preferences).length > 0) portable.preferences = preferences;
  }

  if (source.mcpServers && typeof source.mcpServers === 'object') {
    portable.mcpServers = source.mcpServers;
  }
  return sanitizeJsonSecrets(portable, home);
}

function readJson(file) {
  if (!file || !fs.existsSync(file)) return {};
  return JSON.parse(fs.readFileSync(file, 'utf8'));
}

function atomicWrite(file, content) {
  fs.mkdirSync(path.dirname(file), { recursive: true });
  const temporary = `${file}.tmp-${process.pid}`;
  fs.writeFileSync(temporary, content, { mode: 0o600 });
  fs.renameSync(temporary, file);
}

function writeJson(file, value) {
  atomicWrite(file, `${JSON.stringify(value, null, 2)}\n`);
}

function usage() {
  console.error(`Usage:
  config-sanitizer.mjs json-backup SOURCE TARGET HOME
  config-sanitizer.mjs json-restore TEMPLATE LIVE TARGET HOME
  config-sanitizer.mjs toml-backup SOURCE TARGET HOME
  config-sanitizer.mjs toml-restore TEMPLATE LIVE TARGET HOME
  config-sanitizer.mjs shell-backup SOURCE TARGET HOME
  config-sanitizer.mjs shell-restore TEMPLATE LIVE TARGET HOME
  config-sanitizer.mjs text-backup SOURCE TARGET HOME
  config-sanitizer.mjs text-restore TEMPLATE TARGET HOME
  config-sanitizer.mjs claude-desktop-backup SOURCE TARGET HOME
  config-sanitizer.mjs claude-desktop-restore TEMPLATE LIVE TARGET HOME`);
}

function main(argv) {
  const [command, ...args] = argv;
  switch (command) {
    case 'json-backup': {
      const [source, target, home = ''] = args;
      writeJson(target, sanitizeJsonSecrets(readJson(source), home));
      break;
    }
    case 'json-restore': {
      const [template, live, target, home = ''] = args;
      writeJson(target, mergeJsonSecrets(readJson(template), readJson(live), home));
      break;
    }
    case 'toml-backup': {
      const [source, target, home = ''] = args;
      atomicWrite(target, sanitizeToml(fs.readFileSync(source, 'utf8'), home));
      break;
    }
    case 'toml-restore': {
      const [template, live, target, home = ''] = args;
      const local = live && fs.existsSync(live) ? fs.readFileSync(live, 'utf8') : '';
      atomicWrite(target, renderToml(fs.readFileSync(template, 'utf8'), local, home));
      break;
    }
    case 'shell-backup': {
      const [source, target, home = ''] = args;
      atomicWrite(target, sanitizeShell(fs.readFileSync(source, 'utf8'), home));
      break;
    }
    case 'shell-restore': {
      const [template, live, target, home = ''] = args;
      const local = live && fs.existsSync(live) ? fs.readFileSync(live, 'utf8') : '';
      atomicWrite(target, renderShell(fs.readFileSync(template, 'utf8'), local, home));
      break;
    }
    case 'text-backup': {
      const [source, target, home = ''] = args;
      atomicWrite(target, sanitizeTextHome(fs.readFileSync(source, 'utf8'), home));
      break;
    }
    case 'text-restore': {
      const [template, target, home = ''] = args;
      atomicWrite(target, renderTextHome(fs.readFileSync(template, 'utf8'), home));
      break;
    }
    case 'claude-desktop-backup': {
      const [source, target, home = ''] = args;
      writeJson(target, selectClaudeDesktopPortable(readJson(source), home));
      break;
    }
    case 'claude-desktop-restore': {
      const [template, live, target, home = ''] = args;
      writeJson(target, mergeJsonOverlay(readJson(template), readJson(live), home));
      break;
    }
    default:
      usage();
      process.exitCode = 2;
  }
}

const isMain =
  process.argv[1] &&
  fs.realpathSync(fileURLToPath(import.meta.url)) === fs.realpathSync(path.resolve(process.argv[1]));
if (isMain) main(process.argv.slice(2));
