function handler(event) {
    const exceptions = ["maintenance", "assets", "govuk-frontend-5.11.2.min.css"];
    const request = event.request;
    let pathSegments = request.uri.split('/');

    if (exceptions.includes(pathSegments[1])) {
        return request;
    }

    request.uri = '/maintenance';
    return request
}