const fs = require('fs');
const path = require('path');
const vm = require('vm');

const moduleDir = path.join(__dirname, '..', '..', 'terraform', 'modules', 'frontdoor');
const exceptions = JSON.parse(fs.readFileSync(path.join(moduleDir, 'url_rewriter_exceptions.json'), 'utf8'));
const template = fs.readFileSync(path.join(moduleDir, 'url_rewriter.js.tftpl'), 'utf8');

function renderUrlRewriter(extraExceptions = []) {
    const mergedExceptions = [...new Set([...exceptions, ...extraExceptions])];
    const rendered = template.replace('${jsonencode(exceptions)}', JSON.stringify(mergedExceptions));

    return vm.runInNewContext(`${rendered}\nhandler;`);
}

const url_rewriter = renderUrlRewriter();
const url_rewriter_with_nft_exceptions = renderUrlRewriter(['local']);

describe('url_rewriter_extra_exceptions validation', () => {
    const variables = fs.readFileSync(path.join(moduleDir, 'variables.tf'), 'utf8');
    const validation = variables.split('variable "url_rewriter_extra_exceptions" {')[1].split('\n}')[0];

    it.each([
        ['local', true],
        ['Local_1-health', true],
        ['0', true],
        ['.', false],
        ['*', false],
        ['', false],
        [' ', false],
        ['local/epc', false],
        ['-local', false],
        ['_local', false],
        ['local.epc', false],
    ])('validates exception %j as %s', (segment, valid) => {
        const pattern = validation.match(/can\(regex\("([^"]+)", segment\)\)/);

        expect(pattern).not.toBeNull();
        expect(new RegExp(pattern[1]).test(segment)).toBe(valid);
    });
});

describe('url_rewriter', () => {
    it('returns the original url for a URL that does not include one of our domain names', () => {
        // given
        const event = createRequestEvent('www.not-our-service.gov.uk', '/dashboard');

        // when
        const new_event = url_rewriter(event);

        // then
        expect(new_event.headers.host.value + new_event.uri).toBe('www.not-our-service.gov.uk/dashboard');
    });

    it('does not rewrite NFT local EPC health paths', () => {
        const event = createRequestEvent(registerHomeToRentHost, '/local/epc/health');

        const new_event = url_rewriter_with_nft_exceptions(event);

        expect(new_event.headers.host.value + new_event.uri).toBe('https://register-home-to-rent.communities.gov.uk/local/epc/health');
    });

    it('does not rewrite NFT local GOV.UK Pay mock card paths', () => {
        const event = createRequestEvent(registerHomeToRentHost, '/local/gov-uk-pay/mock-card-page/example');

        const new_event = url_rewriter_with_nft_exceptions(event);

        expect(new_event.headers.host.value + new_event.uri).toBe('https://register-home-to-rent.communities.gov.uk/local/gov-uk-pay/mock-card-page/example');
    });

    it('keeps /local paths in the normal landlord route when no extra exception is configured', () => {
        const event = createRequestEvent(registerHomeToRentHost, '/local/epc/health');

        const new_event = url_rewriter(event);

        expect(new_event.headers.host.value + new_event.uri).toBe('https://register-home-to-rent.communities.gov.uk/landlord/local/epc/health');
    });

    it('does not affect unrelated hosts when NFT local exceptions are configured', () => {
        const event = createRequestEvent('www.not-our-service.gov.uk', '/local/epc/health');

        const new_event = url_rewriter_with_nft_exceptions(event);

        expect(new_event.headers.host.value + new_event.uri).toBe('www.not-our-service.gov.uk/local/epc/health');
    });

    it('preserves landlord, local-council, and system-operator routes', () => {
        const landlord_event = createRequestEvent(registerHomeToRentHost, '/dashboard');
        const council_event = createRequestEvent(searchLandlordHomeInformationHost, '/dashboard');
        const operator_event = createRequestEvent(searchLandlordHomeInformationHost, '/system-operator/manage-council-users/1');

        expect(url_rewriter_with_nft_exceptions(landlord_event).uri).toBe('/landlord/dashboard');
        expect(url_rewriter_with_nft_exceptions(council_event).uri).toBe('/local-council/dashboard');
        expect(url_rewriter_with_nft_exceptions(operator_event).uri).toBe('/system-operator/manage-council-users/1');
    });

    describe('for the register-home-to-rent domain', () => {
        it('inserts /landlord into the dashboard URL', () => {
            // given
            const event = createRequestEvent(registerHomeToRentHost, '/dashboard');

            // when
            const new_event = url_rewriter(event);

            // then
            expect(new_event.headers.host.value + new_event.uri).toBe('https://register-home-to-rent.communities.gov.uk/landlord/dashboard');
        });

        it('returns the original url if the first path segment after the domain is already /landlord', () => {
            // given
            const event = createRequestEvent(registerHomeToRentHost, '/landlord/dashboard');

            // when
            const new_event = url_rewriter(event);

            // then
            expect(new_event.headers.host.value + new_event.uri).toBe('https://register-home-to-rent.communities.gov.uk/landlord/dashboard');
        });

        it('inserts /landlord into a URL which has a /landlord segment, but not as the first path segment', () => {
            // given
            const event = createRequestEvent(registerHomeToRentHost, '/dashboard/landlord');

            // when
            const new_event = url_rewriter(event);

            // then
            expect(new_event.headers.host.value + new_event.uri).toBe('https://register-home-to-rent.communities.gov.uk/landlord/dashboard/landlord');

        })

        it('inserts /landlord into a URL where the first path segment is /local-council', () => {
            // given
            const event = createRequestEvent(registerHomeToRentHost, '/local-council/dashboard');

            // when
            const new_event = url_rewriter(event);

            // then
            expect(new_event.headers.host.value + new_event.uri).toBe('https://register-home-to-rent.communities.gov.uk/landlord/local-council/dashboard');
        });

        it('returns the original url for the /signout endpoint', () => {
            // given
            const event = createRequestEvent(registerHomeToRentHost, '/signout');

            // when
            const new_event = url_rewriter(event);

            // then
            expect(new_event.headers.host.value + new_event.uri).toBe('https://register-home-to-rent.communities.gov.uk/signout');
        });

        it('returns the original url for the /confirm-sign-out endpoint', () => {
            // given
            const event = createRequestEvent(registerHomeToRentHost, '/confirm-sign-out');

            // when
            const new_event = url_rewriter(event);

            // then
            expect(new_event.headers.host.value + new_event.uri).toBe('https://register-home-to-rent.communities.gov.uk/confirm-sign-out');
        });

        it('returns the original url for the /error/* endpoint', () => {
            // given
            const event = createRequestEvent(registerHomeToRentHost, '/error/some-error');

            // when
            const new_event = url_rewriter(event);

            // then
            expect(new_event.headers.host.value + new_event.uri).toBe('https://register-home-to-rent.communities.gov.uk/error/some-error');
        });

        it('returns the original url for the /assets endpoint', () => {
            // given
            const event = createRequestEvent(registerHomeToRentHost, '/assets');

            // when
            const new_event = url_rewriter(event);

            // then
            expect(new_event.headers.host.value + new_event.uri).toBe('https://register-home-to-rent.communities.gov.uk/assets');
        });

        it('returns the original url for the /id-verification endpoint', () => {
            // given
            const event = createRequestEvent(registerHomeToRentHost, '/id-verification');

            // when
            const new_event = url_rewriter(event);

            // then
            expect(new_event.headers.host.value + new_event.uri).toBe('https://register-home-to-rent.communities.gov.uk/id-verification');
        });

        it('returns the original url for the /logout endpoint', () => {
            // given
            const event = createRequestEvent(registerHomeToRentHost, '/logout');

            // when
            const new_event = url_rewriter(event);

            // then
            expect(new_event.headers.host.value + new_event.uri).toBe('https://register-home-to-rent.communities.gov.uk/logout');
        });

        it('returns the original url for the /oauth2 endpoint', () => {
            // given
            const event = createRequestEvent(registerHomeToRentHost, '/oauth2');

            // when
            const new_event = url_rewriter(event);

            // then
            expect(new_event.headers.host.value + new_event.uri).toBe('https://register-home-to-rent.communities.gov.uk/oauth2');
        });

        it('returns the original url for the /healthcheck endpoint', () => {
            // given
            const event = createRequestEvent(registerHomeToRentHost, '/healthcheck');

            // when
            const new_event = url_rewriter(event);

            // then
            expect(new_event.headers.host.value + new_event.uri).toBe('https://register-home-to-rent.communities.gov.uk/healthcheck');
        });

        it('returns the original url for the /cookies endpoint', () => {
            // given
            const event = createRequestEvent(registerHomeToRentHost, '/cookies');

            // when
            const new_event = url_rewriter(event);

            // then
            expect(new_event.headers.host.value + new_event.uri).toBe('https://register-home-to-rent.communities.gov.uk/cookies');
        });

        it('returns the original url for the /maintenance endpoint', () => {
            // given
            const event = createRequestEvent(registerHomeToRentHost, '/maintenance');

            // when
            const new_event = url_rewriter(event);

            // then
            expect(new_event.headers.host.value + new_event.uri).toBe('https://register-home-to-rent.communities.gov.uk/maintenance');
        });

        it('returns the original url for the /.well-known endpoint', () => {
            // given
            const event = createRequestEvent(registerHomeToRentHost, '/.well-known/security.txt');

            // when
            const new_event = url_rewriter(event);

            // then
            expect(new_event.headers.host.value + new_event.uri).toBe('https://register-home-to-rent.communities.gov.uk/.well-known/security.txt');
        });

        it('returns the original url for the /login endpoint', () => {
            // given
            const event = createRequestEvent(registerHomeToRentHost, '/login/oauth2/code/one-login');

            // when
            const new_event = url_rewriter(event);

            // then
            expect(new_event.headers.host.value + new_event.uri).toBe('https://register-home-to-rent.communities.gov.uk/login/oauth2/code/one-login');
        });
    });

    describe('for the search-landlord-home-information domain', () => {
        it('inserts /local-council into the dashboard URL', () => {
            // given
            const event = createRequestEvent(searchLandlordHomeInformationHost, '/dashboard');

            // when
            const new_event = url_rewriter(event);

            // then
            expect(new_event.headers.host.value + new_event.uri).toBe('https://search-landlord-home-information.communities.gov.uk/local-council/dashboard');
        });

        it('returns the original url if the first path segment after the domain is already /local-council', () => {
            // given
            const event = createRequestEvent(searchLandlordHomeInformationHost, '/local-council/dashboard');

            // when
            const new_event = url_rewriter(event);

            // then
            expect(new_event.headers.host.value + new_event.uri).toBe('https://search-landlord-home-information.communities.gov.uk/local-council/dashboard');
        });

        it('inserts /local-council into a URL which has a /local-council segment, but not as the first path segment', () => {
            // given
            const event = createRequestEvent(searchLandlordHomeInformationHost, '/dashboard/local-council');

            // when
            const new_event = url_rewriter(event);

            // then
            expect(new_event.headers.host.value + new_event.uri).toBe('https://search-landlord-home-information.communities.gov.uk/local-council/dashboard/local-council');

        })

        it('inserts /local-council into a URL where the first path segment is /landlord', () => {
            // given
            const event = createRequestEvent(searchLandlordHomeInformationHost, '/landlord/dashboard');

            // when
            const new_event = url_rewriter(event);

            // then
            expect(new_event.headers.host.value + new_event.uri).toBe('https://search-landlord-home-information.communities.gov.uk/local-council/landlord/dashboard');
        });

        it('returns the original url for the /signout endpoint', () => {
            // given
            const event = createRequestEvent(searchLandlordHomeInformationHost, '/signout');

            // when
            const new_event = url_rewriter(event);

            // then
            expect(new_event.headers.host.value + new_event.uri).toBe('https://search-landlord-home-information.communities.gov.uk/signout');
        });

        it('returns the original url for the /confirm-sign-out endpoint', () => {
            // given
            const event = createRequestEvent(searchLandlordHomeInformationHost, '/confirm-sign-out');

            // when
            const new_event = url_rewriter(event);

            // then
            expect(new_event.headers.host.value + new_event.uri).toBe('https://search-landlord-home-information.communities.gov.uk/confirm-sign-out');
        });

        it('returns the original url for the /error/* endpoint', () => {
            // given
            const event = createRequestEvent(searchLandlordHomeInformationHost, '/error/some-error');

            // when
            const new_event = url_rewriter(event);

            // then
            expect(new_event.headers.host.value + new_event.uri).toBe('https://search-landlord-home-information.communities.gov.uk/error/some-error');
        });

        it('returns the original url for the /assets endpoint', () => {
            // given
            const event = createRequestEvent(searchLandlordHomeInformationHost, '/assets');

            // when
            const new_event = url_rewriter(event);

            // then
            expect(new_event.headers.host.value + new_event.uri).toBe('https://search-landlord-home-information.communities.gov.uk/assets');
        });

        it('returns the original url for the /id-verification endpoint', () => {
            // given
            const event = createRequestEvent(searchLandlordHomeInformationHost, '/id-verification');

            // when
            const new_event = url_rewriter(event);

            // then
            expect(new_event.headers.host.value + new_event.uri).toBe('https://search-landlord-home-information.communities.gov.uk/id-verification');
        });

        it('returns the original url for the /logout endpoint', () => {
            // given
            const event = createRequestEvent(searchLandlordHomeInformationHost, '/logout');

            // when
            const new_event = url_rewriter(event);

            // then
            expect(new_event.headers.host.value + new_event.uri).toBe('https://search-landlord-home-information.communities.gov.uk/logout');
        });

        it('returns the original url for the /oauth2 endpoint', () => {
            // given
            const event = createRequestEvent(searchLandlordHomeInformationHost, '/oauth2');

            // when
            const new_event = url_rewriter(event);

            // then
            expect(new_event.headers.host.value + new_event.uri).toBe('https://search-landlord-home-information.communities.gov.uk/oauth2');
        });

        it('returns the original url for the /healthcheck endpoint', () => {
            // given
            const event = createRequestEvent(searchLandlordHomeInformationHost, '/healthcheck');

            // when
            const new_event = url_rewriter(event);

            // then
            expect(new_event.headers.host.value + new_event.uri).toBe('https://search-landlord-home-information.communities.gov.uk/healthcheck');
        });

        it('returns the original url for the /cookies endpoint', () => {
            // given
            const event = createRequestEvent(searchLandlordHomeInformationHost, '/cookies');

            // when
            const new_event = url_rewriter(event);

            // then
            expect(new_event.headers.host.value + new_event.uri).toBe('https://search-landlord-home-information.communities.gov.uk/cookies');
        });

        it('returns the original url for the /maintenance endpoint', () => {
            // given
            const event = createRequestEvent(searchLandlordHomeInformationHost, '/maintenance');

            // when
            const new_event = url_rewriter(event);

            // then
            expect(new_event.headers.host.value + new_event.uri).toBe('https://search-landlord-home-information.communities.gov.uk/maintenance');
        });

        it('returns the original url for the /.well-known endpoint', () => {
            // given
            const event = createRequestEvent(searchLandlordHomeInformationHost, '/.well-known/security.txt');

            // when
            const new_event = url_rewriter(event);

            // then
            expect(new_event.headers.host.value + new_event.uri).toBe('https://search-landlord-home-information.communities.gov.uk/.well-known/security.txt');
        });

        it('returns the original url for the /system-operator/manage-council-users endpoint', () => {
            // given
            const event = createRequestEvent(searchLandlordHomeInformationHost, '/system-operator/manage-council-users/1');

            // when
            const new_event = url_rewriter(event);

            // then
            expect(new_event.headers.host.value + new_event.uri).toBe('https://search-landlord-home-information.communities.gov.uk/system-operator/manage-council-users/1');
        });

        it('returns the original url for the /system-operator base path', () => {
            // given
            const event = createRequestEvent(searchLandlordHomeInformationHost, '/system-operator');

            // when
            const new_event = url_rewriter(event);

            // then
            expect(new_event.headers.host.value + new_event.uri).toBe('https://search-landlord-home-information.communities.gov.uk/system-operator');
        });

        it('returns the original url for the /login endpoint', () => {
            // given
            const event = createRequestEvent(searchLandlordHomeInformationHost, '/login/oauth2/code/one-login');

            // when
            const new_event = url_rewriter(event);

            // then
            expect(new_event.headers.host.value + new_event.uri).toBe('https://search-landlord-home-information.communities.gov.uk/login/oauth2/code/one-login');
        });
    });

    describe('for the register-rental-property domain', () => {
        it('inserts /landlord into the dashboard URL', () => {
            // given
            const event = createRequestEvent(registerRentalPropertyHost, '/dashboard');

            // when
            const new_event = url_rewriter(event);

            // then
            expect(new_event.headers.host.value + new_event.uri).toBe('https://register-rental-property.communities.gov.uk/landlord/dashboard');
        });

        it('returns the original url if the first path segment after the domain is already /landlord', () => {
            // given
            const event = createRequestEvent(registerRentalPropertyHost, '/landlord/dashboard');

            // when
            const new_event = url_rewriter(event);

            // then
            expect(new_event.headers.host.value + new_event.uri).toBe('https://register-rental-property.communities.gov.uk/landlord/dashboard');
        });

        it('inserts /landlord into a URL which has a /landlord segment, but not as the first path segment', () => {
            // given
            const event = createRequestEvent(registerRentalPropertyHost, '/dashboard/landlord');

            // when
            const new_event = url_rewriter(event);

            // then
            expect(new_event.headers.host.value + new_event.uri).toBe('https://register-rental-property.communities.gov.uk/landlord/dashboard/landlord');
        })

        it('inserts /landlord into a URL where the first path segment is /local-council', () => {
            // given
            const event = createRequestEvent(registerRentalPropertyHost, '/local-council/dashboard');

            // when
            const new_event = url_rewriter(event);

            // then
            expect(new_event.headers.host.value + new_event.uri).toBe('https://register-rental-property.communities.gov.uk/landlord/local-council/dashboard');
        });

        it('returns the original url for the /signout endpoint', () => {
            // given
            const event = createRequestEvent(registerRentalPropertyHost, '/signout');

            // when
            const new_event = url_rewriter(event);

            // then
            expect(new_event.headers.host.value + new_event.uri).toBe('https://register-rental-property.communities.gov.uk/signout');
        });

        it('returns the original url for the /confirm-sign-out endpoint', () => {
            // given
            const event = createRequestEvent(registerRentalPropertyHost, '/confirm-sign-out');

            // when
            const new_event = url_rewriter(event);

            // then
            expect(new_event.headers.host.value + new_event.uri).toBe('https://register-rental-property.communities.gov.uk/confirm-sign-out');
        });

        it('returns the original url for the /error/* endpoint', () => {
            // given
            const event = createRequestEvent(registerRentalPropertyHost, '/error/some-error');

            // when
            const new_event = url_rewriter(event);

            // then
            expect(new_event.headers.host.value + new_event.uri).toBe('https://register-rental-property.communities.gov.uk/error/some-error');
        });

        it('returns the original url for the /assets endpoint', () => {
            // given
            const event = createRequestEvent(registerRentalPropertyHost, '/assets');

            // when
            const new_event = url_rewriter(event);

            // then
            expect(new_event.headers.host.value + new_event.uri).toBe('https://register-rental-property.communities.gov.uk/assets');
        });

        it('returns the original url for the /id-verification endpoint', () => {
            // given
            const event = createRequestEvent(registerRentalPropertyHost, '/id-verification');

            // when
            const new_event = url_rewriter(event);

            // then
            expect(new_event.headers.host.value + new_event.uri).toBe('https://register-rental-property.communities.gov.uk/id-verification');
        });

        it('returns the original url for the /logout endpoint', () => {
            // given
            const event = createRequestEvent(registerRentalPropertyHost, '/logout');

            // when
            const new_event = url_rewriter(event);

            // then
            expect(new_event.headers.host.value + new_event.uri).toBe('https://register-rental-property.communities.gov.uk/logout');
        });

        it('returns the original url for the /oauth2 endpoint', () => {
            // given
            const event = createRequestEvent(registerRentalPropertyHost, '/oauth2');

            // when
            const new_event = url_rewriter(event);

            // then
            expect(new_event.headers.host.value + new_event.uri).toBe('https://register-rental-property.communities.gov.uk/oauth2');
        });

        it('returns the original url for the /healthcheck endpoint', () => {
            // given
            const event = createRequestEvent(registerRentalPropertyHost, '/healthcheck');

            // when
            const new_event = url_rewriter(event);

            // then
            expect(new_event.headers.host.value + new_event.uri).toBe('https://register-rental-property.communities.gov.uk/healthcheck');
        });

        it('returns the original url for the /cookies endpoint', () => {
            // given
            const event = createRequestEvent(registerRentalPropertyHost, '/cookies');

            // when
            const new_event = url_rewriter(event);

            // then
            expect(new_event.headers.host.value + new_event.uri).toBe('https://register-rental-property.communities.gov.uk/cookies');
        });

        it('returns the original url for the /maintenance endpoint', () => {
            // given
            const event = createRequestEvent(registerRentalPropertyHost, '/maintenance');

            // when
            const new_event = url_rewriter(event);

            // then
            expect(new_event.headers.host.value + new_event.uri).toBe('https://register-rental-property.communities.gov.uk/maintenance');
        });

        it('returns the original url for the /.well-known endpoint', () => {
            // given
            const event = createRequestEvent(registerRentalPropertyHost, '/.well-known/security.txt');

            // when
            const new_event = url_rewriter(event);

            // then
            expect(new_event.headers.host.value + new_event.uri).toBe('https://register-rental-property.communities.gov.uk/.well-known/security.txt');
        });

        it('returns the original url for the /login endpoint', () => {
            // given
            const event = createRequestEvent(registerRentalPropertyHost, '/login/oauth2/code/one-login');

            // when
            const new_event = url_rewriter(event);

            // then
            expect(new_event.headers.host.value + new_event.uri).toBe('https://register-rental-property.communities.gov.uk/login/oauth2/code/one-login');
        });
    });

    describe('for the check-rental-property-or-landlord domain', () => {
        it('inserts /local-council into the dashboard URL', () => {
            // given
            const event = createRequestEvent(checkRentalPropertyOrLandlordHost, '/dashboard');

            // when
            const new_event = url_rewriter(event);

            // then
            expect(new_event.headers.host.value + new_event.uri).toBe('https://check-rental-property-or-landlord.communities.gov.uk/local-council/dashboard');
        });

        it('returns the original url if the first path segment after the domain is already /local-council', () => {
            // given
            const event = createRequestEvent(checkRentalPropertyOrLandlordHost, '/local-council/dashboard');

            // when
            const new_event = url_rewriter(event);

            // then
            expect(new_event.headers.host.value + new_event.uri).toBe('https://check-rental-property-or-landlord.communities.gov.uk/local-council/dashboard');
        });

        it('inserts /local-council into a URL which has a /local-council segment, but not as the first path segment', () => {
            // given
            const event = createRequestEvent(checkRentalPropertyOrLandlordHost, '/dashboard/local-council');

            // when
            const new_event = url_rewriter(event);

            // then
            expect(new_event.headers.host.value + new_event.uri).toBe('https://check-rental-property-or-landlord.communities.gov.uk/local-council/dashboard/local-council');
        })

        it('inserts /local-council into a URL where the first path segment is /landlord', () => {
            // given
            const event = createRequestEvent(checkRentalPropertyOrLandlordHost, '/landlord/dashboard');

            // when
            const new_event = url_rewriter(event);

            // then
            expect(new_event.headers.host.value + new_event.uri).toBe('https://check-rental-property-or-landlord.communities.gov.uk/local-council/landlord/dashboard');
        });

        it('returns the original url for the /signout endpoint', () => {
            // given
            const event = createRequestEvent(checkRentalPropertyOrLandlordHost, '/signout');

            // when
            const new_event = url_rewriter(event);

            // then
            expect(new_event.headers.host.value + new_event.uri).toBe('https://check-rental-property-or-landlord.communities.gov.uk/signout');
        });

        it('returns the original url for the /confirm-sign-out endpoint', () => {
            // given
            const event = createRequestEvent(checkRentalPropertyOrLandlordHost, '/confirm-sign-out');

            // when
            const new_event = url_rewriter(event);

            // then
            expect(new_event.headers.host.value + new_event.uri).toBe('https://check-rental-property-or-landlord.communities.gov.uk/confirm-sign-out');
        });

        it('returns the original url for the /error/* endpoint', () => {
            // given
            const event = createRequestEvent(checkRentalPropertyOrLandlordHost, '/error/some-error');

            // when
            const new_event = url_rewriter(event);

            // then
            expect(new_event.headers.host.value + new_event.uri).toBe('https://check-rental-property-or-landlord.communities.gov.uk/error/some-error');
        });

        it('returns the original url for the /assets endpoint', () => {
            // given
            const event = createRequestEvent(checkRentalPropertyOrLandlordHost, '/assets');

            // when
            const new_event = url_rewriter(event);

            // then
            expect(new_event.headers.host.value + new_event.uri).toBe('https://check-rental-property-or-landlord.communities.gov.uk/assets');
        });

        it('returns the original url for the /id-verification endpoint', () => {
            // given
            const event = createRequestEvent(checkRentalPropertyOrLandlordHost, '/id-verification');

            // when
            const new_event = url_rewriter(event);

            // then
            expect(new_event.headers.host.value + new_event.uri).toBe('https://check-rental-property-or-landlord.communities.gov.uk/id-verification');
        });

        it('returns the original url for the /logout endpoint', () => {
            // given
            const event = createRequestEvent(checkRentalPropertyOrLandlordHost, '/logout');

            // when
            const new_event = url_rewriter(event);

            // then
            expect(new_event.headers.host.value + new_event.uri).toBe('https://check-rental-property-or-landlord.communities.gov.uk/logout');
        });

        it('returns the original url for the /oauth2 endpoint', () => {
            // given
            const event = createRequestEvent(checkRentalPropertyOrLandlordHost, '/oauth2');

            // when
            const new_event = url_rewriter(event);

            // then
            expect(new_event.headers.host.value + new_event.uri).toBe('https://check-rental-property-or-landlord.communities.gov.uk/oauth2');
        });

        it('returns the original url for the /healthcheck endpoint', () => {
            // given
            const event = createRequestEvent(checkRentalPropertyOrLandlordHost, '/healthcheck');

            // when
            const new_event = url_rewriter(event);

            // then
            expect(new_event.headers.host.value + new_event.uri).toBe('https://check-rental-property-or-landlord.communities.gov.uk/healthcheck');
        });

        it('returns the original url for the /cookies endpoint', () => {
            // given
            const event = createRequestEvent(checkRentalPropertyOrLandlordHost, '/cookies');

            // when
            const new_event = url_rewriter(event);

            // then
            expect(new_event.headers.host.value + new_event.uri).toBe('https://check-rental-property-or-landlord.communities.gov.uk/cookies');
        });

        it('returns the original url for the /maintenance endpoint', () => {
            // given
            const event = createRequestEvent(checkRentalPropertyOrLandlordHost, '/maintenance');

            // when
            const new_event = url_rewriter(event);

            // then
            expect(new_event.headers.host.value + new_event.uri).toBe('https://check-rental-property-or-landlord.communities.gov.uk/maintenance');
        });

        it('returns the original url for the /.well-known endpoint', () => {
            // given
            const event = createRequestEvent(checkRentalPropertyOrLandlordHost, '/.well-known/security.txt');

            // when
            const new_event = url_rewriter(event);

            // then
            expect(new_event.headers.host.value + new_event.uri).toBe('https://check-rental-property-or-landlord.communities.gov.uk/.well-known/security.txt');
        });

        it('returns the original url for the /system-operator/manage-council-users endpoint', () => {
            // given
            const event = createRequestEvent(checkRentalPropertyOrLandlordHost, '/system-operator/manage-council-users/1');

            // when
            const new_event = url_rewriter(event);

            // then
            expect(new_event.headers.host.value + new_event.uri).toBe('https://check-rental-property-or-landlord.communities.gov.uk/system-operator/manage-council-users/1');
        });

        it('returns the original url for the /system-operator base path', () => {
            // given
            const event = createRequestEvent(checkRentalPropertyOrLandlordHost, '/system-operator');

            // when
            const new_event = url_rewriter(event);

            // then
            expect(new_event.headers.host.value + new_event.uri).toBe('https://check-rental-property-or-landlord.communities.gov.uk/system-operator');
        });

        it('returns the original url for the /login endpoint', () => {
            // given
            const event = createRequestEvent(checkRentalPropertyOrLandlordHost, '/login/oauth2/code/one-login');

            // when
            const new_event = url_rewriter(event);

            // then
            expect(new_event.headers.host.value + new_event.uri).toBe('https://check-rental-property-or-landlord.communities.gov.uk/login/oauth2/code/one-login');
        });
    });
});


function createRequestEvent(host, endpoint) {
    return {
        request: {
            method: 'GET',
            uri: endpoint,
            headers: {
                host: {
                    value: host
                }
            }
        }
    };
}

const registerHomeToRentHost = 'https://register-home-to-rent.communities.gov.uk';
const searchLandlordHomeInformationHost = 'https://search-landlord-home-information.communities.gov.uk';
const registerRentalPropertyHost = 'https://register-rental-property.communities.gov.uk';
const checkRentalPropertyOrLandlordHost = 'https://check-rental-property-or-landlord.communities.gov.uk';