import assert from 'node:assert/strict';
import { execFileSync } from 'node:child_process';
import { join } from 'node:path';
import { test } from 'node:test';
import { Evaluator, Lexer, Parser, data } from '@actions/expressions';

const workflowDir = process.argv[2];

function readJobs(file) {
  return JSON.parse(execFileSync('yq', ['-o=json', 'explode(.) | .jobs', join(workflowDir, file)], {
    encoding: 'utf8',
  }));
}

const workflow = readJobs('workflow.yaml');
const selfTest = readJobs('autodoc.yaml');

function contextData(value) {
  if (value === null) return new data.Null();
  if (typeof value === 'string') return new data.StringData(value);
  if (typeof value === 'boolean') return new data.BooleanData(value);
  return new data.Dictionary(...Object.entries(value).map(([key, val]) => ({
    key, value: contextData(val),
  })));
}

function evaluate(source, context) {
  const text = source.trim();
  const expression = text.startsWith('${{') ? text.slice(3, -2) : text;
  // Evaluate with GitHub's expression library, including its serialization
  // of the decoded result so that strings, lists and objects stay distinct.
  const tokens = new Lexer(`toJSON(${expression})`).lex().tokens;
  const parsed = new Parser(tokens, Object.keys(context), []).parse();
  const result = new Evaluator(parsed, contextData(context)).evaluate();
  return JSON.parse(result.coerceString());
}

for (const job of ['autodoc', 'push']) {
  test(`${job}: runner labels and JSON forms`, () => {
    for (const [input, expected] of [
      ['ubuntu-latest', 'ubuntu-latest'],
      ['"ubuntu-latest"', 'ubuntu-latest'],
      ['["self-hosted", "Linux"]', ['self-hosted', 'Linux']],
      ['{"group": "g"}', { group: 'g' }],
      [' \t\r\n ["self-hosted", "Linux"]\r\n ', ['self-hosted', 'Linux']],
      ['\t{"group": "g"} ', { group: 'g' }],
      ['\n"ubuntu-latest"\t', 'ubuntu-latest'],
      ['\r"ubuntu-latest"', 'ubuntu-latest'],
      ['""', ''],
    ]) {
      assert.deepEqual(evaluate(workflow[job]['runs-on'], { inputs: { 'runs-on': input } }),
        expected, `runs-on: ${JSON.stringify(input)}`);
    }
  });
}

const repo = 'example/autodoc';
const pullRequest = full_name => ({ pull_request: { head: { repo: { full_name } } } });

test('PRs require a verified same-repository head; non-PR dispatch still runs', () => {
  for (const [event_name, event, repository, allowed] of [
    ['pull_request', pullRequest(repo), repo, true],
    ['pull_request', pullRequest('example/fork'), repo, false],
    ['pull_request', { pull_request: { head: { repo: null } } }, repo, false],
    ['pull_request', {}, repo, false],
    ['pull_request_target', pullRequest(repo), repo, true],
    ['pull_request_target', pullRequest('example/fork'), repo, false],
    ['pull_request_target', { pull_request: { head: {} } }, repo, false],
    ['pull_request_target', {}, repo, false],
    ['pull_request_target', pullRequest(''), '', false],
    ['pull_request_review', pullRequest('example/fork'), repo, false],
    ['workflow_dispatch', {}, repo, true],
    ['push', {}, repo, true],
  ]) {
    const github = { event_name, event, repository };
    assert.equal(evaluate(workflow.autodoc.if, { github }), allowed, JSON.stringify(github));
  }
});

test('push requires the guarded autodoc job to succeed', () => {
  assert.ok([workflow.push.needs].flat().includes('autodoc'), 'push must depend on autodoc');
  for (const result of ['success', 'skipped', 'failure', 'cancelled']) {
    assert.equal(evaluate(workflow.push.if, { needs: { autodoc: { result } } }),
      result === 'success', `autodoc result: ${result}`);
  }
});

test('repository self-test remains opt-in and skips draft PRs', () => {
  for (const [flag, draft, allowed] of [['true', false, true], ['true', true, false], ['', false, false]]) {
    const vars = { AUTODOC_SELFTEST: flag };
    const github = { event_name: 'pull_request', event: { pull_request: { draft } } };
    assert.equal(evaluate(selfTest.autodoc.if, { vars, github }), allowed, JSON.stringify({ flag, draft }));
  }
});
