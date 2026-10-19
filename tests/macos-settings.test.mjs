import assert from 'node:assert/strict';
import fs from 'node:fs';
import os from 'node:os';
import path from 'node:path';
import { spawnSync } from 'node:child_process';
import test from 'node:test';

import {
  HOME_MARKER,
  buildRestoreOperations,
  diffPortableSettings,
  mergeComplexDomain,
  restorePortableSettings,
  selectPortableSettings,
} from '../scripts/macos-settings.mjs';

function syntheticDomains() {
  return {
    NSGlobalDomain: {
      AppleInterfaceStyle: 'Dark',
      InitialKeyRepeat: 15,
      KeyRepeat: 2,
      NSAutomaticCapitalizationEnabled: true,
      NSWindowFrame: 'machine-local-window-state',
      'com.apple.swipescrolldirection': true,
      'com.apple.trackpad.scaling': 1,
    },
    'com.apple.HIToolbox': {
      AppleEnabledInputSources: [
        {
          InputSourceKind: 'Keyboard Layout',
          'KeyboardLayout ID': 252,
          'KeyboardLayout Name': 'ABC',
        },
        {
          'Bundle ID': 'com.apple.inputmethod.SCIM',
          'Input Mode': 'com.apple.inputmethod.SCIM.ITABC',
          InputSourceKind: 'Input Mode',
        },
      ],
      AppleSelectedInputSources: [
        {
          InputSourceKind: 'Keyboard Layout',
          'KeyboardLayout ID': 252,
          'KeyboardLayout Name': 'ABC',
        },
        {
          'Bundle ID': 'com.apple.inputmethod.SCIM',
          'Input Mode': 'com.apple.inputmethod.SCIM.ITABC',
          InputSourceKind: 'Input Mode',
        },
      ],
      AppleInputSourceHistory: ['machine-local-history'],
    },
    'com.apple.symbolichotkeys': {
      AppleSymbolicHotKeys: {
        60: { enabled: true, value: { parameters: [32, 49, 1048576], type: 'standard' } },
        61: { enabled: true, value: { parameters: [32, 49, 786432], type: 'standard' } },
        64: { enabled: true, value: { parameters: [65535, 49, 1048576], type: 'standard' } },
      },
    },
    'com.apple.AppleMultitouchTrackpad': {
      Clicking: true,
      TrackpadThreeFingerDrag: true,
      TrackpadThreeFingerHorizSwipeGesture: 0,
      TrackpadThreeFingerVertSwipeGesture: 0,
      TrackpadFourFingerHorizSwipeGesture: 2,
      TrackpadFourFingerVertSwipeGesture: 2,
      DeviceID: 999,
    },
    'com.apple.finder': {
      FXPreferredViewStyle: 'Nlsv',
      ShowPathbar: true,
      LastTrashState: 'machine-local',
    },
    'com.apple.dock': {
      autohide: true,
      'show-recents': false,
      'persistent-apps': ['machine-specific-app-list'],
    },
    'com.apple.screencapture': {
      location: '/Users/tester/Pictures/Screenshots',
      type: 'png',
      'last-selection-display': 1,
    },
  };
}

test('portable snapshot contains only allowlisted settings', () => {
  const snapshot = selectPortableSettings(syntheticDomains(), '/Users/tester');

  assert.equal(snapshot.version, 1);
  assert.equal(snapshot.domains.NSGlobalDomain.InitialKeyRepeat, 15);
  assert.equal(snapshot.domains.NSGlobalDomain.NSWindowFrame, undefined);
  assert.deepEqual(
    Object.keys(snapshot.domains['com.apple.symbolichotkeys'].AppleSymbolicHotKeys).sort(),
    ['60', '61'],
  );
  assert.equal(
    snapshot.domains['com.apple.AppleMultitouchTrackpad'].TrackpadThreeFingerDrag,
    true,
  );
  assert.equal(snapshot.domains['com.apple.AppleMultitouchTrackpad'].DeviceID, undefined);
  assert.equal(snapshot.domains['com.apple.HIToolbox'].AppleInputSourceHistory, undefined);
  assert.equal(snapshot.domains['com.apple.HIToolbox'].AppleCurrentKeyboardLayoutInputSourceID, undefined);
  assert.deepEqual(
    snapshot.domains['com.apple.HIToolbox'].AppleSelectedInputSources,
    syntheticDomains()['com.apple.HIToolbox'].AppleSelectedInputSources,
  );
  assert.equal(snapshot.domains['com.apple.dock']['persistent-apps'], undefined);
  assert.equal(snapshot.domains['com.apple.screencapture'].location, `${HOME_MARKER}/Pictures/Screenshots`);
});

test('restore operations retain declared types and exclude unrelated keys', () => {
  const snapshot = selectPortableSettings(syntheticDomains(), '/Users/tester');
  const operations = buildRestoreOperations(snapshot, '/Users/new-user');

  const repeat = operations.find(
    (operation) => operation.domain === 'NSGlobalDomain' && operation.key === 'KeyRepeat',
  );
  assert.deepEqual(repeat, {
    kind: 'scalar',
    domain: 'NSGlobalDomain',
    key: 'KeyRepeat',
    type: 'int',
    value: 2,
  });

  const screenshot = operations.find(
    (operation) => operation.domain === 'com.apple.screencapture' && operation.key === 'location',
  );
  assert.equal(screenshot.value, '/Users/new-user/Pictures/Screenshots');
  assert.equal(operations.some((operation) => operation.key === 'persistent-apps'), false);
  assert.equal(operations.some((operation) => operation.key === 'NSWindowFrame'), false);
});

test('complex restore merges shortcut IDs without deleting unrelated shortcuts', () => {
  const current = {
    AppleSymbolicHotKeys: {
      60: { enabled: false },
      64: { enabled: true, value: { parameters: [1, 2, 3] } },
    },
    OtherDomainState: 'keep-me',
  };
  const portable = {
    AppleSymbolicHotKeys: {
      60: { enabled: true, value: { parameters: [32, 49, 1048576], type: 'standard' } },
      61: { enabled: true, value: { parameters: [32, 49, 786432], type: 'standard' } },
    },
  };

  assert.deepEqual(mergeComplexDomain('com.apple.symbolichotkeys', current, portable), {
    AppleSymbolicHotKeys: {
      60: { enabled: true, value: { parameters: [32, 49, 1048576], type: 'standard' } },
      61: { enabled: true, value: { parameters: [32, 49, 786432], type: 'standard' } },
      64: { enabled: true, value: { parameters: [1, 2, 3] } },
    },
    OtherDomainState: 'keep-me',
  });
});

test('input source restore adds portable sources without deleting local sources', () => {
  const local = {
    AppleEnabledInputSources: [
      {
        InputSourceKind: 'Keyboard Layout',
        'KeyboardLayout Name': 'U.S.',
        'KeyboardLayout ID': 0,
      },
    ],
    AppleSelectedInputSources: [
      {
        InputSourceKind: 'Keyboard Layout',
        'KeyboardLayout Name': 'U.S.',
        'KeyboardLayout ID': 0,
      },
    ],
    AppleInputSourceHistory: ['keep-me'],
  };
  const portable = {
    AppleEnabledInputSources: syntheticDomains()['com.apple.HIToolbox'].AppleEnabledInputSources,
    AppleSelectedInputSources: syntheticDomains()['com.apple.HIToolbox'].AppleSelectedInputSources,
  };

  const merged = mergeComplexDomain('com.apple.HIToolbox', local, portable);
  assert.equal(merged.AppleEnabledInputSources.length, 3);
  assert.equal(merged.AppleSelectedInputSources.length, 3);
  assert.equal(merged.AppleEnabledInputSources[0]['KeyboardLayout Name'], 'U.S.');
  assert.equal(merged.AppleSelectedInputSources[0]['KeyboardLayout Name'], 'U.S.');
  assert.deepEqual(merged.AppleInputSourceHistory, ['keep-me']);
});

test('input source order and local extras do not cause drift, but a missing source does', () => {
  const expected = selectPortableSettings(syntheticDomains(), '/Users/tester');
  const current = structuredClone(expected);
  const hitoolbox = current.domains['com.apple.HIToolbox'];
  hitoolbox.AppleEnabledInputSources = hitoolbox.AppleEnabledInputSources.toReversed();
  hitoolbox.AppleSelectedInputSources = hitoolbox.AppleSelectedInputSources.toReversed();
  const localEnglish = {
    InputSourceKind: 'Keyboard Layout',
    'KeyboardLayout Name': 'U.S.',
    'KeyboardLayout ID': 0,
  };
  hitoolbox.AppleEnabledInputSources.push(localEnglish);
  hitoolbox.AppleSelectedInputSources.push(localEnglish);

  assert.deepEqual(diffPortableSettings(expected, current), []);

  hitoolbox.AppleSelectedInputSources = hitoolbox.AppleSelectedInputSources.filter(
    (source) => source['KeyboardLayout Name'] !== 'ABC',
  );
  assert.deepEqual(diffPortableSettings(expected, current), [
    'com.apple.HIToolbox.AppleSelectedInputSources',
  ]);
});

test(
  'complex restore imports typed plists and preserves unrelated domain state',
  { skip: process.platform !== 'darwin' },
  () => {
    const temporaryDirectory = fs.mkdtempSync(path.join(os.tmpdir(), 'macos-settings-test-'));
    const fakeBin = path.join(temporaryDirectory, 'bin');
    const currentPlist = path.join(temporaryDirectory, 'current.json');
    const importedDirectory = path.join(temporaryDirectory, 'imported');
    const originalEnvironment = {
      PATH: process.env.PATH,
      FAKE_DEFAULTS_CURRENT: process.env.FAKE_DEFAULTS_CURRENT,
      FAKE_DEFAULTS_IMPORTED_DIR: process.env.FAKE_DEFAULTS_IMPORTED_DIR,
    };

    try {
      fs.mkdirSync(fakeBin);
      fs.mkdirSync(importedDirectory);
      fs.writeFileSync(
        currentPlist,
        `${JSON.stringify({
          AppleEnabledInputSources: [
            {
              InputSourceKind: 'Keyboard Layout',
              'KeyboardLayout Name': 'U.S.',
              'KeyboardLayout ID': 0,
            },
          ],
          AppleSelectedInputSources: [
            {
              InputSourceKind: 'Keyboard Layout',
              'KeyboardLayout Name': 'U.S.',
              'KeyboardLayout ID': 0,
            },
          ],
          AppleInputSourceHistory: ['keep-me'],
          AppleSymbolicHotKeys: {
            64: { enabled: true, value: { parameters: [1, 2, 3], type: 'standard' } },
          },
          OtherDomainState: true,
        })}\n`,
      );
      const converted = spawnSync('/usr/bin/plutil', ['-convert', 'xml1', currentPlist], {
        encoding: 'utf8',
      });
      assert.equal(converted.status, 0, converted.stderr);
      const insertedData = spawnSync(
        '/usr/bin/plutil',
        ['-insert', 'BinaryState', '-data', 'AQID', currentPlist],
        { encoding: 'utf8' },
      );
      assert.equal(insertedData.status, 0, insertedData.stderr);

      const fakeDefaults = path.join(fakeBin, 'defaults');
      fs.writeFileSync(
        fakeDefaults,
        `#!/bin/sh
case "$1" in
  export) cp "$FAKE_DEFAULTS_CURRENT" "$3" ;;
  import) cp "$3" "$FAKE_DEFAULTS_IMPORTED_DIR/$2.plist" ;;
  write) exit 0 ;;
  *) exit 2 ;;
esac
`,
      );
      fs.chmodSync(fakeDefaults, 0o755);
      fs.symlinkSync('/usr/bin/plutil', path.join(fakeBin, 'plutil'));
      process.env.PATH = `${fakeBin}:${originalEnvironment.PATH}`;
      process.env.FAKE_DEFAULTS_CURRENT = currentPlist;
      process.env.FAKE_DEFAULTS_IMPORTED_DIR = importedDirectory;

      restorePortableSettings(
        {
          version: 1,
          domains: {
            'com.apple.HIToolbox': {
              AppleEnabledInputSources: [
                {
                  InputSourceKind: 'Keyboard Layout',
                  'KeyboardLayout Name': 'ABC',
                  'KeyboardLayout ID': 252,
                },
              ],
              AppleSelectedInputSources: [
                {
                  InputSourceKind: 'Keyboard Layout',
                  'KeyboardLayout Name': 'ABC',
                  'KeyboardLayout ID': 252,
                },
              ],
            },
            'com.apple.symbolichotkeys': {
              AppleSymbolicHotKeys: {
                60: {
                  enabled: true,
                  value: { parameters: [32, 49, 1048576], type: 'standard' },
                },
              },
            },
          },
        },
        '/Users/tester',
      );

      const readImportedValue = (domain, keyPath) => {
        const extractedPlist = path.join(
          temporaryDirectory,
          `${domain}-${keyPath}-extracted.plist`,
        );
        const extracted = spawnSync(
          '/usr/bin/plutil',
          [
            '-extract',
            keyPath,
            'xml1',
            '-o',
            extractedPlist,
            path.join(importedDirectory, `${domain}.plist`),
          ],
          { encoding: 'utf8' },
        );
        assert.equal(extracted.status, 0, extracted.stderr || extracted.stdout);
        const result = spawnSync(
          '/usr/bin/plutil',
          ['-convert', 'json', '-o', '-', extractedPlist],
          { encoding: 'utf8' },
        );
        assert.equal(result.status, 0, result.stderr || result.stdout);
        return JSON.parse(result.stdout);
      };
      const inputSources = readImportedValue(
        'com.apple.HIToolbox',
        'AppleEnabledInputSources',
      );
      const inputSourceHistory = readImportedValue(
        'com.apple.HIToolbox',
        'AppleInputSourceHistory',
      );
      const selectedInputSources = readImportedValue(
        'com.apple.HIToolbox',
        'AppleSelectedInputSources',
      );
      const hotkeys = readImportedValue(
        'com.apple.symbolichotkeys',
        'AppleSymbolicHotKeys',
      );
      const symbolHotkeysPlist = path.join(
        importedDirectory,
        'com.apple.symbolichotkeys.plist',
      );
      const otherDomainState = spawnSync(
        '/usr/bin/plutil',
        ['-extract', 'OtherDomainState', 'raw', symbolHotkeysPlist],
        { encoding: 'utf8' },
      );
      const binaryStateType = spawnSync(
        '/usr/bin/plutil',
        [
          '-type',
          'BinaryState',
          path.join(importedDirectory, 'com.apple.HIToolbox.plist'),
        ],
        { encoding: 'utf8' },
      );

      assert.deepEqual(
        inputSources.map((source) => source['KeyboardLayout Name']),
        ['U.S.', 'ABC'],
      );
      assert.deepEqual(
        selectedInputSources.map((source) => source['KeyboardLayout Name']),
        ['U.S.', 'ABC'],
      );
      assert.deepEqual(inputSourceHistory, ['keep-me']);
      assert.equal(hotkeys['60'].enabled, true);
      assert.deepEqual(hotkeys['60'].value.parameters, [32, 49, 1048576]);
      assert.equal(hotkeys['64'].enabled, true);
      assert.equal(otherDomainState.status, 0, otherDomainState.stderr || otherDomainState.stdout);
      assert.equal(otherDomainState.stdout.trim(), 'true');
      assert.equal(binaryStateType.status, 0, binaryStateType.stderr);
      assert.equal(binaryStateType.stdout.trim(), 'data');
    } finally {
      for (const [key, value] of Object.entries(originalEnvironment)) {
        if (value === undefined) delete process.env[key];
        else process.env[key] = value;
      }
      fs.rmSync(temporaryDirectory, { recursive: true, force: true });
    }
  },
);
