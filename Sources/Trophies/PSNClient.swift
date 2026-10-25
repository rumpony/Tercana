import Foundation

enum PSNError: LocalizedError {
    case notSignedIn
    case badSessionToken
    case expiredLogin
    case server(Int)

    var errorDescription: String? {
        switch self {
        case .notSignedIn: return S.psnNotSignedIn
        case .badSessionToken: return S.psnBadToken
        case .expiredLogin: return S.psnExpired
        case .server(let code): return S.psnServer(code)
        }
    }
}

/// Read-only client for the PlayStation Network trophy and presence endpoints used by Sony's
/// mobile app. Signing in exchanges the browser session token (NPSSO) for OAuth tokens once;
/// after that only the refresh token is used.
///
/// The endpoints are unofficial, so requests are spaced out and cached to stay well below
/// anything that could look like abuse on the account.
actor PSNClient {
    static let shared = PSNClient()

    private static let authBase = "https://ca.account.sony.com/api/authz/v3/oauth"
    private static let apiBase = "https://m.np.playstation.com/api"
    private static let clientID = "09515159-7237-4370-9b40-3806e67c0891"
    private static let clientAuth = "Basic MDk1MTUxNTktNzIzNy00MzcwLTliNDAtMzgwNmU2N2MwODkxOnVjUGprYTV0bnRCMktxc1A="
    private static let redirectURI = "com.scee.psxandroid.scecompcall://redirect"
    private static let scope = "psn:mobile.v2.core psn:clientapp"
    /// Where the user fetches their NPSSO after logging in on playstation.com.
    static let sessionTokenURL = URL(string: "https://ca.account.sony.com/api/v1/ssocookie")!

    private var accessToken: String?
    private var accessExpiry = Date.distantPast
    private var lastRequest = Date.distantPast
    private var cache: [String: (Date, Data)] = [:]
    private let session: URLSession

    init() {
        let config = URLSessionConfiguration.ephemeral
        config.httpShouldSetCookies = false
        config.timeoutIntervalForRequest = 20
        session = URLSession(configuration: config, delegate: NoRedirects(), delegateQueue: nil)
    }

    var isSignedIn: Bool { SecureStore.string(for: Keys.refreshToken) != nil }

    // MARK: Sign-in

    func signIn(sessionToken npsso: String) async throws {
        var components = URLComponents(string: "\(Self.authBase)/authorize")!
        components.queryItems = [
            URLQueryItem(name: "access_type", value: "offline"),
            URLQueryItem(name: "client_id", value: Self.clientID),
            URLQueryItem(name: "redirect_uri", value: Self.redirectURI),
            URLQueryItem(name: "response_type", value: "code"),
            URLQueryItem(name: "scope", value: Self.scope),
        ]
        var request = URLRequest(url: components.url!)
        request.setValue("npsso=\(npsso.trimmingCharacters(in: .whitespacesAndNewlines))", forHTTPHeaderField: "Cookie")
        let (_, response) = try await session.data(for: request)
        // Sony answers with a redirect whose query carries the one-time code.
        guard let location = (response as? HTTPURLResponse)?.value(forHTTPHeaderField: "Location"),
              let code = URLComponents(string: location)?.queryItems?.first(where: { $0.name == "code" })?.value
        else { throw PSNError.badSessionToken }

        try await requestTokens([
            "code": code,
            "redirect_uri": Self.redirectURI,
            "grant_type": "authorization_code",
            "token_format": "jwt",
        ])
    }

    func signOut() {
        SecureStore.set(nil, for: Keys.refreshToken)
        SecureStore.set(nil, for: Keys.accountID)
        accessToken = nil
        accessExpiry = .distantPast
        cache.removeAll()
    }

    // MARK: Trophies

    func games() async throws -> [TrophyGame] {
        var all: [TrophyGame] = []
        var offset = 0
        repeat {
            let page: TrophyGamesPage = try await get("/trophy/v1/users/me/trophyTitles",
                                                      query: ["limit": "200", "offset": "\(offset)"], ttl: 300)
            all += page.trophyTitles
            guard let next = page.nextOffset, next > offset, all.count < page.totalItemCount else { break }
            offset = next
        } while true
        return all
    }

    func trophies(for game: TrophyGame) async throws -> [Trophy] {
        let service = ["npServiceName": game.npServiceName]
        let definitions: TrophyDefinitionsPayload = try await get(
            "/trophy/v1/npCommunicationIds/\(game.npCommunicationId)/trophyGroups/all/trophies",
            query: service, ttl: 3600)
        let progress: TrophyProgressPayload = try await get(
            "/trophy/v1/users/me/npCommunicationIds/\(game.npCommunicationId)/trophyGroups/all/trophies",
            query: service, ttl: 120)
        let byID = Dictionary(progress.trophies.map { ($0.trophyId, $0) }, uniquingKeysWith: { a, _ in a })
        let dateParser = ISO8601DateFormatter()
        return definitions.trophies.map { item in
            var trophy = Trophy(id: item.trophyId, name: item.trophyName ?? S.hiddenTrophy,
                                detail: item.trophyDetail ?? "", grade: item.trophyType,
                                hidden: item.trophyHidden ?? false,
                                iconURL: item.trophyIconUrl.flatMap(URL.init(string:)),
                                groupId: item.trophyGroupId)
            if let mine = byID[item.trophyId] {
                trophy.earned = mine.earned ?? false
                trophy.earnedDate = mine.earnedDateTime.flatMap(dateParser.date(from:))
                trophy.earnedRate = mine.trophyEarnedRate.flatMap(Double.init)
                trophy.progress = mine.progress
                trophy.progressTarget = mine.trophyProgressTargetValue
            }
            return trophy
        }
    }

    /// Name of the game the player is in right now, if PSN reports one.
    func currentGameName() async throws -> String? {
        let accountID = try await accountID()
        let presence: PresencePayload = try await get(
            "/userProfile/v1/internal/users/\(accountID)/basicPresences", query: ["type": "primary"], ttl: 60)
        return presence.basicPresence.gameTitleInfoList?.first?.titleName
    }

    // MARK: Plumbing

    private func accountID() async throws -> String {
        if let saved = SecureStore.string(for: Keys.accountID) { return saved }
        let token = try await validAccessToken()
        // The access token is a JWT whose payload carries the numeric account id.
        let parts = token.split(separator: ".")
        guard parts.count > 1, let payload = Data(base64URL: String(parts[1])),
              let json = try? JSONSerialization.jsonObject(with: payload) as? [String: Any],
              let id = (json["account_id"] ?? json["sub"]).map({ "\($0)" }) else { throw PSNError.server(0) }
        SecureStore.set(id, for: Keys.accountID)
        return id
    }

    private func get<T: Decodable>(_ path: String, query: [String: String], ttl: TimeInterval) async throws -> T {
        var components = URLComponents(string: Self.apiBase + path)!
        components.queryItems = query.sorted { $0.key < $1.key }.map { URLQueryItem(name: $0.key, value: $0.value) }
        let url = components.url!
        // Sony returns trophy names and descriptions in the requested language when the game has them.
        let language = AppLanguage.current.resolved.rawValue
        let cacheKey = "\(language)|\(url.absoluteString)"
        if let (stamp, data) = cache[cacheKey], Date().timeIntervalSince(stamp) < ttl {
            return try JSONDecoder().decode(T.self, from: data)
        }

        // At most one request per second.
        let wait = 1 - Date().timeIntervalSince(lastRequest)
        if wait > 0 { try await Task.sleep(for: .seconds(wait)) }
        lastRequest = Date()

        var request = URLRequest(url: url)
        request.setValue("Bearer \(try await validAccessToken())", forHTTPHeaderField: "Authorization")
        request.setValue(language, forHTTPHeaderField: "Accept-Language")
        let (data, response) = try await session.data(for: request)
        let status = (response as? HTTPURLResponse)?.statusCode ?? 0
        if status == 401 {
            accessToken = nil
            throw PSNError.expiredLogin
        }
        guard (200..<300).contains(status) else { throw PSNError.server(status) }
        cache[cacheKey] = (Date(), data)
        return try JSONDecoder().decode(T.self, from: data)
    }

    private func validAccessToken() async throws -> String {
        if let accessToken, accessExpiry > Date().addingTimeInterval(60) { return accessToken }
        guard let refresh = SecureStore.string(for: Keys.refreshToken) else { throw PSNError.notSignedIn }
        do {
            try await requestTokens([
                "refresh_token": refresh,
                "grant_type": "refresh_token",
                "token_format": "jwt",
                "scope": Self.scope,
            ])
        } catch {
            throw PSNError.expiredLogin
        }
        guard let accessToken else { throw PSNError.expiredLogin }
        return accessToken
    }

    private func requestTokens(_ form: [String: String]) async throws {
        var request = URLRequest(url: URL(string: "\(Self.authBase)/token")!)
        request.httpMethod = "POST"
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        request.setValue(Self.clientAuth, forHTTPHeaderField: "Authorization")
        var body = URLComponents()
        body.queryItems = form.map { URLQueryItem(name: $0.key, value: $0.value) }
        request.httpBody = body.percentEncodedQuery?.data(using: .utf8)

        let (data, response) = try await session.data(for: request)
        guard (response as? HTTPURLResponse)?.statusCode == 200 else { throw PSNError.badSessionToken }
        struct Tokens: Decodable {
            let access_token: String
            let expires_in: Double
            let refresh_token: String?
        }
        let tokens = try JSONDecoder().decode(Tokens.self, from: data)
        accessToken = tokens.access_token
        accessExpiry = Date().addingTimeInterval(tokens.expires_in)
        if let refresh = tokens.refresh_token { SecureStore.set(refresh, for: Keys.refreshToken) }
    }

    private enum Keys {
        static let refreshToken = "psn.refreshToken"
        static let accountID = "psn.accountID"
    }
}

/// Lets the sign-in step read the redirect instead of following it to the app-only URL scheme.
private final class NoRedirects: NSObject, URLSessionTaskDelegate {
    func urlSession(_ session: URLSession, task: URLSessionTask,
                    willPerformHTTPRedirection response: HTTPURLResponse,
                    newRequest request: URLRequest) async -> URLRequest? {
        nil
    }
}

private extension Data {
    init?(base64URL: String) {
        var text = base64URL.replacingOccurrences(of: "-", with: "+").replacingOccurrences(of: "_", with: "/")
        text += String(repeating: "=", count: (4 - text.count % 4) % 4)
        self.init(base64Encoded: text)
    }
}
