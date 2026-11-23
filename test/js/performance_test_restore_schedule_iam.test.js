const fs = require('fs');
const path = require('path');

const repoDir = path.join(__dirname, '../..');
const scheduledTasks = require(path.join(repoDir, 'terraform/nft/scheduled_tasks.json'));
const taskDefinition = fs.readFileSync(
    path.join(repoDir, 'terraform/nft/ecs_task_definition/main.tf'), 'utf8'
);
const childVariables = fs.readFileSync(
    path.join(repoDir, 'terraform/nft/ecs_task_definition/nft_seed/variables.tf'), 'utf8'
);
const restorePolicy = fs.readFileSync(
    path.join(repoDir, 'terraform/nft/ecs_task_definition/nft_seed/performance_test_restore.tf'), 'utf8'
);

const accountId = '123456789012';
const environmentName = 'nft';

function schedulerResourceTemplate() {
    expect(taskDefinition).toMatch(/scheduled_tasks\s*=\s*jsondecode\(file\("\$\{path\.module\}\/\.\.\/scheduled_tasks\.json"\)\)/);
    const moduleBlock = taskDefinition.match(/module "nft_seed"\s*\{[^}]*\}/s)?.[0] ?? '';
    expect(moduleBlock).toMatch(/scheduled_task_names\s*=\s*keys\(local\.scheduled_tasks\)/);
    expect(childVariables).toMatch(/variable "scheduled_task_names"\s*\{[^}]*type\s*=\s*list\(string\)/s);

    const scheduleStatement = restorePolicy.match(/statement\s*\{\s*actions\s*=\s*\[[\s\S]*?"scheduler:GetSchedule"[\s\S]*?"scheduler:UpdateSchedule"[\s\S]*?\]\s*resources\s*=\s*\[[\s\S]*?\]\s*\}/);
    expect(scheduleStatement).not.toBeNull();
    const resources = scheduleStatement[0].match(/resources\s*=\s*\[\s*for\s+task_name\s+in\s+var\.scheduled_task_names\s*:\s*"([^"]+)"\s*\]/s);
    expect(resources).not.toBeNull();
    return resources[1];
}

function schedulerArns(taskNames) {
    const template = schedulerResourceTemplate();
    return taskNames.map(taskName => template
        .replace('${data.aws_caller_identity.current.account_id}', accountId)
        .replaceAll('${var.environment_name}', environmentName)
        .replace('${task_name}', taskName));
}

function schedulerTaskNamePattern() {
    const variableBlock = childVariables.match(/variable "scheduled_task_names"\s*\{([\s\S]*?)\n\s*\}/);
    expect(variableBlock).not.toBeNull();
    expect(variableBlock[1]).toMatch(/condition\s*=\s*alltrue\(\[/);
    expect(variableBlock[1]).toMatch(/for name in var\.scheduled_task_names/);
    const pattern = variableBlock[1].match(/can\(regex\("([^"]+)",\s*name\)\)/);
    expect(pattern).not.toBeNull();
    return new RegExp(pattern[1]);
}

describe('NFT performance restore Scheduler IAM resources', () => {
    it('derives a Scheduler ARN for every key in the NFT schedule JSON', () => {
        const taskNames = Object.keys(scheduledTasks);
        expect(schedulerArns(taskNames)).toEqual(taskNames.map(taskName =>
            `arn:aws:scheduler:eu-west-2:${accountId}:schedule/nft-scheduled-tasks-group/nft-${taskName}-scheduled-task`
        ));
    });

    it.each(['a', 'name-with-hyphens', 'Task_2.0', 'a'.repeat(64)])(
        'allows valid Scheduler name %s', taskName => {
            expect(schedulerTaskNamePattern().test(taskName)).toBe(true);
        }
    );

    it.each(['bad*name', 'bad?name', 'bad/name', '', 'a'.repeat(65)])(
        'rejects invalid Scheduler name %j', taskName => {
            expect(schedulerTaskNamePattern().test(taskName)).toBe(false);
        }
    );

    it('automatically includes a new schedule key in the derived resource set', () => {
        const schedulesWithSyntheticTask = {
            ...scheduledTasks,
            'future-scheduled-job': {schedule_expression: 'cron(0 2 * * ? *)'},
        };
        expect(schedulerArns(Object.keys(schedulesWithSyntheticTask)).at(-1)).toBe(
            `arn:aws:scheduler:eu-west-2:${accountId}:schedule/nft-scheduled-tasks-group/nft-future-scheduled-job-scheduled-task`
        );
    });

    it('keeps schedule listing region-limited and PassRole restricted', () => {
        expect(restorePolicy).toMatch(/actions\s*=\s*\["scheduler:ListSchedules"\][\s\S]*?resources\s*=\s*\["\*"\][\s\S]*?variable\s*=\s*"aws:RequestedRegion"[\s\S]*?values\s*=\s*\["eu-west-2"\]/);
        expect(restorePolicy).toMatch(/actions\s*=\s*\["iam:PassRole"\][\s\S]*?resources\s*=\s*\["arn:aws:iam::\$\{data\.aws_caller_identity\.current\.account_id\}:role\/nft-scheduled-tasks"\][\s\S]*?variable\s*=\s*"iam:PassedToService"[\s\S]*?values\s*=\s*\["scheduler\.amazonaws\.com"\]/);
    });
});
