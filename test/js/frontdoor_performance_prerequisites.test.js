const fs = require('fs');
const path = require('path');

const repoDir = path.join(__dirname, '..', '..');
const frontdoorDir = path.join(repoDir, 'terraform', 'modules', 'frontdoor');
const loadBalancerWaf = fs.readFileSync(path.join(frontdoorDir, 'load_balancer_waf.tf'), 'utf8');
const frontdoorVariables = fs.readFileSync(path.join(frontdoorDir, 'variables.tf'), 'utf8');
const cloudfront = fs.readFileSync(path.join(frontdoorDir, 'cloudfront.tf'), 'utf8');
const nftMain = fs.readFileSync(path.join(repoDir, 'terraform', 'nft', 'main.tf'), 'utf8');
const sqlRuleStart = loadBalancerWaf.indexOf('name     = "aws-managed-rules-sqli-rule-set"');
const sqlRuleEnd = loadBalancerWaf.indexOf('\n  rule {\n    name = "aws-managed-rules-unix-rule-set"', sqlRuleStart);
const managedSqlRule = loadBalancerWaf.slice(sqlRuleStart, sqlRuleEnd);
const queryRuleStart = loadBalancerWaf.lastIndexOf('  dynamic "rule" {');
const queryRuleEnd = loadBalancerWaf.indexOf('\n}\n\nresource "aws_wafv2_ip_set"', queryRuleStart);
const nftQueryRule = loadBalancerWaf.slice(queryRuleStart, queryRuleEnd);

describe('NFT performance frontdoor prerequisites', () => {
    it('counts SQLi query-argument matches only in NFT and blocks them outside the simulator authorization route', () => {
        expect(managedSqlRule).toContain('for_each = var.environment_name == "nft" && var.simulator_host != null ? [1] : []');
        expect(managedSqlRule).toContain('name = "SQLi_QUERYARGUMENTS"');

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

    it('opts NFT into disabled caching without changing shared defaults or origin forwarding', () => {
        expect(frontdoorVariables).toMatch(/variable "disable_caching" \{[\s\S]*?default\s+=\s+false/);
        expect(nftMain).toMatch(/disable_caching\s+=\s+true/);
        expect(cloudfront).toContain('data "aws_cloudfront_cache_policy" "caching_disabled"');
        expect(cloudfront).toContain('name = "Managed-CachingDisabled"');
        expect(cloudfront).toMatch(/cache_policy_id\s*=\s*var\.disable_caching \? data\.aws_cloudfront_cache_policy\.caching_disabled\[0\]\.id : aws_cloudfront_cache_policy\.main\.id/);
        expect(cloudfront).toContain('origin_request_policy_id   = aws_cloudfront_origin_request_policy.main.id');
        expect(cloudfront).toContain('custom_header {');
    });
});
