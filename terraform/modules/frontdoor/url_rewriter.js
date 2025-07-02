function url_rewriter(event) {
    const exceptions = ["landlord", "local-authority", "sign-out", "error", "assets"];
    const request = event.request;
    const pathSegments = request.uri.split('/');

    const domainSegmentIndex = pathSegments.findIndex(segment => segment.includes(".gov.uk"));

    // Do not allow /local-authority endpoints to be requested from "register-home-to-rent" or /landlord endpoints to be requested from "search-landlord-home-information"
    if ((pathSegments[domainSegmentIndex].includes("register-home-to-rent") && pathSegments[domainSegmentIndex+1] === "local-authority") ||
        (pathSegments[domainSegmentIndex].includes("search-landlord-home-information") && pathSegments[domainSegmentIndex+1] === "landlord")) {
        pathSegments.splice(domainSegmentIndex+1,1);
    }

    if (exceptions.includes(pathSegments[domainSegmentIndex+1])) {
        // If the first segment after the domain is one of the specified paths, return the request as is
        return request;
    }

    if (pathSegments[domainSegmentIndex].includes("register-home-to-rent")) {
        pathSegments.splice(domainSegmentIndex+1,0,"landlord");
    }

    if (pathSegments[domainSegmentIndex].includes("search-landlord-home-information")) {
        pathSegments.splice(domainSegmentIndex+1,0,"local-authority");
    }

    request.uri = pathSegments.join('/');
    return request
}

