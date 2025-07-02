const rewire = require('babel-plugin-rewire');
const test = require("node:test");
const assert = require("node:assert");


const url_rewriter = rewire('../../terraform/modules/frontdoor/url_rewriter.js').__get__('url_rewriter');

test('url_rewriter inserts /landlord into a URL for the register-home-to-rent domain', () => {
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
        assert.equal(new_uri,'https://integration.register-home-to-rent.test.communities.gov.uk/landlord/dashboard');
})
