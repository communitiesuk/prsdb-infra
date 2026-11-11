const fs = require('fs');
const path = require('path');
const {spawnSync} = require('child_process');

const script = fs.readFileSync(path.join(__dirname,
    '../../terraform/nft/ecs_task_definition/nft_seed/performance_test_restore.sh'), 'utf8');
// Run only the service-response predicate, never the restore script or its AWS/database commands.
const serviceGuard = script.match(
    /jq -e --arg app[\s\S]*?'\s+"\$workspace\/services\.json" >\/dev\/null \|\| fail/
)[0].replace('"$workspace/services.json"', '/dev/stdin');

function guardStatus(services, failures = []) {
    const result = spawnSync('bash', ['-c', `set -eu\nfail() { exit 1; }\n${serviceGuard}`], {
        env: {
            ...process.env,
            NFT_APP_SERVICE: 'nft-app',
            NFT_SIMULATOR_SERVICE: 'nft-one-login-simulator',
            NFT_ASYNC_WORKER_SERVICE: 'nft-async-worker',
        },
        input: JSON.stringify({services, failures}),
        encoding: 'utf8',
    });
    if (result.error) throw result.error;
    expect(result.stderr).toBe('');
    return result.status;
}

function stoppedServices() {
    return ['nft-app', 'nft-one-login-simulator', 'nft-async-worker'].map(serviceName => ({
        serviceName, desiredCount: 0, runningCount: 0, pendingCount: 0,
    }));
}

describe('NFT restore writer service guard', () => {
    it('allows restoration only when all three services are stopped', () => {
        expect(guardStatus(stoppedServices())).toBe(0);
    });

    it.each(['desiredCount', 'runningCount', 'pendingCount'])(
        'refuses restoration when the async worker has nonzero %s', count => {
            const services = stoppedServices();
            services[2][count] = 1;
            expect(guardStatus(services)).toBe(1);
        }
    );

    it('refuses restoration when the async worker is missing', () => {
        expect(guardStatus(stoppedServices().slice(0, 2))).toBe(1);
    });

    it('refuses restoration when a duplicate service replaces the async worker', () => {
        const services = stoppedServices();
        services[2] = {...services[0]};
        expect(guardStatus(services)).toBe(1);
    });

    it('refuses restoration when ECS reports a service lookup failure', () => {
        expect(guardStatus(stoppedServices(), [{arn: 'nft-async-worker', reason: 'MISSING'}])).toBe(1);
    });
});
