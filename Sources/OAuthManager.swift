import Foundation
import Security
import AppKit

class OAuthManager {
    static let shared = OAuthManager()

    private let clientID = Secrets.googleClientID
    private let clientSecret = Secrets.googleClientSecret
    private let redirectURI = "http://localhost:8080/oauth/callback"
    private let scope = "https://www.googleapis.com/auth/calendar.readonly"

    private let keychainService = "com.calendarbarapp.oauth"
    private let accessTokenKey = "accessToken"
    private let refreshTokenKey = "refreshToken"

    private var localServer: HTTPServer?

    // MARK: - OAuth Flow

    func startOAuthFlow(completion: @escaping (Bool) -> Void) {
        // Start local HTTP server to receive callback
        localServer = HTTPServer(port: 8080) { [weak self] code in
            self?.handleAuthorizationCode(code, completion: completion)
        }

        localServer?.start()

        // Build OAuth URL
        let authURL = buildAuthorizationURL()

        // Open browser for user to log in
        NSWorkspace.shared.open(authURL)
    }

    private func buildAuthorizationURL() -> URL {
        var components = URLComponents(string: "https://accounts.google.com/o/oauth2/v2/auth")!
        components.queryItems = [
            URLQueryItem(name: "client_id", value: clientID),
            URLQueryItem(name: "redirect_uri", value: redirectURI),
            URLQueryItem(name: "response_type", value: "code"),
            URLQueryItem(name: "scope", value: scope),
            URLQueryItem(name: "access_type", value: "offline"),
            URLQueryItem(name: "prompt", value: "consent")
        ]
        return components.url!
    }

    private func handleAuthorizationCode(_ code: String, completion: @escaping (Bool) -> Void) {
        NSLog("📝 Received authorization code: \(code.prefix(10))...")

        // Exchange code for tokens
        exchangeCodeForTokens(code) { [weak self] success in
            self?.localServer?.stop()
            completion(success)
        }
    }

    private func exchangeCodeForTokens(_ code: String, completion: @escaping (Bool) -> Void) {
        let tokenURL = URL(string: "https://oauth2.googleapis.com/token")!
        var request = URLRequest(url: tokenURL)
        request.httpMethod = "POST"
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")

        let bodyParams = [
            "code": code,
            "client_id": clientID,
            "client_secret": clientSecret,
            "redirect_uri": redirectURI,
            "grant_type": "authorization_code"
        ]

        request.httpBody = bodyParams.map { "\($0.key)=\($0.value)" }
            .joined(separator: "&")
            .data(using: .utf8)

        URLSession.shared.dataTask(with: request) { [weak self] data, response, error in
            guard let data = data, error == nil else {
                NSLog("❌ Token exchange error: \(error?.localizedDescription ?? "Unknown")")
                completion(false)
                return
            }

            do {
                if let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
                   let accessToken = json["access_token"] as? String,
                   let refreshToken = json["refresh_token"] as? String {

                    NSLog("✅ Tokens received successfully")
                    self?.saveTokens(accessToken: accessToken, refreshToken: refreshToken)
                    completion(true)
                } else {
                    NSLog("❌ Failed to parse tokens: \(String(data: data, encoding: .utf8) ?? "")")
                    completion(false)
                }
            } catch {
                NSLog("❌ JSON parsing error: \(error.localizedDescription)")
                completion(false)
            }
        }.resume()
    }

    // MARK: - Token Storage (UserDefaults - no keychain prompts)

    private func saveTokens(accessToken: String, refreshToken: String) {
        UserDefaults.standard.set(accessToken, forKey: accessTokenKey)
        UserDefaults.standard.set(refreshToken, forKey: refreshTokenKey)
    }

    func getAccessToken() -> String? {
        return UserDefaults.standard.string(forKey: accessTokenKey)
    }

    private func getRefreshToken() -> String? {
        return UserDefaults.standard.string(forKey: refreshTokenKey)
    }

    func hasValidTokens() -> Bool {
        return getAccessToken() != nil
    }

    func clearTokens() {
        UserDefaults.standard.removeObject(forKey: accessTokenKey)
        UserDefaults.standard.removeObject(forKey: refreshTokenKey)
        NSLog("🗑️ Tokens cleared from UserDefaults")
    }

    func refreshAccessToken(completion: @escaping (Bool) -> Void) {
        guard let refreshToken = getRefreshToken() else {
            completion(false)
            return
        }

        let tokenURL = URL(string: "https://oauth2.googleapis.com/token")!
        var request = URLRequest(url: tokenURL)
        request.httpMethod = "POST"
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")

        let bodyParams = [
            "client_id": clientID,
            "client_secret": clientSecret,
            "refresh_token": refreshToken,
            "grant_type": "refresh_token"
        ]

        request.httpBody = bodyParams.map { "\($0.key)=\($0.value)" }
            .joined(separator: "&")
            .data(using: .utf8)

        URLSession.shared.dataTask(with: request) { [weak self] data, response, error in
            guard let data = data, error == nil else {
                completion(false)
                return
            }

            do {
                if let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
                   let accessToken = json["access_token"] as? String {
                    UserDefaults.standard.set(accessToken, forKey: self?.accessTokenKey ?? "")
                    completion(true)
                } else {
                    completion(false)
                }
            } catch {
                completion(false)
            }
        }.resume()
    }
}

// MARK: - Simple HTTP Server for OAuth Callback

class HTTPServer {
    private var serverSocket: Int32 = -1
    private let port: UInt16
    private var isRunning = false
    private let callback: (String) -> Void

    init(port: UInt16, callback: @escaping (String) -> Void) {
        self.port = port
        self.callback = callback
    }

    func start() {
        DispatchQueue.global(qos: .background).async { [weak self] in
            self?.runServer()
        }
    }

    func stop() {
        isRunning = false
        if serverSocket >= 0 {
            close(serverSocket)
            serverSocket = -1
        }
    }

    private func runServer() {
        serverSocket = socket(AF_INET, SOCK_STREAM, 0)
        guard serverSocket >= 0 else { return }

        var addr = sockaddr_in()
        addr.sin_family = sa_family_t(AF_INET)
        addr.sin_port = port.bigEndian
        addr.sin_addr.s_addr = INADDR_ANY.bigEndian

        let bindResult = withUnsafePointer(to: &addr) {
            $0.withMemoryRebound(to: sockaddr.self, capacity: 1) {
                bind(serverSocket, $0, socklen_t(MemoryLayout<sockaddr_in>.size))
            }
        }

        guard bindResult >= 0 else {
            close(serverSocket)
            return
        }

        listen(serverSocket, 5)
        isRunning = true
        NSLog("🌐 OAuth callback server listening on port \(port)")

        while isRunning {
            let clientSocket = accept(serverSocket, nil, nil)
            guard clientSocket >= 0 else { continue }

            handleClient(socket: clientSocket)
            close(clientSocket)
            break
        }
    }

    private func handleClient(socket: Int32) {
        var buffer = [UInt8](repeating: 0, count: 4096)
        let bytesRead = read(socket, &buffer, buffer.count)

        guard bytesRead > 0,
              let request = String(bytes: buffer[0..<bytesRead], encoding: .utf8) else {
            return
        }

        // Parse authorization code from request
        if let codeRange = request.range(of: "code="),
           let endRange = request[codeRange.upperBound...].range(of: "&") ?? request[codeRange.upperBound...].range(of: " ") {
            let code = String(request[codeRange.upperBound..<endRange.lowerBound])

            // Send success response
            let response = """
            HTTP/1.1 200 OK\r
            Content-Type: text/html; charset=utf-8\r
            \r
            <html><body><h1>✅ Authentication Successful!</h1><p>You can close this window and return to the app.</p></body></html>
            """
            if let data = response.data(using: .utf8) {
                data.withUnsafeBytes {
                    _ = write(socket, $0.baseAddress, data.count)
                }
            }

            callback(code)
        }
    }
}
