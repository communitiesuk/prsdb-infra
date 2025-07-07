const rewire = require('rewire');
const url_rewriter = rewire('../../terraform/modules/frontdoor/url_rewriter.js').__get__('handler');

describe('url_rewriter', () => {
    it('returns the original url for a URL that does not include one of our domain names', () => {
        // given
        const event = {
            request: {
                method: 'GET',
                uri: '/dashboard',
                headers: {
                    host: {
                        value: 'www.not-our-service.gov.uk'
                    },
                }
            }
        };

        // when
        const new_url = (url_rewriter(event).headers.host.value + url_rewriter(event).uri);

        // then
        expect(new_url).toBe('www.not-our-service.gov.uk/dashboard');
    });

    describe('for the register-home-to-rent domain', () => {
        it('inserts /landlord into the dashboard URL', () => {
            // given
            const event = {
                request: {
                    method: 'GET',
                    uri: '/dashboard',
                    headers: {
                        host: {
                            value: 'https://integration.register-home-to-rent.test.communities.gov.uk'
                        }
                    }
                }
            };

            // when
            const new_url = (url_rewriter(event).headers.host.value + url_rewriter(event).uri);

            // then
            expect(new_url).toBe('https://integration.register-home-to-rent.test.communities.gov.uk/landlord/dashboard');
        });

        it('returns the original url for the /signout endpoint', () => {
            // given
            const event = {
                request: {
                    method: 'GET',
                    uri: '/signout',
                    headers: {
                        host: {
                            value: 'https://register-home-to-rent.communities.gov.uk'
                        }
                    }
                }
            };

            // when
            const new_url = (url_rewriter(event).headers.host.value + url_rewriter(event).uri);

            // then
            expect(new_url).toBe('https://register-home-to-rent.communities.gov.uk/signout');
        });

        it('returns the original url for the /confirm-sign-out endpoint', () => {
            // given
            const event = {
                request: {
                    method: 'GET',
                    uri: '/confirm-sign-out',
                    headers: {
                        host: {
                            value: 'https://register-home-to-rent.communities.gov.uk'
                        }
                    }
                }
            };

            // when
            const new_url = (url_rewriter(event).headers.host.value + url_rewriter(event).uri);

            // then
            expect(new_url).toBe('https://register-home-to-rent.communities.gov.uk/confirm-sign-out');
        });

        it('returns the original url for the /error/* endpoint', () => {
            // given
            const event = {
                request: {
                    method: 'GET',
                    uri: '/error/some-error',
                    headers: {
                        host: {
                            value: 'https://register-home-to-rent.communities.gov.uk'
                        }
                    }
                }
            };

            // when
            const new_url = (url_rewriter(event).headers.host.value + url_rewriter(event).uri);

            // then
            expect(new_url).toBe('https://register-home-to-rent.communities.gov.uk/error/some-error');
        });

        it('returns the original url for the /assets endpoint', () => {
            // given
            const event = {
                request: {
                    method: 'GET',
                    uri: '/assets',
                    headers: {
                        host: {
                            value: 'https://register-home-to-rent.communities.gov.uk'
                        }
                    }
                }
            };

            // when
            const new_url = (url_rewriter(event).headers.host.value + url_rewriter(event).uri);

            // then
            expect(new_url).toBe('https://register-home-to-rent.communities.gov.uk/assets');
        });

        it('returns the original url if the first path segment after the domain is already /landlord', () => {
            // given
            const event = {
                request: {
                    method: 'GET',
                    uri: '/landlord/dashboard',
                    headers: {
                        host: {
                            value: 'https://register-home-to-rent.communities.gov.uk'
                        }
                    }
                }
            };

            // when
            const new_url = (url_rewriter(event).headers.host.value + url_rewriter(event).uri);

            // then
            expect(new_url).toBe('https://register-home-to-rent.communities.gov.uk/landlord/dashboard');
        });

        it('inserts /landlord into a URL where the first path segment is /local-authority', () => {
            // given
            const event = {
                request: {
                    method: 'GET',
                    uri: '/local-authority/dashboard',
                    headers: {
                        host: {
                            value: 'https://register-home-to-rent.communities.gov.uk'
                        }
                    }
                }
            };

            // when
            const new_url = (url_rewriter(event).headers.host.value + url_rewriter(event).uri);

            // then
            expect(new_url).toBe('https://register-home-to-rent.communities.gov.uk/landlord/local-authority/dashboard');
        });
    });

    describe('for the search-landlord-home-information domain', () => {
        it('inserts /local-authority into the dashboard URL', () => {
            // given
            const event = {
                request: {
                    method: 'GET',
                    uri: '/dashboard',
                    headers: {
                        host: {
                            value: 'https://integration.search-landlord-home-information.communities.gov.uk'
                        }
                    }
                }
            };

            // when
            const new_url = (url_rewriter(event).headers.host.value + url_rewriter(event).uri);

            // then
            expect(new_url).toBe('https://integration.search-landlord-home-information.communities.gov.uk/local-authority/dashboard');
        });

        it('returns the original url for the /signout endpoint', () => {
            // given
            const event = {
                request: {
                    method: 'GET',
                    uri: '/signout',
                    headers: {
                        host: {
                            value: 'https://search-landlord-home-information.communities.gov.uk'
                        }
                    }
                }
            };

            // when
            const new_url = (url_rewriter(event).headers.host.value + url_rewriter(event).uri);

            // then
            expect(new_url).toBe('https://search-landlord-home-information.communities.gov.uk/signout');
        });

        it('returns the original url for the /confirm-sign-out endpoint', () => {
            // given
            const event = {
                request: {
                    method: 'GET',
                    uri: '/confirm-sign-out',
                    headers: {
                        host: {
                            value: 'https://search-landlord-home-information.communities.gov.uk'
                        }
                    }
                }
            };

            // when
            const new_url = (url_rewriter(event).headers.host.value + url_rewriter(event).uri);

            // then
            expect(new_url).toBe('https://search-landlord-home-information.communities.gov.uk/confirm-sign-out');
        });

        it('returns the original url for the /error/* endpoint', () => {
            // given
            const event = {
                request: {
                    method: 'GET',
                    uri: '/error/some-error',
                    headers: {
                        host: {
                            value: 'https://search-landlord-home-information.communities.gov.uk'
                        }
                    }
                }
            };

            // when
            const new_url = (url_rewriter(event).headers.host.value + url_rewriter(event).uri);

            // then
            expect(new_url).toBe('https://search-landlord-home-information.communities.gov.uk/error/some-error');
        });

        it('returns the original url for the /assets endpoint', () => {
            // given
            const event = {
                request: {
                    method: 'GET',
                    uri: '/assets',
                    headers: {
                        host: {
                            value: 'https://search-landlord-home-information.communities.gov.uk'
                        }
                    }
                }
            };

            // when
            const new_url = (url_rewriter(event).headers.host.value + url_rewriter(event).uri);

            // then
            expect(new_url).toBe('https://search-landlord-home-information.communities.gov.uk/assets');
        });

        it('returns the original url if the first path segment after the domain is already /local-authority', () => {
            // given
            const event = {
                request: {
                    method: 'GET',
                    uri: '/local-authority/dashboard',
                    headers: {
                        host: {
                            value: 'https://search-landlord-home-information.communities.gov.uk'
                        }
                    }
                }
            };

            // when
            const new_url = (url_rewriter(event).headers.host.value + url_rewriter(event).uri);

            // then
            expect(new_url).toBe('https://search-landlord-home-information.communities.gov.uk/local-authority/dashboard');
        });

        it('inserts /local-authority into a URL where the first path segment is /landlord', () => {
            // given
            const event = {
                request: {
                    method: 'GET',
                    uri: '/landlord/dashboard',
                    headers: {
                        host: {
                            value: 'https://search-landlord-home-information.communities.gov.uk'
                        }
                    }
                }
            };

            // when
            const new_url = (url_rewriter(event).headers.host.value + url_rewriter(event).uri);

            // then
            expect(new_url).toBe('https://search-landlord-home-information.communities.gov.uk/local-authority/landlord/dashboard');
        });
    });
});
