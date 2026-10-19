import assert from 'node:assert/strict';
import test from 'node:test';

import {
  HOME_MARKER,
  SECRET_MARKER,
  mergeJsonSecrets,
  renderShell,
  renderToml,
  sanitizeJsonSecrets,
  sanitizeShell,
  sanitizeTextHome,
  sanitizeToml,
  selectClaudeDesktopPortable,
  renderTextHome,
} from '../scripts/config-sanitizer.mjs';

test('JSON backup replaces secret values and the home directory', () => {
  const input = {
    env: {
      ANTHROPIC_AUTH_TOKEN: 'test-secret-value',
      ANTHROPIC_BASE_URL: 'https://example.invalid',
    },
    command: '/Users/tester/bin/tool',
  };

  assert.deepEqual(sanitizeJsonSecrets(input, '/Users/tester'), {
    env: {
      ANTHROPIC_AUTH_TOKEN: SECRET_MARKER,
      ANTHROPIC_BASE_URL: 'https://example.invalid',
    },
    command: `${HOME_MARKER}/bin/tool`,
  });
});

test('JSON restore keeps the local secret and applies portable settings', () => {
  const template = {
    env: {
      ANTHROPIC_AUTH_TOKEN: SECRET_MARKER,
      ANTHROPIC_BASE_URL: 'https://new.invalid',
    },
    command: `${HOME_MARKER}/bin/tool`,
    model: 'portable-model',
  };
  const local = {
    env: {
      ANTHROPIC_AUTH_TOKEN: 'local-only-secret',
      ANTHROPIC_BASE_URL: 'https://old.invalid',
    },
    model: 'old-model',
  };

  assert.deepEqual(mergeJsonSecrets(template, local, '/Users/new-user'), {
    env: {
      ANTHROPIC_AUTH_TOKEN: 'local-only-secret',
      ANTHROPIC_BASE_URL: 'https://new.invalid',
    },
    command: '/Users/new-user/bin/tool',
    model: 'portable-model',
  });
});

test('TOML backup and restore match secrets by section and key', () => {
  const source = [
    'model = "portable"',
    'notify = ["/Users/tester/bin/notify"]',
    '',
    '[model_providers.gateway.http_headers]',
    'X-Llmgw-Authorization = "Bearer test-secret"',
    'X-Mode = "portable"',
    '',
  ].join('\n');

  const snapshot = sanitizeToml(source, '/Users/tester');
  assert.match(snapshot, new RegExp(`X-Llmgw-Authorization = "${SECRET_MARKER}"`));
  assert.match(snapshot, new RegExp(HOME_MARKER));
  assert.doesNotMatch(snapshot, /test-secret/);

  const local = [
    'model = "old"',
    '',
    '[model_providers.gateway.http_headers]',
    'X-Llmgw-Authorization = "Bearer local-secret"',
    'X-Mode = "old"',
    '',
  ].join('\n');

  const rendered = renderToml(snapshot, local, '/Users/new-user');
  assert.match(rendered, /model = "portable"/);
  assert.match(rendered, /X-Llmgw-Authorization = "Bearer local-secret"/);
  assert.match(rendered, /notify = \["\/Users\/new-user\/bin\/notify"\]/);
  assert.doesNotMatch(rendered, new RegExp(SECRET_MARKER));
});

test('TOML restore omits a secret assignment that has no local value', () => {
  const template = [
    '[headers]',
    `Authorization = "${SECRET_MARKER}"`,
    'Mode = "portable"',
    '',
  ].join('\n');

  const rendered = renderToml(template, '', '/Users/new-user');
  assert.doesNotMatch(rendered, /Authorization/);
  assert.match(rendered, /Mode = "portable"/);
});

test('TOML backup recognizes API key names that use hyphen separators', () => {
  const source = [
    '[provider.http_headers]',
    'x-relay-api-key = "backup-secret"',
    '',
  ].join('\n');
  const local = [
    '[provider.http_headers]',
    'x-relay-api-key = "local-secret"',
    '',
  ].join('\n');

  const snapshot = sanitizeToml(source);
  assert.match(snapshot, new RegExp(`x-relay-api-key = "${SECRET_MARKER}"`));
  assert.doesNotMatch(snapshot, /backup-secret/);

  const rendered = renderToml(snapshot, local);
  assert.match(rendered, /x-relay-api-key = "local-secret"/);
});

test('TOML backup sanitizes secrets inside inline tables', () => {
  const source = [
    '[model_providers.gateway]',
    'http_headers = { "x-relay-api-key" = "backup-inline-secret", "x-mode" = "portable" }',
    '',
  ].join('\n');
  const local = [
    '[model_providers.gateway]',
    'http_headers = { "x-relay-api-key" = "local-inline-secret", "x-mode" = "local" }',
    '',
  ].join('\n');

  const snapshot = sanitizeToml(source);
  assert.match(snapshot, new RegExp(`"x-relay-api-key" = "${SECRET_MARKER}"`));
  assert.doesNotMatch(snapshot, /backup-inline-secret/);

  const rendered = renderToml(snapshot, local);
  assert.match(rendered, /"x-relay-api-key" = "local-inline-secret"/);
  assert.doesNotMatch(rendered, new RegExp(SECRET_MARKER));
});

test('shell backup sanitizes exported secrets and restore keeps the local value', () => {
  const source = [
    'export EDITOR="nvim"',
    'export RELAY_API_KEY="backup-secret"',
    'export TOOL_PATH="/Users/tester/bin/tool"',
    '',
  ].join('\n');
  const local = [
    'export EDITOR="vim"',
    'export RELAY_API_KEY="local-secret"',
    '',
  ].join('\n');

  const snapshot = sanitizeShell(source, '/Users/tester');
  assert.match(snapshot, new RegExp(`export RELAY_API_KEY="${SECRET_MARKER}"`));
  assert.doesNotMatch(snapshot, /backup-secret/);
  assert.match(snapshot, new RegExp(HOME_MARKER));

  const rendered = renderShell(snapshot, local, '/Users/new-user');
  assert.match(rendered, /export EDITOR="nvim"/);
  assert.match(rendered, /export RELAY_API_KEY="local-secret"/);
  assert.match(rendered, /export TOOL_PATH="\/Users\/new-user\/bin\/tool"/);
});

test('plain text home paths are portable across machines', () => {
  const source = 'prefix_rule(pattern=["/Users/tester/bin/tool"], decision="allow")\n';
  const snapshot = sanitizeTextHome(source, '/Users/tester');
  assert.equal(
    snapshot,
    `prefix_rule(pattern=["${HOME_MARKER}/bin/tool"], decision="allow")\n`,
  );
  assert.equal(
    renderTextHome(snapshot, '/Users/new-user'),
    'prefix_rule(pattern=["/Users/new-user/bin/tool"], decision="allow")\n',
  );
});

test('Claude desktop snapshot keeps portable preferences and sanitizes MCP secrets', () => {
  const source = {
    deploymentMode: 'default',
    coworkUserFilesPath: '/Users/tester/Documents/Claude',
    preferences: {
      menuBarEnabled: true,
      sidebarMode: 'expanded',
      coworkWebSearchEnabled: true,
      localAgentModeTrustedFolders: ['/Users/tester/work'],
      bypassPermissionsOptInByAccount: { account: true },
      epitaxyPrefs: { machine: 'state' },
    },
    mcpServers: {
      demo: {
        command: '/Users/tester/bin/demo-mcp',
        env: { API_KEY: 'mcp-secret' },
      },
    },
    'oauth:tokenCache': 'oauth-secret',
  };

  assert.deepEqual(selectClaudeDesktopPortable(source, '/Users/tester'), {
    deploymentMode: 'default',
    preferences: {
      menuBarEnabled: true,
      sidebarMode: 'expanded',
      coworkWebSearchEnabled: true,
    },
    mcpServers: {
      demo: {
        command: `${HOME_MARKER}/bin/demo-mcp`,
        env: { API_KEY: SECRET_MARKER },
      },
    },
  });
});
