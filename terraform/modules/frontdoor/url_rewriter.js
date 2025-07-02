function url_rewriter(event) {
    const exceptions = ["landlord", "local-authority", "sign-out", "error", "assets"];
    const request = event.request;
    let pathSegments = request.uri.split('/');
    const domainSegmentIndex = pathSegments.findIndex(segment => segment.includes(".gov.uk"));

    pathSegments = remove_service_segment_if_invalid_for_domain(pathSegments, domainSegmentIndex);

    if (exceptions.includes(pathSegments[domainSegmentIndex+1])) {
        // If the first segment after the domain is one of the excluded paths, return the request as is
        return request;
    }

    pathSegments = insert_service_segment_for_domain(pathSegments, domainSegmentIndex);

    request.uri = pathSegments.join('/');
    return request
}

function remove_service_segment_if_invalid_for_domain(pathSegments, domainSegmentIndex) {
    if ((pathSegments[domainSegmentIndex].includes("register-home-to-rent") && pathSegments[domainSegmentIndex+1] === "local-authority") ||
        (pathSegments[domainSegmentIndex].includes("search-landlord-home-information") && pathSegments[domainSegmentIndex+1] === "landlord")) {
        pathSegments.splice(domainSegmentIndex+1,1);
    }
    return pathSegments;
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