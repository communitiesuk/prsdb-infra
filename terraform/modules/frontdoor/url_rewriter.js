function handler(event) {
    const exceptions = ["signout","confirm-sign-out", "error", "assets", "id-verification", "logout", "oauth2", "login", "healthcheck", "cookies", "maintenance", ".well-known", "system-operator"];
    const request = event.request;
    const hostName = request.headers.host.value;
    let pathSegments = request.uri.split('/');

    if (!url_should_be_rewritten(pathSegments, hostName, exceptions)) {
        return request;
    }

    pathSegments = insert_service_segment_for_domain(pathSegments, hostName);

    request.uri = pathSegments.join('/');
    return request
}

function is_landlord_domain(hostName) {
    return hostName.includes("register-home-to-rent") || hostName.includes("register-rental-property");
}

function is_local_council_domain(hostName) {
    return hostName.includes("search-landlord-home-information") || hostName.includes("check-rental-property-or-landlord");
}

function insert_service_segment_for_domain(pathSegments, hostName) {
    if (is_landlord_domain(hostName)) {
        pathSegments.splice(1,0,"landlord");
    }

    if (is_local_council_domain(hostName)) {
        pathSegments.splice(1,0,"local-council");
    }
    return pathSegments;
}

function url_should_be_rewritten(pathSegments, hostName, exceptions) {
    return !(exceptions.includes(pathSegments[1]) ||
        (is_landlord_domain(hostName) && pathSegments[1] === "landlord") ||
        (is_local_council_domain(hostName) && pathSegments[1] === "local-council"));
}