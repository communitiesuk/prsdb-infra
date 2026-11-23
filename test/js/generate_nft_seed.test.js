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

const fakeAws = `#!/usr/bin/env node
const fs = require('node:fs');
const args = process.argv.slice(2);
const queryIndex = args.indexOf('--query');
const query = queryIndex < 0 ? '' : args[queryIndex + 1];
const desiredStatusIndex = args.indexOf('--desired-status');
let key;
if (args[0] === 's3api' && args[1] === 'head-object') key = 'certificate';
else if (args[0] === 'ecs' && args[1] === 'describe-services') {
  key = args[args.indexOf('--query') + 1].includes('subnets') ? 'subnets' : 'securityGroups';
} else if (args[0] === 'ecs' && args[1] === 'run-task') key = 'runTask';
else if (args[0] === 'ecs' && args[1] === 'describe-tasks') key = query.includes('lastStatus') ? 'status' : 'dump';
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
                GITHUB_OUTPUT: outputFile,
                GITHUB_RUN_ID: '123456789',
                GITHUB_RUN_ATTEMPT: '1',
                CERTIFICATE_VERSION_ID: 'certificate-canary',
                TASK_NETWORK: '{"awsvpcConfiguration":{"subnets":["network-canary"],"securityGroups":["security-group-canary"],"assignPublicIp":"DISABLED"}}',
                TASK_ARN: '',
                MAX_ATTEMPTS: '680',
                RECONCILE_MAX_ATTEMPTS: '5',
                FAKE_AWS_FIXTURES: JSON.stringify(fixtures),
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
    };
}

function outputValue(outputs, key) {
    return outputs.split('\n').find(line => line.startsWith(`${key}=`))?.slice(key.length + 1) || '';
}

describe('NFT seed workflow preflight diagnostics', () => {
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
});

describe('NFT seed workflow task identity and cleanup', () => {
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
