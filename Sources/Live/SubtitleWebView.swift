import Foundation
import Network

/// Serves the live translation as a web page on the local network, for a phone, tablet or an OBS
/// browser source: http://<this Mac>:8787. Off unless turned on in Settings.
final class SubtitleWebView {
    static let shared = SubtitleWebView()
    static let port: UInt16 = 8787

    private let queue = DispatchQueue(label: "Tercana.SubtitleWebView")
    private var listener: NWListener?
    private var streams: [ObjectIdentifier: NWConnection] = [:]
    private var last = ""

    var isRunning: Bool { listener != nil }

    func setEnabled(_ on: Bool) {
        on ? start() : stop()
    }

    func start() {
        queue.async {
            guard self.listener == nil, let port = NWEndpoint.Port(rawValue: Self.port),
                  let listener = try? NWListener(using: .tcp, on: port) else { return }
            listener.newConnectionHandler = { [weak self] connection in self?.accept(connection) }
            listener.stateUpdateHandler = { state in
                if case .failed(let error) = state { AppLog.write("web view failed: \(error)") }
            }
            listener.start(queue: self.queue)
            self.listener = listener
        }
    }

    func stop() {
        queue.async {
            self.listener?.cancel()
            self.listener = nil
            self.streams.values.forEach { $0.cancel() }
            self.streams.removeAll()
        }
    }

    /// Sends the current subtitle ("" clears it) to every open page.
    func show(_ text: String) {
        queue.async {
            guard text != self.last else { return }
            self.last = text
            let frame = Data(Self.event(text).utf8)
            self.streams.values.forEach { $0.send(content: frame, completion: .contentProcessed { _ in }) }
        }
    }

    /// Addresses a phone on the same network can open.
    static var addresses: [String] {
        var result: [String] = []
        var list: UnsafeMutablePointer<ifaddrs>?
        guard getifaddrs(&list) == 0, let first = list else { return [] }
        defer { freeifaddrs(list) }
        for pointer in sequence(first: first, next: { $0.pointee.ifa_next }) {
            let entry = pointer.pointee
            guard let address = entry.ifa_addr, address.pointee.sa_family == UInt8(AF_INET),
                  (entry.ifa_flags & UInt32(IFF_LOOPBACK)) == 0 else { continue }
            var host = [CChar](repeating: 0, count: Int(NI_MAXHOST))
            if getnameinfo(address, socklen_t(address.pointee.sa_len), &host, socklen_t(host.count), nil, 0, NI_NUMERICHOST) == 0 {
                result.append("http://\(String(cString: host)):\(port)")
            }
        }
        return result
    }

    private static func event(_ text: String) -> String {
        let json = (try? JSONSerialization.data(withJSONObject: ["text": text])).flatMap { String(data: $0, encoding: .utf8) } ?? "{}"
        return "data: \(json)\n\n"
    }

    private func accept(_ connection: NWConnection) {
        connection.start(queue: queue)
        connection.receive(minimumIncompleteLength: 1, maximumLength: 8192) { [weak self] data, _, _, _ in
            guard let self, let data, let request = String(data: data, encoding: .utf8) else { connection.cancel(); return }
            let path = request.split(separator: " ").dropFirst().first.map(String.init) ?? "/"
            if path.hasPrefix("/events") {
                let head = "HTTP/1.1 200 OK\r\nContent-Type: text/event-stream\r\nCache-Control: no-cache\r\nConnection: keep-alive\r\nAccess-Control-Allow-Origin: *\r\n\r\n"
                connection.send(content: Data((head + Self.event(self.last)).utf8), completion: .contentProcessed { _ in })
                let id = ObjectIdentifier(connection)
                self.streams[id] = connection
                connection.stateUpdateHandler = { [weak self] state in
                    switch state {
                    case .failed, .cancelled: self?.queue.async { self?.streams[id] = nil }
                    default: break
                    }
                }
            } else {
                let body = Data(Self.page.utf8)
                let head = "HTTP/1.1 200 OK\r\nContent-Type: text/html; charset=utf-8\r\nContent-Length: \(body.count)\r\nConnection: close\r\n\r\n"
                connection.send(content: Data(head.utf8) + body, completion: .contentProcessed { _ in connection.cancel() })
            }
        }
    }

    /// Transparent background so OBS can lay it over the game; add ?bg=1 for a dark page on a phone.
    private static let page = """
    <!doctype html><html><head><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1">
    <title>Tercana</title><style>
    html,body{margin:0;height:100%;background:transparent;font-family:-apple-system,system-ui,sans-serif}
    body.bg{background:#111}
    #s{position:fixed;left:4%;right:4%;bottom:6%;text-align:center}
    #t{display:inline-block;padding:10px 20px;border-radius:12px;background:rgba(0,0,0,.72);color:#fff;
       font-size:clamp(20px,4.5vw,44px);line-height:1.3;font-weight:600}
    #t:empty{display:none}
    </style></head><body><div id="s"><span id="t"></span></div><script>
    if (location.search.indexOf('bg=1') >= 0) document.body.className = 'bg';
    var t = document.getElementById('t');
    function connect() {
      var es = new EventSource('/events');
      es.onmessage = function (e) { try { t.textContent = JSON.parse(e.data).text || ''; } catch (x) {} };
      es.onerror = function () { es.close(); setTimeout(connect, 2000); };
    }
    connect();
    </script></body></html>
    """
}
