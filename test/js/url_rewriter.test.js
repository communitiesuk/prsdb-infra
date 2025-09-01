const rewire = require('rewire');
const url_rewriter = rewire('../../terraform/modules/frontdoor/url_rewriter.js').__get__('handler');

describe('url_rewriter', () => {
    it('returns the original url for a URL that does not include one of our domain names', () => {
        // given
        const event = createRequestEvent('www.not-our-service.gov.uk', '/dashboard');

        // when
        const new_event = url_rewriter(event);

        // then
        expect(new_event.headers.host.value + new_event.uri).toBe('www.not-our-service.gov.uk/dashboard');
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