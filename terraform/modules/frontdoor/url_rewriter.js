function handler(event) {
    const exceptions = ["signout","confirm-sign-out", "error", "assets"];
    const request = event.request;
    let pathSegments = request.uri.split('/');

    let domainSegmentIndex;
    try {
        // Throws an error if ".gov.uk" is not found in the path segments - we expect this in the domain.
        domainSegmentIndex = get_domain_segment_index(pathSegments)
    } catch (error) {
        // Logs the error and returns the request. If the error was uncaught, the client would see a 500 error.
        console.log(`Error: ${error.message} for request URI: ${request.uri}`);
        return request;
    }

    if (!url_should_be_rewritten(pathSegments, domainSegmentIndex, exceptions)) {
        return request;
    }

    pathSegments = insert_service_segment_for_domain(pathSegments, domainSegmentIndex);

    request.uri = pathSegments.join('/');
    return request
}

function insert_service_segment_for_domain(pathSegments, domainSegmentIndex) {
    if (pathSegments[domainSegmentIndex].includes("register-home-to-rent")) {
        pathSegments.splice(domainSegmentIndex+1,0,"landlord");
    }

    if (pathSegments[domainSegmentIndex].includes("search-landlord-home-information")) {
        pathSegments.splice(domainSegmentIndex+1,0,"local-authority");
    }
    return pathSegments;
}

function get_domain_segment_index(pathSegments) {
    const domainSegmentIndex = pathSegments.findIndex(segment => segment.includes(".gov.uk"));
    if (domainSegmentIndex === -1) {
        // If no domain segment is found, return the request as is
        throw new Error(".gov.uk domain segment not found in the request URI");
    }
    return domainSegmentIndex;
}

function url_should_be_rewritten(pathSegments, domainSegmentIndex, exceptions) {
    return !(exceptions.includes(pathSegments[domainSegmentIndex + 1]) ||
        (pathSegments[domainSegmentIndex].includes("register-home-to-rent") && pathSegments[domainSegmentIndex + 1] === "landlord") ||
        (pathSegments[domainSegmentIndex].includes("search-landlord-home-information") && pathSegments[domainSegmentIndex + 1] === "local-authority"));
}