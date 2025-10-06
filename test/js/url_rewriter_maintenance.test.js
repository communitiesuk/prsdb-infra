const rewire = require('rewire');
const url_rewriter = rewire('../../terraform/modules/frontdoor/url_rewriter_maintenance.js').__get__('handler');

describe('url_rewriter_maintenance', () => {
    it('returns /maintenance for a non-excluded URL', () => {
        const event = {
            request: {
                uri: '/some-path'
            }
        };
        const result = url_rewriter(event);
        expect(result.uri).toBe('/maintenance');
    });

    it('returns original URI for excluded URL "maintenance"', () => {
        const event = {
            request: {
                uri: '/maintenance'
            }
        };
        const result = url_rewriter(event);
        expect(result.uri).toBe('/maintenance');
    });

    it('returns original URI for excluded URL "assets"', () => {
        const event = {
            request: {
                uri: '/assets/image.png'
            }
        };
        const result = url_rewriter(event);
        expect(result.uri).toBe('/assets/image.png');
    });

    it('returns original URI for excluded URL "govuk-frontend-5.11.2.min.css"', () => {
        const event = {
            request: {
                uri: '/govuk-frontend-5.11.2.min.css'
            }
        };
        const result = url_rewriter(event);
        expect(result.uri).toBe('/govuk-frontend-5.11.2.min.css');
    });
});