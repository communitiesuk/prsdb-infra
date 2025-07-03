const rewire = require('rewire');
const url_rewriter = rewire('../../terraform/modules/frontdoor/url_rewriter.js').__get__('url_rewriter');

describe('url_rewriter', () => {
    it('inserts /landlord into a URL for the register-home-to-rent domain', () => {
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
});
