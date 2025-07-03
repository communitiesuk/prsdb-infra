const rewire = require('rewire');
const url_rewriter = rewire('../../terraform/modules/frontdoor/url_rewriter.js').__get__('url_rewriter');

describe('url_rewriter', () => {
    it('returns the original url for a URL that does not include .gov.uk in the domain', () => {
        // given
        const event = {
            request: {
                method: 'GET',
                uri: 'www.not-a-gov-domain.com/dashboard'
            }
        };

        // when
        const new_uri = url_rewriter(event).uri;

        // then
        expect(new_uri).toBe('www.not-a-gov-domain.com/dashboard');
    });

    it('returns the original url for a URL that does includes .gov.uk in the domain but is not one of our services', () => {
        // given
        const event = {
            request: {
                method: 'GET',
                uri: 'www.another-gov-service.gov.uk/dashboard'
            }
        };

        // when
        const new_uri = url_rewriter(event).uri;

        // then
        expect(new_uri).toBe('www.another-gov-service.gov.uk/dashboard');
    });

    describe('for the register-home-to-rent domain', () => {
        it('inserts /landlord into the dashboard URL', () => {
            // given
            const event = {
                request: {
                    method: 'GET',
                    uri: 'https://integration.register-home-to-rent.test.communities.gov.uk/dashboard'
                }
            };

            // when
            const new_uri = url_rewriter(event).uri;

            // then
            expect(new_uri).toBe('https://integration.register-home-to-rent.test.communities.gov.uk/landlord/dashboard');
        });

        it('can insert /landlord into a URL for any domain that includes register-home-to-rent and .gov.uk', () => {
            // given
            const event = {
                request: {
                    method: 'GET',
                    uri: 'register-home-to-rent.gov.uk'
                }
            };

            // when
            const new_uri = url_rewriter(event).uri;

            // then
            expect(new_uri).toBe('register-home-to-rent.gov.uk/landlord');
        });

        it('returns the original url for the /signout endpoint', () => {
            // given
            const event = {
                request: {
                    method: 'GET',
                    uri: 'https://register-home-to-rent.communities.gov.uk/signout'
                }
            };

            // when
            const new_uri = url_rewriter(event).uri;

            // then
            expect(new_uri).toBe('https://register-home-to-rent.communities.gov.uk/signout');
        });

        it('returns the original url for the /confirm-sign-out endpoint', () => {
            // given
            const event = {
                request: {
                    method: 'GET',
                    uri: 'https://register-home-to-rent.communities.gov.uk/confirm-sign-out'
                }
            };

            // when
            const new_uri = url_rewriter(event).uri;

            // then
            expect(new_uri).toBe('https://register-home-to-rent.communities.gov.uk/confirm-sign-out');
        });

        it('returns the original url for the /error/* endpoint', () => {
            // given
            const event = {
                request: {
                    method: 'GET',
                    uri: 'https://register-home-to-rent.communities.gov.uk/error/some-error'
                }
            };

            // when
            const new_uri = url_rewriter(event).uri;

            // then
            expect(new_uri).toBe('https://register-home-to-rent.communities.gov.uk/error/some-error');
        });

        it('returns the original url for the /assets endpoint', () => {
            // given
            const event = {
                request: {
                    method: 'GET',
                    uri: 'https://register-home-to-rent.communities.gov.uk/assets'
                }
            };

            // when
            const new_uri = url_rewriter(event).uri;

            // then
            expect(new_uri).toBe('https://register-home-to-rent.communities.gov.uk/assets');
        });

        it('returns the original url if the first path segment after the domain is already /landlord', () => {
            // given
            const event = {
                request: {
                    method: 'GET',
                    uri: 'https://register-home-to-rent.communities.gov.uk/landlord/dashboard'
                }
            };

            // when
            const new_uri = url_rewriter(event).uri;

            // then
            expect(new_uri).toBe('https://register-home-to-rent.communities.gov.uk/landlord/dashboard');
        });

        it('inserts /landlord into a URL where the first path segment is /local-authority', () => {
            // given
            const event = {
                request: {
                    method: 'GET',
                    uri: 'https://register-home-to-rent.communities.gov.uk/local-authority/dashboard'
                }
            };

            // when
            const new_uri = url_rewriter(event).uri;

            // then
            expect(new_uri).toBe('https://register-home-to-rent.communities.gov.uk/landlord/local-authority/dashboard');
        });
    });

    describe('for the search-landlord-home-information domain', () => {
        it('inserts /local-authority into the dashboard URL', () => {
            // given
            const event = {
                request: {
                    method: 'GET',
                    uri: 'https://integration.search-landlord-home-information.communities.gov.uk/dashboard'
                }
            };

            // when
            const new_uri = url_rewriter(event).uri;

            // then
            expect(new_uri).toBe('https://integration.search-landlord-home-information.communities.gov.uk/local-authority/dashboard');
        });

        it('can insert /local-authority into a URL for any domain that includes search-landlord-home-information and .gov.uk', () => {
            // given
            const event = {
                request: {
                    method: 'GET',
                    uri: 'search-landlord-home-information.gov.uk'
                }
            };

            // when
            const new_uri = url_rewriter(event).uri;

            // then
            expect(new_uri).toBe('search-landlord-home-information.gov.uk/local-authority');
        });

        it('returns the original url for the /signout endpoint', () => {
            // given
            const event = {
                request: {
                    method: 'GET',
                    uri: 'https://search-landlord-home-information.communities.gov.uk/signout'
                }
            };

            // when
            const new_uri = url_rewriter(event).uri;

            // then
            expect(new_uri).toBe('https://search-landlord-home-information.communities.gov.uk/signout');
        });

        it('returns the original url for the /confirm-sign-out endpoint', () => {
            // given
            const event = {
                request: {
                    method: 'GET',
                    uri: 'https://search-landlord-home-information.communities.gov.uk/confirm-sign-out'
                }
            };

            // when
            const new_uri = url_rewriter(event).uri;

            // then
            expect(new_uri).toBe('https://search-landlord-home-information.communities.gov.uk/confirm-sign-out');
        });

        it('returns the original url for the /error/* endpoint', () => {
            // given
            const event = {
                request: {
                    method: 'GET',
                    uri: 'https://search-landlord-home-information.communities.gov.uk/error/some-error'
                }
            };

            // when
            const new_uri = url_rewriter(event).uri;

            // then
            expect(new_uri).toBe('https://search-landlord-home-information.communities.gov.uk/error/some-error');
        });

        it('returns the original url for the /assets endpoint', () => {
            // given
            const event = {
                request: {
                    method: 'GET',
                    uri: 'https://search-landlord-home-information.communities.gov.uk/assets'
                }
            };

            // when
            const new_uri = url_rewriter(event).uri;

            // then
            expect(new_uri).toBe('https://search-landlord-home-information.communities.gov.uk/assets');
        });

        it('returns the original url if the first path segment after the domain is already /local-authority', () => {
            // given
            const event = {
                request: {
                    method: 'GET',
                    uri: 'https://search-landlord-home-information.communities.gov.uk/local-authority/dashboard'
                }
            };

            // when
            const new_uri = url_rewriter(event).uri;

            // then
            expect(new_uri).toBe('https://search-landlord-home-information.communities.gov.uk/local-authority/dashboard');
        });

        it('inserts /local-authority into a URL where the first path segment is /landlord', () => {
            // given
            const event = {
                request: {
                    method: 'GET',
                    uri: 'https://search-landlord-home-information.communities.gov.uk/landlord/dashboard'
                }
            };

            // when
            const new_uri = url_rewriter(event).uri;

            // then
            expect(new_uri).toBe('https://search-landlord-home-information.communities.gov.uk/local-authority/landlord/dashboard');
        });
    });
});
