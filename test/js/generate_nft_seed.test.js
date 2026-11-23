const fs = require('fs');
const os = require('os');
const path = require('path');
const {spawnSync} = require('child_process');
const yaml = require('js-yaml');

const repoDir = path.join(__dirname, '../..');
const workflowFile = path.join(repoDir, '.github/workflows/generate-nft-seed.yml');
const workflow = yaml.load(fs.readFileSync(workflowFile, 'utf8'));
const seedIam = fs.readFileSync(
    path.join(repoDir, 'terraform/nft/ecs_task_definition/nft_seed/iam.tf'), 'utf8'
);
const taskArn = 'arn:aws:ecs:eu-west-2:448120078528:task/nft-app/0123456789abcdef0123456789abcdef';
const startedBy = 'nft-123456789-1';

describe('NFT multipart dump upload', () => {
    function runDumpCli(scenario) {
        const scratch = fs.mkdtempSync(path.join(os.tmpdir(), '.nft-dump-cli-'));
        try {
            const bin = path.join(scratch, 'bin');
            fs.mkdirSync(bin);
            fs.writeFileSync(path.join(bin, 'pg_dump'), '#!/bin/sh\nprintf abcdefgh\n[ "$SCENARIO" != dump-failure ]\n', {mode: 0o755});
            fs.writeFileSync(path.join(bin, 'aws'), `#!/usr/bin/env node
const fs = require('fs');
const args = process.argv.slice(2);
const operation = args[1];
const calls = JSON.parse(fs.readFileSync(process.env.TRACE, 'utf8'));
calls.push(operation);
fs.writeFileSync(process.env.TRACE, JSON.stringify(calls));
if (operation === 'put-object' || operation === 'complete-multipart-upload') {
  const flag = operation === 'put-object' ? '--body' : '--multipart-upload';
  const file = args[args.indexOf(flag) + 1].replace(/^file:\\/\\//, '');
  const details = JSON.parse(fs.readFileSync(process.env.DETAILS, 'utf8'));
  details[operation] = {args, body: JSON.parse(fs.readFileSync(file, 'utf8'))};
  fs.writeFileSync(process.env.DETAILS, JSON.stringify(details));
}
if (operation === 'complete-multipart-upload' && process.env.SCENARIO === 'completion-failure') process.exit(1);
const result = {
  'create-multipart-upload': {UploadId: 'upload-id'},
  'upload-part': {ETag: '"part-etag"'},
  'complete-multipart-upload': {VersionId: 'dump-version'},
  'put-object': {VersionId: 'manifest-version'},
}[operation] || {};
process.stdout.write(JSON.stringify(result));
`, {mode: 0o755});
            const trace = path.join(scratch, 'trace.json');
            const details = path.join(scratch, 'details.json');
            fs.writeFileSync(trace, '[]');
            fs.writeFileSync(details, '{}');
            const result = spawnSync('python3', [
                path.join(repoDir, 'terraform/nft/ecs_task_definition/nft_seed/multipart_dump.py'),
            ], {
                cwd: repoDir, encoding: 'utf8',
                env: {...process.env, PATH: `${bin}${path.delimiter}${process.env.PATH}`, TRACE: trace, DETAILS: details,
                    SCENARIO: scenario, NFT_SEED_RUN_ID: '123-2',
                    NFT_SEED_CERTIFICATE_OBJECT_KEY: 'seeding/certificate-references/123-2.png',
                    NFT_SEED_CERTIFICATE_VERSION_ID: 'cert-version'},
            });
            if (result.error) throw result.error;
            return {...result, calls: JSON.parse(fs.readFileSync(trace, 'utf8')),
                details: JSON.parse(fs.readFileSync(details, 'utf8'))};
        } finally {
            fs.rmSync(scratch, {recursive: true, force: true});
        }
    }

    function runUpload(scenario) {
        const script = path.join(repoDir, 'terraform/nft/ecs_task_definition/nft_seed/multipart_dump.py');
        const result = spawnSync('python3', ['-c', `
import importlib.util, io, json, sys
spec = importlib.util.spec_from_file_location('dump', sys.argv[1])
module = importlib.util.module_from_spec(spec)
spec.loader.exec_module(module)
scenario = sys.argv[2]
calls = []
def aws(operation, **kwargs):
    calls.append((operation, kwargs))
    if operation == 'create-multipart-upload':
        return {'UploadId': 'owned-upload'}
    if operation == 'upload-part':
        if scenario == 'part-failure': raise RuntimeError('private error')
        return {'ETag': '"etag-%s"' % kwargs['part_number']}
    if operation == 'complete-multipart-upload':
        if scenario == 'ambiguous-completion': raise RuntimeError('private error')
        return {'VersionId': 'exact-version' if scenario != 'missing-version' else 'null'}
    return {}
payload = b'abcdefgh' if scenario != 'empty' else b''
try:
    result = module.upload_dump(io.BytesIO(payload), aws, lambda: scenario != 'dump-failure', part_size=4)
    print(json.dumps({'result': result, 'calls': calls}))
except Exception:
    print(json.dumps({'result': None, 'calls': calls}))
`, script, scenario], {encoding: 'utf8'});
        if (result.error) throw result.error;
        if (result.status !== 0) throw new Error(result.stderr);
        return JSON.parse(result.stdout);
    }

    it('binds exact multipart completion version, bytes and SHA to the uploaded parts', () => {
        const {result, calls} = runUpload('success');
        expect(result).toEqual({
            version: 'exact-version',
            bytes: 8,
            sha256: '9c56cc51b374c3ba189210d5b6d4bf57790d351c96c47c02190ecf1e430635ab', // pragma: allowlist secret
        });
        expect(calls.map(call => call[0])).toEqual([
            'create-multipart-upload', 'upload-part', 'upload-part', 'complete-multipart-upload',
        ]);
        expect(calls[3][1].parts).toEqual([
            {ETag: '"etag-1"', PartNumber: 1}, {ETag: '"etag-2"', PartNumber: 2},
        ]);
    });

    it.each(['part-failure', 'dump-failure', 'ambiguous-completion', 'missing-version', 'empty'])(
        'never returns a usable identity for %s', scenario => {
            const {result, calls} = runUpload(scenario);
            expect(result).toBeNull();
            if (['part-failure', 'dump-failure', 'empty'].includes(scenario)) {
                expect(calls.some(call => call[0] === 'complete-multipart-upload')).toBe(false);
            }
        }
    );

    it('publishes the certificate and exact dump identity in a run-owned versioned manifest', () => {
        const script = path.join(repoDir, 'terraform/nft/ecs_task_definition/nft_seed/multipart_dump.py');
        const result = spawnSync('python3', ['-c', `
import importlib.util, json, sys
spec = importlib.util.spec_from_file_location('dump', sys.argv[1])
module = importlib.util.module_from_spec(spec)
spec.loader.exec_module(module)
calls = []
def aws(operation, **kwargs):
    calls.append((operation, kwargs))
    return {'VersionId': 'manifest-version'}
dump = {'version': 'dump-version', 'bytes': 8, 'sha256': 'a' * 64}
result = module.publish_manifest(aws, '123-2', 'seeding/certificate-references/123-2.png', 'cert-version', dump)
print(json.dumps({'result': result, 'calls': calls}))
`, script], {encoding: 'utf8'});
        if (result.error) throw result.error;
        if (result.status !== 0) throw new Error(result.stderr);
        const parsed = JSON.parse(result.stdout);
        expect(parsed.result).toEqual({key: 'seed-manifests/123-2.json', version: 'manifest-version'});
        expect(parsed.calls).toEqual([['put-object', expect.objectContaining({
            key: 'seed-manifests/123-2.json',
            manifest: {
                runId: '123-2',
                dump: {key: 'seed-data.dump', version: 'dump-version', bytes: 8, sha256: 'a'.repeat(64)},
                certificate: {key: 'seeding/certificate-references/123-2.png', version: 'cert-version'},
            },
        })]]);
    });

    it('runs pg_dump and publishes a manifest only after exact multipart completion', () => {
        const result = runDumpCli('success');
        expect(result.status).toBe(0);
        expect(result.calls).toEqual([
            'create-multipart-upload', 'upload-part', 'complete-multipart-upload', 'put-object',
        ]);
        expect(result.stdout).toContain('NFT_SEED_MANIFEST_VERSION=manifest-version'); // pragma: allowlist secret
        expect(result.stdout).not.toContain('cert-version');
        expect(result.stdout).not.toContain('dump-version');
        expect(result.details['complete-multipart-upload'].body).toEqual({Parts: [{ETag: '"part-etag"', PartNumber: 1}]});
        expect(result.details['put-object'].args).toContain('--if-none-match');
        expect(result.details['put-object'].body).toEqual({
            runId: '123-2',
            dump: {
                key: 'seed-data.dump', version: 'dump-version', bytes: 8,
                sha256: '9c56cc51b374c3ba189210d5b6d4bf57790d351c96c47c02190ecf1e430635ab', // pragma: allowlist secret
            },
            certificate: {key: 'seeding/certificate-references/123-2.png', version: 'cert-version'},
        });
    });

    it.each(['dump-failure', 'completion-failure'])(
        'does not publish a manifest after %s', scenario => {
            const result = runDumpCli(scenario);
            expect(result.status).toBe(1);
            expect(result.calls).not.toContain('put-object');
            expect(result.stdout).not.toContain('NFT_SEED_MANIFEST_VERSION=');
        }
    );
});

const fakeAws = `#!/usr/bin/env node
const fs = require('node:fs');
const args = process.argv.slice(2);
const queryIndex = args.indexOf('--query');
const query = queryIndex < 0 ? '' : args[queryIndex + 1];
const desiredStatusIndex = args.indexOf('--desired-status');
let key;
if (args[0] === 's3api' && args[1] === 'head-object') {
  key = args.includes('--version-id') ? 'certificateCopiedHead' : 'certificate';
}
else if (args[0] === 's3api' && args[1] === 'copy-object') key = 'certificateCopy';
else if (args[0] === 's3api' && args[1] === 'get-object') key = 'manifestGet';
else if (args[0] === 'logs' && args[1] === 'get-log-events') key = 'manifestLog';
else if (args[0] === 'ecs' && args[1] === 'describe-services') {
  key = args[args.indexOf('--query') + 1].includes('subnets') ? 'subnets' : 'securityGroups';
} else if (args[0] === 'ecs' && args[1] === 'run-task') key = 'runTask';
else if (args[0] === 'ecs' && args[1] === 'describe-tasks') {
  key = query.includes('lastStatus') ? 'status' :
    query.includes('nft-data-seeder') ? 'seedExit' :
      query.includes('stopCode') ? 'stopCode' : 'dump';
}
else if (args[0] === 'ecs' && args[1] === 'list-tasks') key = 'listTasks';
else if (args[0] === 'ecs' && args[1] === 'stop-task') key = 'stop';
else key = 'unexpected';
const readJson = (file, fallback) => fs.existsSync(file) ? JSON.parse(fs.readFileSync(file, 'utf8')) : fallback;
const state = readJson(process.env.FAKE_AWS_STATE, {});
const index = state[key] || 0;
state[key] = index + 1;
fs.writeFileSync(process.env.FAKE_AWS_STATE, JSON.stringify(state));
const calls = readJson(process.env.FAKE_AWS_TRACE, []);
calls.push({key, query: query || null, cluster: args[args.indexOf('--cluster') + 1] || null,
  task: args[args.indexOf('--task') + 1] || null,
  objectKey: args.includes('--key') ? args[args.indexOf('--key') + 1] : null,
  versionId: args.includes('--version-id') ? args[args.indexOf('--version-id') + 1] : null,
  copySource: args.includes('--copy-source') ? args[args.indexOf('--copy-source') + 1] : null,
  overrides: args.includes('--overrides') ? JSON.parse(args[args.indexOf('--overrides') + 1]) : null,
  startedBy: args[args.indexOf('--started-by') + 1] || null,
  clientToken: args[args.indexOf('--client-token') + 1] || null,
  desiredStatus: desiredStatusIndex < 0 ? null : args[desiredStatusIndex + 1],
  count: args[args.indexOf('--count') + 1] || null});
fs.writeFileSync(process.env.FAKE_AWS_TRACE, JSON.stringify(calls));
if (key === 'listTasks' && args.includes('--started-by') && args.includes('--desired-status')) {
  process.stderr.write('An error occurred (InvalidParameterException) when calling ListTasks: startedBy must be the only filter');
  process.exit(254);
}
const fixtures = JSON.parse(process.env.FAKE_AWS_FIXTURES);
const entries = fixtures[key] || [];
const response = entries[Math.min(index, entries.length - 1)] || {stdout: ''};
if (key === 'manifestGet' && !response.exitCode) fs.writeFileSync(args[args.length - 1], process.env.FAKE_MANIFEST);
if (response.stdout) process.stdout.write(response.stdout);
if (response.stderr) process.stderr.write(response.stderr);
process.exit(response.exitCode || 0);
`;

function runWorkflowStep(stepId, fixtures, envOverrides = {}) {
    const step = workflow.jobs.generate.steps.find(candidate => candidate.id === stepId);
    if (!step) throw new Error(`Workflow step ${stepId} was not found`);

    const scratch = fs.mkdtempSync(path.join(os.tmpdir(), '.generate-nft-seed-'));
    try {
        const bin = path.join(scratch, 'bin');
        fs.mkdirSync(bin);
        fs.writeFileSync(path.join(bin, 'aws'), fakeAws, {mode: 0o755});
        fs.writeFileSync(path.join(bin, 'sleep'), '#!/bin/sh\nprintf "%s\\n" "$1" >> "$FAKE_SLEEP_TRACE"\n', {mode: 0o755});
        const outputFile = path.join(scratch, 'github-output');
        const stateFile = path.join(scratch, 'aws-state.json');
        const traceFile = path.join(scratch, 'aws-trace.json');
        const sleepTrace = path.join(scratch, 'sleep-trace');
        fs.writeFileSync(outputFile, '');
        fs.writeFileSync(stateFile, '{}');
        fs.writeFileSync(traceFile, '[]');
        fs.writeFileSync(sleepTrace, '');

        const result = spawnSync('/bin/bash', ['-e', '-u', '-o', 'pipefail', '-c', step.run], {
            cwd: repoDir,
            encoding: 'utf8',
            timeout: 60000,
            env: {
                PATH: `${bin}${path.delimiter}${process.env.PATH}`,
                AWS_REGION: 'eu-west-2',
                AWS_ACCOUNT_ID: '448120078528',
                ENVIRONMENT: 'nft',
                RUNNER_TEMP: scratch,
                GITHUB_OUTPUT: outputFile,
                GITHUB_RUN_ID: '123456789',
                GITHUB_RUN_ATTEMPT: '1',
                CERTIFICATE_KEY: 'seeding/certificate-references/123456789-1.png',
                CERTIFICATE_VERSION_ID: 'certificate-canary',
                TASK_NETWORK: '{"awsvpcConfiguration":{"subnets":["network-canary"],"securityGroups":["security-group-canary"],"assignPublicIp":"DISABLED"}}',
                TASK_ARN: '',
                MAX_ATTEMPTS: '680',
                RECONCILE_MAX_ATTEMPTS: '5',
                FAKE_AWS_FIXTURES: JSON.stringify(fixtures),
                FAKE_MANIFEST: JSON.stringify({
                    runId: '123456789-1',
                    dump: {key: 'seed-data.dump', version: 'dump-version', bytes: 8, sha256: 'a'.repeat(64)},
                    certificate: {key: 'seeding/certificate-references/123456789-1.png', version: 'certificate-canary'},
                }),
                FAKE_AWS_STATE: stateFile,
                FAKE_AWS_TRACE: traceFile,
                FAKE_SLEEP_TRACE: sleepTrace,
                ...envOverrides,
            },
        });
        if (result.error) throw result.error;
        return {
            ...result,
            outputs: fs.readFileSync(outputFile, 'utf8'),
            awsCalls: JSON.parse(fs.readFileSync(traceFile, 'utf8')),
            sleepCalls: fs.readFileSync(sleepTrace, 'utf8').trim().split('\n').filter(Boolean),
        };
    } finally {
        fs.rmSync(scratch, {recursive: true, force: true});
    }
}

function successfulLaunch(statuses = ['STOPPED'], dumpExitCode = '0') {
    return {
        runTask: [{stdout: JSON.stringify({tasks: [{taskArn}], failures: []})}],
        status: statuses.map(stdout => ({stdout})),
        dump: [{stdout: dumpExitCode}],
        manifestLog: [{stdout: JSON.stringify(['NFT_SEED_MANIFEST_VERSION=manifest-version'])}],
        manifestGet: [{stdout: JSON.stringify({VersionId: 'manifest-version'})}],
    };
}

function outputValue(outputs, key) {
    return outputs.split('\n').find(line => line.startsWith(`${key}=`))?.slice(key.length + 1) || '';
}

describe('NFT seed workflow preflight diagnostics', () => {
    it('copies a pinned template to a unique run-owned key and verifies its exact version', () => {
        const result = runWorkflowStep('certificate', {
            certificate: [{stdout: 'template-version'}],
            certificateCopy: [{stdout: JSON.stringify({VersionId: 'copied-version'})}],
            certificateCopiedHead: [{stdout: JSON.stringify({VersionId: 'copied-version', ContentLength: 123})}],
        });
        expect(result.status).toBe(0);
        expect(outputValue(result.outputs, 'key')).toBe('seeding/certificate-references/123456789-1.png');
        expect(outputValue(result.outputs, 'version-id')).toBe('copied-version');
        expect(result.awsCalls.map(call => call.key)).toEqual([
            'certificate', 'certificateCopy', 'certificateCopiedHead',
        ]);
        expect(result.awsCalls[1]).toEqual(expect.objectContaining({
            objectKey: 'seeding/certificate-references/123456789-1.png',
            copySource: 'prsdb-uploaded-files-nft/seeding/certificate_template.png?versionId=template-version',
        }));
        expect(result.awsCalls[2]).toEqual(expect.objectContaining({
            objectKey: 'seeding/certificate-references/123456789-1.png', versionId: 'copied-version',
        }));
    });

    it('rejects a copied certificate whose version cannot be verified', () => {
        const result = runWorkflowStep('certificate', {
            certificate: [{stdout: 'template-version'}],
            certificateCopy: [{stdout: JSON.stringify({VersionId: 'copied-version'})}],
            certificateCopiedHead: [{stdout: JSON.stringify({VersionId: 'wrong-version', ContentLength: 123})}],
        });
        expect(result.status).toBe(1);
        expect(outputValue(result.outputs, 'version-id')).toBe('');
    });

    it.each([
        ['missing copy version', {certificateCopy: [{stdout: '{}'}]}],
        ['copy access failure', {certificateCopy: [{exitCode: 254, stderr: 'private-payload-canary'}]}],
        ['head access failure', {certificateCopiedHead: [{exitCode: 254, stderr: 'private-payload-canary'}]}],
        ['empty copy', {certificateCopiedHead: [{stdout: JSON.stringify({VersionId: 'copied-version', ContentLength: 0})}]}],
    ])('fails closed on %s', (_description, overrides) => {
        const result = runWorkflowStep('certificate', {
            certificate: [{stdout: 'template-version'}],
            certificateCopy: [{stdout: JSON.stringify({VersionId: 'copied-version'})}],
            certificateCopiedHead: [{stdout: JSON.stringify({VersionId: 'copied-version', ContentLength: 123})}],
            ...overrides,
        });
        expect(result.status).toBe(1);
        expect(outputValue(result.outputs, 'version-id')).toBe('');
        expect(result.stdout + result.stderr).not.toContain('private-payload-canary');
    });

    it('reports certificate AWS errors without exposing certificate data', () => {
        const result = runWorkflowStep('certificate', {
            certificate: [{
                exitCode: 254,
                stderr: 'An error occurred (AccessDeniedException) when calling HeadObject: certificate-canary private-payload-canary',
            }],
        });

        expect(result.status).toBe(1);
        expect(result.stdout).toContain('Certificate metadata preflight failed');
        expect(result.stdout).toContain('AccessDeniedException');
        expect(result.stdout).not.toContain('certificate-canary');
        expect(result.stdout).not.toContain('private-payload-canary');
    });

    it('reports networking AWS errors without exposing network details', () => {
        const result = runWorkflowStep('networking', {
            subnets: [{stdout: '["subnet-canary"]'}],
            securityGroups: [{
                exitCode: 254,
                stderr: 'An error occurred (AccessDeniedException) when calling DescribeServices: network-canary private-payload-canary',
            }],
        });

        expect(result.status).toBe(1);
        expect(result.stdout).toContain('security-group preflight failed');
        expect(result.stdout).toContain('AccessDeniedException');
        expect(result.stdout).not.toContain('subnet-canary');
        expect(result.stdout).not.toContain('network-canary');
        expect(result.stdout).not.toContain('private-payload-canary');
    });
});

describe('NFT seed workflow task polling', () => {
    it('requires an exact versioned manifest before reporting successful seed completion', () => {
        const fixture = successfulLaunch();
        fixture.manifestLog = [{stdout: '[]'}];
        const result = runWorkflowStep('run-task', fixture);
        expect(result.status).toBe(1);
        expect(result.stdout).not.toContain('Seed dump completed');
    });

    it('retrieves the exact manifest version produced by this task', () => {
        const result = runWorkflowStep('run-task', successfulLaunch());
        expect(result.status).toBe(0);
        expect(result.awsCalls.find(call => call.key === 'manifestGet')).toEqual(expect.objectContaining({
            objectKey: 'seed-manifests/123456789-1.json', versionId: 'manifest-version',
        }));
        expect(outputValue(result.outputs, 'manifest-version')).toBe('manifest-version');
    });

    it('rejects a response for a different manifest version', () => {
        const fixture = successfulLaunch();
        fixture.manifestGet = [{stdout: JSON.stringify({VersionId: 'another-version'})}];
        const result = runWorkflowStep('run-task', fixture);
        expect(result.status).toBe(1);
        expect(result.stdout).not.toContain('Seed dump completed');
    });

    it('rejects a manifest that binds a different certificate to the dump', () => {
        const result = runWorkflowStep('run-task', successfulLaunch(), {
            FAKE_MANIFEST: JSON.stringify({
                runId: '123456789-1',
                dump: {key: 'seed-data.dump', version: 'dump-version', bytes: 8, sha256: 'a'.repeat(64)},
                certificate: {key: 'seeding/certificate-references/123456789-1.png', version: 'different'},
            }),
        });
        expect(result.status).toBe(1);
        expect(result.stdout).not.toContain('Seed dump completed');
    });

    it('retries missing status before observing RUNNING and STOPPED', () => {
        const result = runWorkflowStep('run-task', successfulLaunch(['', 'None', 'RUNNING', 'STOPPED']));

        expect(result.status).toBe(0);
        expect(result.stdout).toContain('Task status: RUNNING');
        expect(result.stdout).toContain('Seed dump completed');
        expect(result.sleepCalls).toEqual(['30', '30', '30']);
    });

    it('bounds repeated missing status with the configured polling limit', () => {
        const result = runWorkflowStep('run-task', successfulLaunch(Array(3).fill('None')), {MAX_ATTEMPTS: '3'});

        expect(result.status).toBe(1);
        expect(result.stdout).toMatch(/Timed out waiting|status remained unavailable/);
        expect(result.awsCalls.filter(call => call.key === 'status')).toHaveLength(3);
        expect(result.sleepCalls).toEqual(['30', '30', '30']);
    });

    it('continues polling through DEPROVISIONING before STOPPED', () => {
        const result = runWorkflowStep('run-task', successfulLaunch(['DEPROVISIONING', 'STOPPED']));

        expect(result.status).toBe(0);
        expect(result.stdout).toContain('Task status: DEPROVISIONING');
        expect(result.stdout).toContain('Seed dump completed');
    });

    it('retries a transient describe-tasks error and continues polling', () => {
        const fixtures = successfulLaunch(['RUNNING', 'STOPPED']);
        fixtures.status.unshift({
            exitCode: 254,
            stderr: 'An error occurred (ThrottlingException) when calling the DescribeTasks operation: private-payload-canary',
        });
        const result = runWorkflowStep('run-task', fixtures);

        expect(result.status).toBe(0);
        expect(result.stdout).toContain('ThrottlingException');
        expect(result.stdout).toContain('Seed dump completed');
        expect(result.stdout).not.toContain('private-payload-canary');
    });

    it('fails explicitly on an unknown ECS status instead of treating it as success', () => {
        const result = runWorkflowStep('run-task', successfulLaunch(['FUTURE_STATUS']));

        expect(result.status).toBe(1);
        expect(result.stdout).toMatch(/unrecognized.*status|unknown.*status/i);
        expect(result.stdout).not.toContain('Seed dump completed');
    });

    it('reports an AWS permission error without exposing the response message', () => {
        const fixtures = successfulLaunch();
        fixtures.runTask = [{
            exitCode: 254,
            stderr: 'An error occurred (AccessDeniedException) when calling RunTask: certificate-canary network-canary private-payload-canary',
        }];
        const result = runWorkflowStep('run-task', fixtures);

        expect(result.status).toBe(1);
        expect(result.stdout).toContain('run-task');
        expect(result.stdout).toContain('AccessDeniedException');
        expect(result.stdout).not.toContain('certificate-canary');
        expect(result.stdout).not.toContain('network-canary');
        expect(result.stdout).not.toContain('private-payload-canary');
    });

    it('reports a describe-tasks permission error safely', () => {
        const fixtures = successfulLaunch();
        fixtures.status = [{
            exitCode: 254,
            stderr: 'An error occurred (AccessDeniedException) when calling DescribeTasks: private-payload-canary',
        }];
        const result = runWorkflowStep('run-task', fixtures);

        expect(result.status).toBe(1);
        expect(result.stdout).toContain('describe-tasks');
        expect(result.stdout).toContain('AccessDeniedException');
        expect(result.stdout).not.toContain('private-payload-canary');
    });

    it('distinguishes a missing dump-container exit code from a nonzero exit code', () => {
        const missing = runWorkflowStep('run-task', successfulLaunch(['STOPPED'], 'None'));
        const failed = runWorkflowStep('run-task', successfulLaunch(['STOPPED'], '17'));

        expect(missing.status).toBe(1);
        expect(missing.stdout).toMatch(/dump container.*(missing|unavailable|exit code)/i);
        expect(failed.status).toBe(1);
        expect(failed.stdout).toContain('17');
    });

    it('reports the seed exit code and safe stop category when the dump container did not start', () => {
        const fixtures = successfulLaunch(['STOPPED'], 'None');
        fixtures.seedExit = [{stdout: '42'}];
        fixtures.stopCode = [{stdout: 'EssentialContainerExited'}];
        const result = runWorkflowStep('run-task', fixtures);

        expect(result.status).toBe(1);
        expect(result.stdout).toContain('Seed container exit code: 42');
        expect(result.stdout).toContain('Task stop category: EssentialContainerExited');
        expect(result.stdout).not.toContain('Seed dump completed');
    });

    it('does not disclose unexpected seed diagnostics or task stop details', () => {
        const fixtures = successfulLaunch(['STOPPED'], 'None');
        fixtures.seedExit = [{stdout: 'private-payload-canary'}];
        fixtures.stopCode = [{stdout: 'private-payload-canary'}];
        const result = runWorkflowStep('run-task', fixtures);

        expect(result.status).toBe(1);
        expect(result.stdout).toContain('Seed container exit code unavailable');
        expect(result.stdout).toContain('Task stop category unavailable');
        expect(result.stdout).not.toContain('private-payload-canary');
    });
});

describe('NFT seed workflow task identity and cleanup', () => {
    it('passes the same run-owned certificate identity to both seed and dump containers', () => {
        const result = runWorkflowStep('run-task', successfulLaunch());
        const overrides = result.awsCalls.find(call => call.key === 'runTask').overrides.containerOverrides;
        const seeder = Object.fromEntries(overrides.find(container => container.name === 'nft-data-seeder')
            .environment.map(({name, value}) => [name, value]));
        const dump = Object.fromEntries(overrides.find(container => container.name === 'nft-database-dump')
            .environment.map(({name, value}) => [name, value]));
        expect(seeder.NFT_SEED_CERTIFICATE_OBJECT_KEY).toBe('seeding/certificate-references/123456789-1.png');
        expect(dump.NFT_SEED_CERTIFICATE_OBJECT_KEY).toBe(seeder.NFT_SEED_CERTIFICATE_OBJECT_KEY);
        expect(dump.NFT_SEED_CERTIFICATE_VERSION_ID).toBe(seeder.NFT_SEED_CERTIFICATE_VERSION_ID);
        expect(dump.NFT_SEED_RUN_ID).toBe('123456789-1');
    });

    it('does not launch a seed task with another run certificate key', () => {
        const result = runWorkflowStep('run-task', successfulLaunch(), {
            CERTIFICATE_KEY: 'seeding/certificate-references/999-1.png',
        });
        expect(result.status).toBe(1);
        expect(result.awsCalls.some(call => call.key === 'runTask')).toBe(false);
    });

    it('reconciles an ambiguous launch after eventual consistency using its unique startedBy', () => {
        const fixtures = successfulLaunch(['STOPPED']);
        fixtures.runTask[0] = {
            exitCode: 255,
            stderr: 'Could not connect to endpoint; certificate-canary network-canary private-payload-canary',
        };
        fixtures.listTasks = [{stdout: '[]'}, {stdout: JSON.stringify([taskArn])}];
        const result = runWorkflowStep('run-task', fixtures);

        expect(result.status).toBe(0);
        expect(result.stdout).toContain('Seed dump completed');
        expect(result.outputs).toContain(`task-arn=${taskArn}`);
        expect(result.stdout).not.toContain('certificate-canary');
        expect(result.stdout).not.toContain('network-canary');
        expect(result.stdout).not.toContain('private-payload-canary');
        const runCall = result.awsCalls.find(call => call.key === 'runTask');
        expect(runCall.startedBy).toBe(startedBy);
        expect(runCall.clientToken).toBe(startedBy);
        expect(runCall.count).toBe('1');
        const listCalls = result.awsCalls.filter(call => call.key === 'listTasks');
        expect(listCalls).toHaveLength(2);
        expect(listCalls.every(call => call.cluster === 'nft-app' && call.startedBy === startedBy)).toBe(true);
        expect(listCalls.every(call => call.desiredStatus === null)).toBe(true);
    });

    it('reports reconciliation permission errors without exposing AWS response text', () => {
        const fixtures = successfulLaunch();
        fixtures.runTask[0] = {exitCode: 255, stderr: 'network failure'};
        fixtures.listTasks = [{
            exitCode: 254,
            stderr: 'An error occurred (AccessDeniedException) when calling ListTasks: private-payload-canary',
        }];
        const result = runWorkflowStep('run-task', fixtures);

        expect(result.status).toBe(1);
        expect(result.stdout).toContain('list-tasks');
        expect(result.stdout).toContain('AccessDeniedException');
        expect(result.stdout).toContain(startedBy);
        expect(result.stdout).not.toContain('private-payload-canary');
        expect(result.awsCalls.some(call => call.key === 'stop')).toBe(false);
    });

    it('fails with operator guidance when reconciliation finds no task', () => {
        const fixtures = successfulLaunch();
        fixtures.runTask[0] = {exitCode: 255, stderr: 'network failure'};
        fixtures.listTasks = [{stdout: '[]'}];
        const result = runWorkflowStep('run-task', fixtures, {RECONCILE_MAX_ATTEMPTS: '2'});

        expect(result.status).toBe(1);
        expect(result.stdout).toContain('nft-123456789-1');
        expect(result.stdout).toMatch(/may have been accepted|ambiguous/i);
        expect(result.stdout).toMatch(/operator|inspect|check/i);
        expect(result.stdout).not.toMatch(/no task was started/i);
        expect(result.stdout).toMatch(/stopped task.*may not be discoverable|default.*running/i);
        expect(result.awsCalls.filter(call => call.key === 'runTask')).toHaveLength(1);
        expect(outputValue(result.outputs, 'task-arn')).toBe('');
    });

    it('does not choose or stop a task when reconciliation finds multiple matches', () => {
        const otherTaskArn = 'arn:aws:ecs:eu-west-2:448120078528:task/nft-app/abcdef0123456789abcdef0123456789';
        const fixtures = successfulLaunch();
        fixtures.runTask[0] = {exitCode: 255, stderr: 'network failure'};
        fixtures.listTasks = [{stdout: JSON.stringify([taskArn, otherTaskArn])}];
        const result = runWorkflowStep('run-task', fixtures);

        expect(result.status).toBe(1);
        expect(result.stdout).toMatch(/multiple.*task|more than one/i);
        expect(result.awsCalls.some(call => call.key === 'stop')).toBe(false);
        expect(outputValue(result.outputs, 'task-arn')).toBe('');
    });

    it('accepts an otherwise valid RunTask response with no failures field', () => {
        const fixtures = successfulLaunch(['STOPPED']);
        fixtures.runTask[0] = {stdout: JSON.stringify({tasks: [{taskArn}]})};
        const result = runWorkflowStep('run-task', fixtures);

        expect(result.status).toBe(0);
        expect(result.outputs).toContain(`task-arn=${taskArn}`);
        expect(result.stdout).toContain('Seed dump completed');
    });

    it('reports RunTask failures and missing tasks explicitly', () => {
        const failedLaunch = runWorkflowStep('run-task', {
            runTask: [{stdout: JSON.stringify({tasks: [], failures: [{reason: 'private-payload-canary'}]})}],
        });
        const emptyLaunch = runWorkflowStep('run-task', {
            runTask: [{stdout: JSON.stringify({tasks: [], failures: []})}],
        });

        expect(failedLaunch.status).toBe(1);
        expect(failedLaunch.stdout).toMatch(/run-task.*failur/i);
        expect(failedLaunch.stdout).not.toContain('private-payload-canary');
        expect(emptyLaunch.status).toBe(1);
        expect(emptyLaunch.stdout).toMatch(/no task|task arn/i);
        expect(emptyLaunch.stdout).not.toMatch(/no task was started/i);
    });

    it('records a validated task before polling and cleanup uses that exact ARN after failure', () => {
        const fixtures = successfulLaunch(['FUTURE_STATUS']);
        const poll = runWorkflowStep('run-task', fixtures);
        const recordedArn = outputValue(poll.outputs, 'task-arn');
        const cleanup = runWorkflowStep('cleanup', {stop: [{stdout: '{}'}]}, {TASK_ARN: recordedArn});

        expect(poll.status).toBe(1);
        expect(recordedArn).toBe(taskArn);
        expect(cleanup.status).toBe(0);
        expect(cleanup.awsCalls.filter(call => call.key === 'stop')).toEqual([
            expect.objectContaining({cluster: 'nft-app', task: taskArn}),
        ]);
    });

    it('never sends an invalid or absent task ARN to stop-task', () => {
        const invalidArn = 'arn:aws:ecs:eu-west-2:999999999999:task/production-app/0123456789abcdef0123456789abcdef';
        const launch = runWorkflowStep('run-task', {
            runTask: [{stdout: JSON.stringify({tasks: [{taskArn: invalidArn}], failures: []})}],
            listTasks: [{stdout: '[]'}],
        }, {RECONCILE_MAX_ATTEMPTS: '1'});
        const cleanup = runWorkflowStep('cleanup', {stop: [{stdout: '{}'}]}, {TASK_ARN: outputValue(launch.outputs, 'task-arn')});

        expect(launch.status).toBe(1);
        expect(outputValue(launch.outputs, 'task-arn')).toBe('');
        expect(cleanup.status).toBe(0);
        expect(cleanup.awsCalls.some(call => call.key === 'stop')).toBe(false);
    });

    it('runs cleanup with the task output after cancellation and surfaces safe stop errors', () => {
        const started = runWorkflowStep('run-task', successfulLaunch(['STOPPED']));
        const recordedArn = outputValue(started.outputs, 'task-arn');
        const cleanup = runWorkflowStep('cleanup', {
            stop: [{exitCode: 254, stderr: 'An error occurred (AccessDeniedException) when calling StopTask: private-payload-canary'}],
        }, {TASK_ARN: recordedArn});

        expect(started.status).toBe(0);
        expect(recordedArn).toBe(taskArn);
        expect(cleanup.status).toBe(1);
        expect(cleanup.stdout).toContain('AccessDeniedException');
        expect(cleanup.stdout).not.toContain('private-payload-canary');
        expect(cleanup.awsCalls.some(call => call.key === 'stop' && call.task === taskArn)).toBe(true);
    });

    it('keeps cleanup attached to failed or cancelled workflow runs', () => {
        const cleanup = workflow.jobs.generate.steps.find(candidate => candidate.name === 'Stop ECS task if workflow was cancelled or failed');

        expect(cleanup.if).toBe('failure() || cancelled()');
        expect(cleanup.env.TASK_ARN).toMatch(/steps\..*outputs\.task-arn/);
        expect(seedIam).toMatch(/actions\s*=\s*\["ecs:ListTasks"\][\s\S]*?resources\s*=\s*\["\*"\][\s\S]*?variable\s*=\s*"ecs:cluster"[\s\S]*?values\s*=\s*\["arn:aws:ecs:eu-west-2:\$\{data\.aws_caller_identity\.current\.account_id\}:cluster\/\$\{var\.environment_name\}-app"\]/);
        const taskStep = workflow.jobs.generate.steps.find(candidate => candidate.id === 'run-task');
        expect(taskStep.env.MAX_ATTEMPTS).toBe('680');
        expect(taskStep.env.RECONCILE_MAX_ATTEMPTS).toBe('5');
        expect(fs.readFileSync(workflowFile, 'utf8')).toContain('If runner loss prevents cleanup');
    });
});
