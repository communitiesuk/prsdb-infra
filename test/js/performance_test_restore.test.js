const fs = require('fs');
const path = require('path');
const {spawnSync} = require('child_process');

const script = fs.readFileSync(path.join(__dirname,
    '../../terraform/nft/ecs_task_definition/nft_seed/performance_test_restore.sh'), 'utf8');
const restoreDefinition = fs.readFileSync(path.join(__dirname,
    '../../terraform/nft/ecs_task_definition/nft_seed/performance_test_restore.tf'), 'utf8');
// Run only the service-response predicate, never the restore script or its AWS/database commands.
const serviceGuard = script.match(
    /jq -e --arg app[\s\S]*?'\s+"\$workspace\/services\.json" >\/dev\/null \|\| fail/
)[0].replace('"$workspace/services.json"', '-');
const versionGuard = script.split('pg_restore --version\n')[1].split('\nstage=identity')[0];

describe('NFT restore certificate contract', () => {
    it('keeps the independently pinned certificate binding consistent with the restored dump', () => {
        const locals = Object.fromEntries([...restoreDefinition.matchAll(/^  ([a-z0-9_]+)\s*=\s*"([^"]+)"/gm)]
            .map(([, name, value]) => [name, value]));
        function env(name) {
            const match = restoreDefinition.match(new RegExp(`name = "${name}", value = (local\\.[a-z0-9_]+|"[^"]+")`));
            if (!match) throw new Error(`Missing ${name}`);
            return match[1].startsWith('local.') ? locals[match[1].slice(6)] : match[1].slice(1, -1);
        }
        expect(env('NFT_CERTIFICATE_KEY')).toMatch(/^seeding\/(?:certificate_template|certificate-references\/[1-9]\d*-[1-9]\d*)\.png$/);
        expect(env('NFT_CERTIFICATE_VERSION')).toBeTruthy();
        for (const field of ['VERSION', 'BYTES', 'SHA256']) {
            expect(env(`NFT_CERTIFICATE_DUMP_${field}`)).toBe(env(`NFT_DUMP_${field}`));
        }
    });
});

function versionGuardStatus(clientMajorVersion, configuredMajorVersion) {
    const result = spawnSync('bash', ['-c', `set -eu
fail() { exit 1; }
pg_restore() { printf 'pg_restore (PostgreSQL) %s.0\\n' "$CLIENT_POSTGRES_MAJOR_VERSION"; }
${versionGuard}`], {
        env: {
            ...process.env,
            CLIENT_POSTGRES_MAJOR_VERSION: clientMajorVersion,
            POSTGRES_MAJOR_VERSION: configuredMajorVersion,
        },
        encoding: 'utf8',
    });
    if (result.error) throw result.error;
    expect(result.stderr).toBe('');
    return result.status;
}

describe('NFT restore PostgreSQL version guard', () => {
    it.each(['16', '17'])('accepts a client matching configured major version %s', majorVersion => {
        expect(versionGuardStatus(majorVersion, majorVersion)).toBe(0);
    });

    it.each([['16', '17'], ['17', '16']])(
        'rejects client major version %s when configured for %s', (clientMajorVersion, configuredMajorVersion) => {
            expect(versionGuardStatus(clientMajorVersion, configuredMajorVersion)).toBe(1);
        }
    );

    it.each(['', '0', '16 OR 1=1'])('rejects invalid configured major version %j', configuredMajorVersion => {
        expect(versionGuardStatus('16', configuredMajorVersion)).toBe(1);
    });
});

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
