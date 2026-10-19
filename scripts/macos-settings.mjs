#!/usr/bin/env node

import fs from 'node:fs';
import os from 'node:os';
import path from 'node:path';
import { spawnSync } from 'node:child_process';
import { fileURLToPath } from 'node:url';

export const HOME_MARKER = '__DOTFILES_HOME__';

const SCALAR_SCHEMA = {
  NSGlobalDomain: {
    AppleICUForce24HourTime: 'bool',
    AppleInterfaceStyle: 'string',
    AppleInterfaceStyleSwitchesAutomatically: 'bool',
    AppleMeasurementUnits: 'string',
    AppleMetricUnits: 'bool',
    ApplePressAndHoldEnabled: 'bool',
    AppleShowAllExtensions: 'bool',
    AppleShowScrollBars: 'string',
    AppleTemperatureUnit: 'string',
    InitialKeyRepeat: 'int',
    KeyRepeat: 'int',
    NSAutomaticCapitalizationEnabled: 'bool',
    NSAutomaticDashSubstitutionEnabled: 'bool',
    NSAutomaticPeriodSubstitutionEnabled: 'bool',
    NSAutomaticQuoteSubstitutionEnabled: 'bool',
    NSAutomaticSpellingCorrectionEnabled: 'bool',
    NSNavPanelExpandedStateForSaveMode: 'bool',
    NSNavPanelExpandedStateForSaveMode2: 'bool',
    'com.apple.mouse.scaling': 'float',
    'com.apple.swipescrolldirection': 'bool',
    'com.apple.trackpad.scaling': 'float',
  },
  'com.apple.HIToolbox': {
    AppleFnUsageType: 'int',
    TextInputGlobalPropertyPerContextInput: 'bool',
  },
  'com.apple.AppleMultitouchTrackpad': {
    Clicking: 'bool',
    DragLock: 'bool',
    Dragging: 'bool',
    TrackpadCornerSecondaryClick: 'int',
    TrackpadFourFingerHorizSwipeGesture: 'int',
    TrackpadFourFingerPinchGesture: 'int',
    TrackpadFourFingerVertSwipeGesture: 'int',
    TrackpadMomentumScroll: 'bool',
    TrackpadPinch: 'bool',
    TrackpadRightClick: 'bool',
    TrackpadRotate: 'bool',
    TrackpadScroll: 'bool',
    TrackpadThreeFingerDrag: 'bool',
    TrackpadThreeFingerHorizSwipeGesture: 'int',
    TrackpadThreeFingerTapGesture: 'int',
    TrackpadThreeFingerVertSwipeGesture: 'int',
    TrackpadTwoFingerDoubleTapGesture: 'int',
    TrackpadTwoFingerFromRightEdgeSwipeGesture: 'int',
    USBMouseStopsTrackpad: 'bool',
  },
  'com.apple.driver.AppleBluetoothMultitouch.trackpad': {
    Clicking: 'bool',
    DragLock: 'bool',
    Dragging: 'bool',
    TrackpadCornerSecondaryClick: 'int',
    TrackpadFourFingerHorizSwipeGesture: 'int',
    TrackpadFourFingerPinchGesture: 'int',
    TrackpadFourFingerVertSwipeGesture: 'int',
    TrackpadMomentumScroll: 'bool',
    TrackpadPinch: 'bool',
    TrackpadRightClick: 'bool',
    TrackpadRotate: 'bool',
    TrackpadScroll: 'bool',
    TrackpadThreeFingerDrag: 'bool',
    TrackpadThreeFingerHorizSwipeGesture: 'int',
    TrackpadThreeFingerTapGesture: 'int',
    TrackpadThreeFingerVertSwipeGesture: 'int',
    TrackpadTwoFingerDoubleTapGesture: 'int',
    TrackpadTwoFingerFromRightEdgeSwipeGesture: 'int',
    USBMouseStopsTrackpad: 'bool',
  },
  'com.apple.finder': {
    AppleShowAllFiles: 'bool',
    AppleShowAllExtensions: 'bool',
    FXDefaultSearchScope: 'string',
    FXEnableExtensionChangeWarning: 'bool',
    FXPreferredViewStyle: 'string',
    FXRemoveOldTrashItems: 'bool',
    ShowPathbar: 'bool',
    ShowStatusBar: 'bool',
    _FXSortFoldersFirst: 'bool',
  },
  'com.apple.dock': {
    autohide: 'bool',
    'autohide-delay': 'float',
    'autohide-time-modifier': 'float',
    'expose-group-apps': 'bool',
    'mru-spaces': 'bool',
    'show-recents': 'bool',
    largesize: 'float',
    magnification: 'bool',
    tilesize: 'float',
  },
  'com.apple.screencapture': {
    'disable-shadow': 'bool',
    'include-date': 'bool',
    location: 'string',
    'show-thumbnail': 'bool',
    type: 'string',
  },
};

const COMPLEX_SCHEMA = {
  'com.apple.HIToolbox': ['AppleEnabledInputSources', 'AppleSelectedInputSources'],
  'com.apple.symbolichotkeys': ['AppleSymbolicHotKeys'],
};

const HOTKEY_IDS = ['60', '61'];

function clone(value) {
  return structuredClone(value);
}

function replaceStrings(value, search, replacement) {
  if (typeof value === 'string') return search ? value.split(search).join(replacement) : value;
  if (Array.isArray(value)) return value.map((item) => replaceStrings(item, search, replacement));
  if (!value || typeof value !== 'object') return value;
  return Object.fromEntries(
    Object.entries(value).map(([key, child]) => [key, replaceStrings(child, search, replacement)]),
  );
}

export function selectPortableSettings(domains, home = '') {
  const selected = {};
  for (const [domain, keys] of Object.entries(SCALAR_SCHEMA)) {
    const source = domains[domain] ?? {};
    const output = {};
    for (const key of Object.keys(keys)) {
      if (Object.hasOwn(source, key)) output[key] = replaceStrings(source[key], home, HOME_MARKER);
    }
    if (Object.keys(output).length > 0) selected[domain] = output;
  }

  const inputSourceDomain = domains['com.apple.HIToolbox'] ?? {};
  const inputSourceOutput = selected['com.apple.HIToolbox'] ?? {};
  for (const key of COMPLEX_SCHEMA['com.apple.HIToolbox']) {
    if (Object.hasOwn(inputSourceDomain, key)) {
      inputSourceOutput[key] = replaceStrings(inputSourceDomain[key], home, HOME_MARKER);
    }
  }
  if (Object.keys(inputSourceOutput).length > 0) selected['com.apple.HIToolbox'] = inputSourceOutput;

  const hotkeys = domains['com.apple.symbolichotkeys']?.AppleSymbolicHotKeys ?? {};
  const portableHotkeys = {};
  for (const id of HOTKEY_IDS) {
    if (Object.hasOwn(hotkeys, id)) portableHotkeys[id] = clone(hotkeys[id]);
  }
  if (Object.keys(portableHotkeys).length > 0) {
    selected['com.apple.symbolichotkeys'] = { AppleSymbolicHotKeys: portableHotkeys };
  }

  return { version: 1, domains: selected };
}

export function buildRestoreOperations(snapshot, home = '') {
  const operations = [];
  for (const [domain, values] of Object.entries(snapshot.domains ?? {})) {
    const scalarTypes = SCALAR_SCHEMA[domain] ?? {};
    for (const [key, value] of Object.entries(values)) {
      if (Object.hasOwn(scalarTypes, key)) {
        operations.push({
          kind: 'scalar',
          domain,
          key,
          type: scalarTypes[key],
          value: replaceStrings(value, HOME_MARKER, home),
        });
      } else if ((COMPLEX_SCHEMA[domain] ?? []).includes(key)) {
        operations.push({
          kind: 'complex',
          domain,
          key,
          value: replaceStrings(value, HOME_MARKER, home),
        });
      }
    }
  }
  return operations;
}

export function mergeComplexDomain(domain, current, portable) {
  const output = clone(current ?? {});
  if (domain === 'com.apple.HIToolbox') {
    for (const [key, value] of Object.entries(portable ?? {})) {
      if (
        (key === 'AppleEnabledInputSources' || key === 'AppleSelectedInputSources') &&
        Array.isArray(value)
      ) {
        const merged = Array.isArray(output[key]) ? clone(output[key]) : [];
        const known = new Set(merged.map(inputSourceIdentity));
        for (const source of value) {
          const identity = inputSourceIdentity(source);
          if (!known.has(identity)) {
            merged.push(clone(source));
            known.add(identity);
          }
        }
        output[key] = merged;
      } else {
        output[key] = clone(value);
      }
    }
    return output;
  }
  if (domain === 'com.apple.symbolichotkeys') {
    output.AppleSymbolicHotKeys = {
      ...(output.AppleSymbolicHotKeys ?? {}),
      ...(clone(portable.AppleSymbolicHotKeys) ?? {}),
    };
    return output;
  }
  return { ...output, ...clone(portable) };
}

function inputSourceIdentity(source) {
  if (!source || typeof source !== 'object') return JSON.stringify(canonical(source));
  if (source['Input Mode']) return `mode:${source['Input Mode']}`;
  if (source['KeyboardLayout ID'] !== undefined) {
    return `layout:${String(source['KeyboardLayout ID'])}`;
  }
  if (source['Bundle ID']) {
    return `bundle:${source['Bundle ID']}:${source.InputSourceKind ?? ''}`;
  }
  return JSON.stringify(canonical(source));
}

function run(command, args, options = {}) {
  const result = spawnSync(command, args, { encoding: 'utf8', ...options });
  if (result.status !== 0 && !options.allowFailure) {
    const details = (result.stderr || result.stdout || '').trim();
    throw new Error(`${command} ${args.join(' ')} failed${details ? `: ${details}` : ''}`);
  }
  return result;
}

function defaultsDomain(domain) {
  return domain === 'NSGlobalDomain' ? '-g' : domain;
}

function parseScalar(raw, type) {
  const value = raw.trim();
  if (type === 'bool') return value === '1' || value.toLowerCase() === 'true';
  if (type === 'int') return Number.parseInt(value, 10);
  if (type === 'float') return Number.parseFloat(value);
  return value;
}

function readScalar(domain, key, type) {
  const result = run('defaults', ['read', defaultsDomain(domain), key], { allowFailure: true });
  if (result.status !== 0) return undefined;
  const value = parseScalar(result.stdout, type);
  return Number.isNaN(value) ? undefined : value;
}

function extractedPlistValue(domain, keyPath, temporaryDirectory) {
  const domainPlist = path.join(temporaryDirectory, `${domain.replaceAll('/', '_')}.plist`);
  const valuePlist = path.join(
    temporaryDirectory,
    `${domain.replaceAll('/', '_')}-${keyPath.replaceAll('.', '_')}.plist`,
  );
  const valueJson = `${valuePlist}.json`;
  const exported = run('defaults', ['export', domain, domainPlist], { allowFailure: true });
  if (exported.status !== 0) return undefined;
  const extracted = run('plutil', ['-extract', keyPath, 'xml1', '-o', valuePlist, domainPlist], {
    allowFailure: true,
  });
  if (extracted.status !== 0) return undefined;
  run('plutil', ['-convert', 'json', '-o', valueJson, valuePlist]);
  return JSON.parse(fs.readFileSync(valueJson, 'utf8'));
}

export function capturePortableSettings(home = os.homedir()) {
  const domains = {};
  for (const [domain, keys] of Object.entries(SCALAR_SCHEMA)) {
    const values = {};
    for (const [key, type] of Object.entries(keys)) {
      const value = readScalar(domain, key, type);
      if (value !== undefined) values[key] = value;
    }
    if (Object.keys(values).length > 0) domains[domain] = values;
  }

  const temporaryDirectory = fs.mkdtempSync(path.join(os.tmpdir(), 'macos-settings-'));
  try {
    const hitoolbox = domains['com.apple.HIToolbox'] ?? {};
    for (const key of COMPLEX_SCHEMA['com.apple.HIToolbox']) {
      const value = extractedPlistValue('com.apple.HIToolbox', key, temporaryDirectory);
      if (value !== undefined) hitoolbox[key] = value;
    }
    if (Object.keys(hitoolbox).length > 0) domains['com.apple.HIToolbox'] = hitoolbox;

    const hotkeys = {};
    for (const id of HOTKEY_IDS) {
      const value = extractedPlistValue(
        'com.apple.symbolichotkeys',
        `AppleSymbolicHotKeys.${id}`,
        temporaryDirectory,
      );
      if (value !== undefined) hotkeys[id] = value;
    }
    if (Object.keys(hotkeys).length > 0) {
      domains['com.apple.symbolichotkeys'] = { AppleSymbolicHotKeys: hotkeys };
    }
  } finally {
    fs.rmSync(temporaryDirectory, { recursive: true, force: true });
  }
  return selectPortableSettings(domains, home);
}

function writeScalar(operation) {
  const flags = { bool: '-bool', int: '-int', float: '-float', string: '-string' };
  run('defaults', [
    'write',
    defaultsDomain(operation.domain),
    operation.key,
    flags[operation.type],
    String(operation.value),
  ]);
}

function exportDomain(domain, temporaryDirectory) {
  const safeDomain = domain.replaceAll('/', '_');
  const domainPlist = path.join(temporaryDirectory, `${safeDomain}.plist`);
  const exported = run('defaults', ['export', domain, domainPlist], { allowFailure: true });
  if (exported.status !== 0) run('plutil', ['-create', 'xml1', domainPlist]);
  return domainPlist;
}

function replaceOrInsertJson(plist, keyPath, value) {
  const json = JSON.stringify(value);
  const replaced = run('plutil', ['-replace', keyPath, '-json', json, plist], {
    allowFailure: true,
  });
  if (replaced.status !== 0) run('plutil', ['-insert', keyPath, '-json', json, plist]);
}

function extractJsonValue(plist, keyPath, temporaryDirectory) {
  const safeName = `${path.basename(plist)}-${keyPath}`.replaceAll(/[^a-zA-Z0-9._-]/g, '_');
  const valuePlist = path.join(temporaryDirectory, `${safeName}.plist`);
  const valueJson = path.join(temporaryDirectory, `${safeName}.json`);
  const extracted = run('plutil', ['-extract', keyPath, 'xml1', '-o', valuePlist, plist], {
    allowFailure: true,
  });
  if (extracted.status !== 0) return undefined;
  run('plutil', ['-convert', 'json', '-o', valueJson, valuePlist]);
  return JSON.parse(fs.readFileSync(valueJson, 'utf8'));
}

function patchComplexDomain(domain, operations, temporaryDirectory) {
  const domainPlist = exportDomain(domain, temporaryDirectory);
  for (const operation of operations) {
    if (domain === 'com.apple.symbolichotkeys' && operation.key === 'AppleSymbolicHotKeys') {
      const currentHotkeys =
        extractJsonValue(domainPlist, operation.key, temporaryDirectory) ?? {};
      replaceOrInsertJson(domainPlist, operation.key, {
        ...currentHotkeys,
        ...operation.value,
      });
    } else if (
      domain === 'com.apple.HIToolbox' &&
      (operation.key === 'AppleEnabledInputSources' ||
        operation.key === 'AppleSelectedInputSources')
    ) {
      const currentValue = extractJsonValue(domainPlist, operation.key, temporaryDirectory) ?? [];
      const merged = mergeComplexDomain(
        domain,
        { [operation.key]: currentValue },
        { [operation.key]: operation.value },
      );
      replaceOrInsertJson(domainPlist, operation.key, merged[operation.key]);
    } else {
      replaceOrInsertJson(domainPlist, operation.key, operation.value);
    }
  }
  run('defaults', ['import', domain, domainPlist]);
}

function writeComplexOperations(operations) {
  const complexOperations = operations.filter((operation) => operation.kind === 'complex');
  if (complexOperations.length === 0) return;

  const operationsByDomain = new Map();
  for (const operation of complexOperations) {
    const values = operationsByDomain.get(operation.domain) ?? {};
    values[operation.key] = clone(operation.value);
    operationsByDomain.set(operation.domain, values);
  }

  const temporaryDirectory = fs.mkdtempSync(path.join(os.tmpdir(), 'macos-settings-restore-'));
  try {
    for (const [domain, values] of operationsByDomain) {
      const domainOperations = Object.entries(values).map(([key, value]) => ({ key, value }));
      patchComplexDomain(domain, domainOperations, temporaryDirectory);
    }
  } finally {
    fs.rmSync(temporaryDirectory, { recursive: true, force: true });
  }
}

export function restorePortableSettings(snapshot, home = os.homedir()) {
  if (snapshot.version !== 1) throw new Error(`Unsupported settings snapshot version: ${snapshot.version}`);
  const operations = buildRestoreOperations(snapshot, home);
  for (const operation of operations.filter((item) => item.kind === 'scalar')) writeScalar(operation);
  writeComplexOperations(operations);
  const screenshotLocation = operations.find(
    (operation) => operation.domain === 'com.apple.screencapture' && operation.key === 'location',
  );
  if (screenshotLocation) fs.mkdirSync(screenshotLocation.value, { recursive: true });
}

function canonical(value) {
  if (Array.isArray(value)) return value.map(canonical);
  if (!value || typeof value !== 'object') return value;
  return Object.fromEntries(Object.keys(value).sort().map((key) => [key, canonical(value[key])]));
}

function comparableSetting(domain, key, value) {
  const normalized = canonical(value);
  if (
    domain === 'com.apple.HIToolbox' &&
    key === 'AppleEnabledInputSources' &&
    Array.isArray(normalized)
  ) {
    return [...normalized].sort((left, right) =>
      JSON.stringify(left).localeCompare(JSON.stringify(right)),
    );
  }
  return normalized;
}

function portableSettingMatches(domain, key, expected, current) {
  if (
    domain === 'com.apple.HIToolbox' &&
    (key === 'AppleEnabledInputSources' || key === 'AppleSelectedInputSources') &&
    Array.isArray(expected) &&
    Array.isArray(current)
  ) {
    const currentIdentities = new Set(current.map(inputSourceIdentity));
    return expected.every((source) => currentIdentities.has(inputSourceIdentity(source)));
  }
  return (
    JSON.stringify(comparableSetting(domain, key, expected)) ===
    JSON.stringify(comparableSetting(domain, key, current))
  );
}

export function diffPortableSettings(expected, current) {
  const differences = [];
  const expectedDomains = expected.domains ?? {};
  const currentDomains = current.domains ?? {};
  for (const [domain, values] of Object.entries(expectedDomains)) {
    for (const [key, expectedValue] of Object.entries(values)) {
      const currentValue = currentDomains[domain]?.[key];
      if (!portableSettingMatches(domain, key, expectedValue, currentValue)) {
        differences.push(`${domain}.${key}`);
      }
    }
  }
  return differences;
}

function readSnapshot(file) {
  return JSON.parse(fs.readFileSync(file, 'utf8'));
}

function writeSnapshot(file, snapshot) {
  fs.mkdirSync(path.dirname(file), { recursive: true });
  fs.writeFileSync(file, `${JSON.stringify(snapshot, null, 2)}\n`);
}

function usage() {
  console.error(`Usage:
  macos-settings.mjs backup SNAPSHOT [HOME]
  macos-settings.mjs restore SNAPSHOT [HOME]
  macos-settings.mjs status SNAPSHOT [HOME]`);
}

function main(argv) {
  const [command, snapshotFile, home = os.homedir()] = argv;
  if (!command || !snapshotFile) {
    usage();
    process.exitCode = 2;
    return;
  }
  if (command === 'backup') {
    writeSnapshot(snapshotFile, capturePortableSettings(home));
    return;
  }
  if (command === 'restore') {
    restorePortableSettings(readSnapshot(snapshotFile), home);
    return;
  }
  if (command === 'status') {
    const differences = diffPortableSettings(readSnapshot(snapshotFile), capturePortableSettings(home));
    if (differences.length === 0) {
      console.log('[synced] macOS settings');
      return;
    }
    for (const difference of differences) console.log(`[drift] ${difference}`);
    process.exitCode = 1;
    return;
  }
  usage();
  process.exitCode = 2;
}

const isMain =
  process.argv[1] &&
  fs.realpathSync(fileURLToPath(import.meta.url)) === fs.realpathSync(path.resolve(process.argv[1]));
if (isMain) main(process.argv.slice(2));
