import Foundation
import XCTest

// MARK: - Embedded test certificate + private key
//
// Self-signed RSA-2048 certificate with CN=localhost, valid 10 years.
// Generated with:
//   openssl req -x509 -newkey rsa:2048 -keyout key.pem -out cert.pem \
//               -days 3650 -nodes -subj "/CN=localhost"

let testCertPEM = """
    -----BEGIN CERTIFICATE-----
    MIIDCTCCAfGgAwIBAgIUQrrYp/0HPKNpeNvrKCh8+W+MD74wDQYJKoZIhvcNAQEL
    BQAwFDESMBAGA1UEAwwJbG9jYWxob3N0MB4XDTI2MDMxNTA5NDYyOVoXDTM2MDMx
    MjA5NDYyOVowFDESMBAGA1UEAwwJbG9jYWxob3N0MIIBIjANBgkqhkiG9w0BAQEF
    AAOCAQ8AMIIBCgKCAQEAyj/fQTKtg0I7NXtiPpzBGxXqQqI1/e32ltQICc8QnOBc
    NYEt4mUBrlcMKVnBl+2Zv34r8ddW94JrOAYFewPpOKFtbPQfUZVrXDf3/4fKrdNK
    V+lxmCy/TYmLS8KmKA7nfea3vQIdQqXB7JRq58bp0T5XlZCL1PIcghTE5P0Ud10L
    Q3kO1AOMOS6sBGUP0tknn7HVlHm80CkrtuFhWqihHGh4bZXep2Vsfvw3OKjvVsrg
    /zvXS3X635l/UdmPinMlqGm9HohZNPP4XjrV1n8q1vC7Mqws360eMaKdpWnpA5LL
    UvEhfIRToVZbIAoRb00fLasiSUVAOciarfwRxJAX9wIDAQABo1MwUTAdBgNVHQ4E
    FgQUnOob1ocM6DnQfzoQBi4kdk3nFoowHwYDVR0jBBgwFoAUnOob1ocM6DnQfzoQ
    Bi4kdk3nFoowDwYDVR0TAQH/BAUwAwEB/zANBgkqhkiG9w0BAQsFAAOCAQEAjjQE
    IC9K0lWhqBdJI57qRf3ApgcX63NaXd1lZc0xBSSPdAIjfvAROQNU7vcSUG0b8phG
    sR8YOPwE/tIV1q5uF5oqMbksY4bwdIQes/Ix9GO9iU+D00iO4CQ0ixMXTy0bgKZI
    5M/DadbSefBlBhE0wwAecOcuLS898X1uwtCEq1saogzAUcBbMDNfkogIfZ67ReW9
    ZWu8KzmdetGmzidO/mXV+xSu9hIRf+0L0uMt5RewZbd36WDxRdoxkXBwRIh9Ug1Y
    8vvXAGOqbW+MLy89Nlq/svhYhDCBAXj2WYk6XVbbGh1tB6ot2QZBxFuXNcrdSxhh
    xud3u6JTp6HIHz6Ohw==
    -----END CERTIFICATE-----
    """

let testKeyPEM = """
    -----BEGIN PRIVATE KEY-----
    MIIEvAIBADANBgkqhkiG9w0BAQEFAASCBKYwggSiAgEAAoIBAQDKP99BMq2DQjs1
    e2I+nMEbFepCojX97faW1AgJzxCc4Fw1gS3iZQGuVwwpWcGX7Zm/fivx11b3gms4
    BgV7A+k4oW1s9B9RlWtcN/f/h8qt00pX6XGYLL9NiYtLwqYoDud95re9Ah1CpcHs
    lGrnxunRPleVkIvU8hyCFMTk/RR3XQtDeQ7UA4w5LqwEZQ/S2SefsdWUebzQKSu2
    4WFaqKEcaHhtld6nZWx+/Dc4qO9WyuD/O9dLdfrfmX9R2Y+KcyWoab0eiFk08/he
    OtXWfyrW8LsyrCzfrR4xop2laekDkstS8SF8hFOhVlsgChFvTR8tqyJJRUA5yJqt
    /BHEkBf3AgMBAAECggEAQewex4AOuW1xoiWU6MasVLlIca6wvZN+YDw9YIEbL58b
    vx7bh2MX8K0T3DiS1wQNrLKh/UKM6MEcVJb121pzfs9zPOO3f56d72GY1rP6trzb
    ixseuRTAyDOwcSHBieYNw2Zb9mIFio8/ze60h9a4qMjSwH/sbBz8eNPvN5pcPOlE
    3nQyIVdAe2Guennq0Ico9VeIvpkZXu4w2O7BA0uXSwevRBXXVnwaTxVxLSX8jIbZ
    zv+A8mucwNKXnigiCu9Cqb4Ta6AS6lABawSvtISmX33itP1/RG7qqw8Mybt/BePV
    ge/tenoZ25pen/weYDMfJGIvAQhv/4xzxZ0gZxbkyQKBgQDyK55cUYtWHHgrgwQC
    FUu3dlAGPDBkPpfNIKBGIhm0zuRKBr9vQ1779sadhWIryBP1HQbC0Qgc7jWGMBsE
    oocSYuAv9T4Vv8snnhg9nXUTfu5OwUnaL+JSr57aNg18QyL8ORpXb08olfUwThQh
    Wfp5uhlB+DlZ0HcGxtiKh/Rm6QKBgQDVzKKDtHsgKuNiZ71/AnGffj37ce88wMRM
    hPEkfwACvFilKuvkyjDj13IcgzMvdPSr/27Zsl7fZ+FDMOhDXA6keM2Bd+NtQoPn
    hrMgilX4ZiE1ZSPJVjz6njLpN70zMWzfxIZBsNa0cMr9pcWpRubCuQUtZvdb2bsY
    NqGMNST73wKBgGfjxH0QUnkvn3HzM739Cs16yRvTqGLo41CRpZBQwrxpYVBMksWV
    nmLzXANpnFLx83Xc7PCYoiVfH8EgVAbp/o4pssmAKRFFhU7KqNWN/hLOCkfo7djX
    X/1e8APm2mQrnQ+dI6rMyqW7p0MAy+v+4NBlwL4nUdsw7k8O8QiFCJk5AoGAI4Gs
    q7rZh+oXgUxBSEqbnCVXHd86IBjTgPHDKpB86/djsWqDaqe5nt008k9HvOXrjHUL
    b9QTtX6HBqWkrSsos1/soUfL2WVmipjwPsM6q9oqQbfeTZ2o2uZTBjBfl5Tpw+/b
    bCV2QtlInP9e6FICGOypU3T6N6LdU5QfGC3rSnkCgYBiQuDboCx2prmzQKMB5Ths
    aAUvO2YDs0AUqt6uPFWExPTTAI4UVOaf8rFk51oEU6lQJPV+uHkg+p2Fh2LCGefl
    vRMbsL5gAfrLYQ3EH5OVTRJetWgmLDM1YYx924IZFA0R+58VVT72rLIXLWLBJc4+
    27gtpagsYJVET9nDxGZpfQ==
    -----END PRIVATE KEY-----
    """

// MARK: - Temp-file helpers shared across TLS test classes

extension XCTestCase {
    /// Writes `data` to a uniquely-named file under the system's temp directory.
    func writeTempFile(_ data: Data, name: String) throws -> String {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(name)
        try data.write(to: url)

        return url.path
    }

    /// Writes `string` (UTF-8) to a temp file and returns its path.
    func writeTempFile(string: String, name: String) throws -> String {
        guard let data = string.data(using: .utf8) else {
            throw CocoaError(.fileWriteUnknown)
        }

        return try writeTempFile(data, name: name)
    }

    /// Extracts raw DER bytes from a PEM block and writes them to a temp file.
    ///
    /// PEM is Base64-encoded DER with `-----BEGIN …-----` / `-----END …-----` headers.
    /// Stripping those lines and base64-decoding the remainder yields binary DER.
    func writeDERTempFile(fromPEM pem: String, name: String) throws -> String {
        let b64 = pem
            .components(separatedBy: .newlines)
            .filter { !$0.hasPrefix("-----") && !$0.isEmpty }
            .joined()
        guard let data = Data(base64Encoded: b64) else {
            throw CocoaError(.fileReadCorruptFile)
        }

        return try writeTempFile(data, name: name)
    }
}
