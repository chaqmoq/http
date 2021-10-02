public enum HeaderName: String {
    case accept
    case acceptCH = "accept-ch"
    case acceptCHLifetime = "accept-ch-lifetime"
    case acceptCharset = "accept-charset"
    case acceptEncoding = "accept-encoding"
    case acceptLanguage = "accept-language"
    case acceptPatch = "accept-patch"
    case acceptRanges = "accept-ranges"
    case accessControlAllowCredentials = "access-control-allow-credentials"
    case accessControlAllowHeaders = "access-control-allow-headers"
    case accessControlAllowMethods = "access-control-allow-methods"
    case accessControlAllowOrigin = "access-control-allow-origin"
    case accessControlExposeHeaders = "access-control-expose-headers"
    case accessControlMaxAge = "access-control-max-age"
    case accessControlRequestHeaders = "access-control-request-headers"
    case accessControlRequestMethod = "access-control-request-method"
    case age
    case allow
    case altSvc = "alt-svc"
    case authorization
    case cacheControl = "cache-control"
    case clearSiteData = "clear-site-data"
    case connection
    case contentDisposition = "content-disposition"
    case contentEncoding = "content-encoding"
    case contentLanguage = "content-language"
    case contentLength = "content-length"
    case contentLocation = "content-location"
    case contentRange = "content-range"
    case contentSecurityPolicy = "content-security-policy"
    case contentSecurityPolicyReportOnly = "content-security-policy-report-only"
    case contentType = "content-type"
    case cookie
    case crossOriginResourcePolicy = "cross-origin-resource-policy"
    case dnt
    case dpr
    case date
    case deviceMemory = "device-memory"
    case digest
    case eTag = "etag"
    case earlyData = "early-data"
    case expect
    case expectCT = "expect-ct"
    case expires
    case featurePolicy = "feature-policy"
    case forwarded
    case from
    case host
    case ifMatch = "if-match"
    case ifModifiedSince = "if-modified-since"
    case ifNoneMatch = "if-none-match"
    case ifRange = "if-range"
    case ifUnmodifiedSince = "if-unmodified-since"
    case index
    case keepAlive = "keep-alive"
    case largeAllocation = "large-allocation"
    case lastModified = "last-modified"
    case link
    case location
    case origin
    case pragma
    case proxyAuthenticate = "proxy-authenticate"
    case proxyAuthorization = "proxy-authorization"
    case publicKeyPins = "public-key-pins"
    case publicKeyPinsReportOnly = "public-key-pins-report-only"
    case range
    case referer
    case refererPolicy = "referrer-policy"
    case retryAfter = "retry-after"
    case saveData = "save-data"
    case secWebSocketAccept = "sec-websocket-accept"
    case server
    case serverTiming = "server-timing"
    case setCookie = "set-cookie"
    case sourceMap = "sourcemap"
    case strictTransportSecurity = "strict-transport-security"
    case te
    case timingAllowOrigin = "timing-allow-origin"
    case tk
    case trailer
    case transferEncoding = "transfer-encoding"
    case upgradeInsecureRequests = "upgrade-insecure-requests"
    case userAgent = "user-agent"
    case vary
    case via
    case wwwAuthenticate = "www-authenticate"
    case wantDigest = "want-digest"
    case warning
    case xContentTypeOptions = "x-content-type-options"
    case xDNSPrefetchControl = "x-dns-prefetch-control"
    case xForwardedFor = "x-forwarded-for"
    case xForwardedHost = "x-forwarded-host"
    case xForwardedProto = "x-forwarded-proto"
    case xFrameOptions = "x-frame-options"
    case xHTTPMethodOverride = "x-http-method-override"
    case xXSSProtection = "x-xss-protection"
}
