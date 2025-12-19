const integrationScheduledTaskJson = require('../../terraform/integration/scheduled_tasks.json');
const testScheduledTaskJson  = require('../../terraform/test/scheduled_tasks.json');
const productionScheduledTaskJson  = require('../../terraform/production/scheduled_tasks.json');

// EventBridge has a limit of 64 characters for event rule names
// Our event rule names are "<environment_name>-<scheduled-task-name>-scheduled-task"
// Our longest environment name is "integration", leaving us 37 characters for the scheduled task name
const maxNameLength = 37;

function checkTopLevelNames(jsonFile) {
    const names = Object.keys(jsonFile);

    names.forEach(name => {
        expect(name.length).toBeLessThanOrEqual(maxNameLength);
    });
}

describe('Scheduled task names from scheduled_tasks.json', () => {
    it('on integration - names are no longer than 37 characters', () => {
        checkTopLevelNames(integrationScheduledTaskJson);
    });

    it('on test - names are no longer than 37 characters', () => {
        checkTopLevelNames(testScheduledTaskJson);
    });

    it('on production - names are no longer than 37 characters', () => {
        checkTopLevelNames(productionScheduledTaskJson);
    });
});

