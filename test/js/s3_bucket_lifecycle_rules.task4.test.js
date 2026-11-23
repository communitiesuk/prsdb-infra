const fs = require('fs');
const path = require('path');

const repoDir = path.join(__dirname, '..', '..');
const nftSeedBucket = fs.readFileSync(
    path.join(repoDir, 'terraform', 'nft', 'ecs_task_definition', 'nft_seed', 's3.tf'), 'utf8');

describe('NFT seed bucket lifecycle contract', () => {
    it('keeps seven-day expiry on the named performance recovery prefix and preserves 700-day retention', () => {
        expect(nftSeedBucket).toMatch(/noncurrent_version_expiration_days\s*=\s*700/);
        expect(nftSeedBucket).toMatch(/access_s3_log_expiration_days\s*=\s*700/);
        expect(nftSeedBucket).toMatch(/id\s*=\s*"expire-performance-recovery-checkpoints"/);
        expect(nftSeedBucket).toMatch(/prefix\s*=\s*"performance-recovery\/"/);
        expect(nftSeedBucket).toMatch(/expiration_days\s*=\s*7/);
    });
});
