# URL Rewriter

url_writer is a cloudfront function that inserts a service path segment (i.e. `/landlord` or `/local-authority`) into the request URL.

We do not currently have automated testing, but the function can be tested on AWS Console (see [documentation here](https://docs.aws.amazon.com/AmazonCloudFront/latest/DeveloperGuide/test-function.html))

## Suggested URIs to check and their expected results

| URI requested                                                                               | Expected output                                                                                        | Notes                                                                       |
|---------------------------------------------------------------------------------------------|--------------------------------------------------------------------------------------------------------|-----------------------------------------------------------------------------|
| https://integration.register-home-to-rent.test.communities.gov.uk/dashboard                 | https://integration.register-home-to-rent.test.communities.gov.uk/landlord/dashboard                   | Landlord dashboard                                                          |
| integration.register-home-to-rent.test.communities.gov.uk/dashboard                         | integration.register-home-to-rent.test.communities.gov.uk/landlord/dashboard                           | Works whether the url scheme is included or not                             |
| https://integration.search-landlord-home-information.test.communities.gov.uk/dashboard      | https://integration.search-landlord-home-information.test.communities.gov.uk/local-authority/dashboard | Local authority dashboard                                                   |
| https://test.search-landlord-home-information.test.communities.gov.uk/dashboard             | https://test.search-landlord-home-information.test.communities.gov.uk/local-authority/dashboard        | Works for any environment                                                   |
| https://test.search-landlord-home-information.gov.uk/dashboard                              | https://test.search-landlord-home-information.gov.uk/local-authority/dashboard                         | Works for modified domain (needs to include .gov.uk)                        |
| https://integration.register-home-to-rent.test.communities/dashboard                        | https://integration.register-home-to-rent.test.communities/dashboard                                   | Returns the original url if the domain does not include .gov.uk             |
| https://integration.register-home-to-rent.test.communities.gov.uk/signout                   | https://integration.register-home-to-rent.test.communities.gov.uk/signout                                     | Returns the original url for excluded endpoints                             |
| https://integration.register-home-to-rent.test.communities.gov.uk/landlord/dashboard        | https://integration.register-home-to-rent.test.communities.gov.uk/landlord/dashboard                          | Returns the original url if the correct service name is already included    |
| https://integration.register-home-to-rent.test.communities.gov.uk/local-authority/dashboard | https://integration.register-home-to-rent.test.communities.gov.uk/landlord/dashboard                          | Attempts to replace an incorrect service name with the correct service name |