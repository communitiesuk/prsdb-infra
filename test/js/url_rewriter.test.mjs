import assert from 'node:assert/strict';
import { describe, test } from 'node:test';
import {url_rewriter} from '../../terraform/modules/frontdoor/url_rewriter.mjs';

describe('url_rewriter', () => {
    test('inserts /landlord into a URL for the register-home-to-rent domain', () => {
        // given
        const event = {
            request: {
                uri: 'https://integration.register-home-to-rent.test.communities.gov.uk/dashboard'
            }
        };

        // when
        const new_uri = url_rewriter(event).uri;

        // then
        assert.equal(new_uri,'https://integration.register-home-to-rent.test.communities.gov.uk/landlord/dashboard');
    })
})