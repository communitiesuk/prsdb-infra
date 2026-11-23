const fs = require('fs');
const path = require('path');

const repoDir = path.join(__dirname, '..', '..');
const frontdoorDir = path.join(repoDir, 'terraform', 'modules', 'frontdoor');
const loadBalancerWaf = fs.readFileSync(path.join(frontdoorDir, 'load_balancer_waf.tf'), 'utf8');
const cloudfront = fs.readFileSync(path.join(frontdoorDir, 'cloudfront.tf'), 'utf8');
const nftMain = fs.readFileSync(path.join(repoDir, 'terraform', 'nft', 'main.tf'), 'utf8');
const productionMain = fs.readFileSync(path.join(repoDir, 'terraform', 'production', 'main.tf'), 'utf8');

function between(source, start, end) {
    const first = source.indexOf(start);
    const last = source.indexOf(end, first + start.length);
    if (first < 0 || last < 0 || last <= first) {
        throw new Error('Terraform block boundaries not found');
    }
    return source.slice(first, last);
}

describe('NFT performance frontdoor prerequisites', () => {
    it('rejects missing or incorrectly ordered block boundaries', () => {
        expect(() => between('start content', 'start', 'end')).toThrow('Terraform block boundaries not found');
        expect(() => between('end content start', 'start', 'end')).toThrow('Terraform block boundaries not found');
        expect(() => between('content end', 'start', 'end')).toThrow('Terraform block boundaries not found');
    });

    it('counts SQLi query-argument matches only in NFT and blocks them outside the simulator authorization route', () => {
        const managedSqlRule = between(loadBalancerWaf,
            'name     = "aws-managed-rules-sqli-rule-set"',
            '\n  rule {\n    name = "aws-managed-rules-unix-rule-set"');
        const name = 'name     = "block-sqli-query-outside-owned-nft-simulator-authorize"';
        const nameIndex = loadBalancerWaf.indexOf(name);
        const start = loadBalancerWaf.lastIndexOf('  dynamic "rule" {', nameIndex);
        expect(nameIndex).toBeGreaterThanOrEqual(0);
        expect(start).toBeGreaterThanOrEqual(0);
        const nftQueryRule = between(loadBalancerWaf.slice(start),
            '  dynamic "rule" {',
            '\n}\n\nresource "aws_wafv2_ip_set"');

        expect(managedSqlRule).toContain('for_each = var.environment_name == "nft" && var.simulator_host != null ? [1] : []');
        expect(managedSqlRule).toContain('name = "SQLi_QUERYARGUMENTS"');

        expect(nftQueryRule).toContain('for_each = var.environment_name == "nft" && var.simulator_host != null ? [1] : []');
        expect(nftQueryRule).toMatch(/name\s*=\s*"block-sqli-query-outside-owned-nft-simulator-authorize"/);
        expect(nftQueryRule).toMatch(/priority\s*=\s*11/);
        expect(nftQueryRule).toMatch(/action\s*\{\s*block\s*\{\s*\}\s*\}/);
        expect(nftQueryRule).toMatch(/key\s*=\s*"awswaf:managed:aws:sql-database:SQLi_QueryArguments"/);
        expect(nftQueryRule).toContain('not_statement {');
        expect(nftQueryRule).toMatch(/search_string\s*=\s*"GET"/);
        expect(nftQueryRule).toMatch(/search_string\s*=\s*"\/local\/internal-access\/authorize"/);
        expect(nftQueryRule).toMatch(/search_string\s*=\s*var\.simulator_host/);
        expect(nftQueryRule).not.toContain('or_statement {');
        expect(nftQueryRule).toMatch(/statement\s*\{\s*ip_set_reference_statement\s*\{\s*arn\s*=\s*aws_wafv2_ip_set\.performance_runner_regional\[0\]\.arn/s);
        expect(nftQueryRule).not.toContain('simulator_allowed_ips');
    });

    it('uses the shared default cache policy for NFT and Production', () => {
        for (const main of [nftMain, productionMain]) {
            const frontdoor = between(main, 'module "frontdoor" {', '\n}\n\nmodule "certificates"');
            expect(frontdoor).toContain('source = "../modules/frontdoor"');
            expect(frontdoor).not.toMatch(/disable_caching\s*=/);
        }
        const defaultBehavior = between(cloudfront, '  default_cache_behavior {', '\n  origin {');
        expect(defaultBehavior).toMatch(/cache_policy_id\s*=\s*aws_cloudfront_cache_policy\.main\.id/);
        expect(cloudfront).toContain('origin_request_policy_id   = aws_cloudfront_origin_request_policy.main.id');
        expect(cloudfront).toContain('custom_header {');
    });
});
