import Foundation

// TEMPORARY: file logging to diagnose the microphone flow.
enum DebugLog {
    static let path = "/private/tmp/claude-501/-Users-keyaanvegdani-Documents-htn-2026/fc1224e2-b230-4c9c-9871-eb87284f56bc/scratchpad/flow.log"
    private static let start = Date()
    private static let lock = NSLock()
    static func write(_ s: String) {
        lock.lock(); defer { lock.unlock() }
        if !FileManager.default.fileExists(atPath: path) { FileManager.default.createFile(atPath: path, contents: nil) }
        let line = String(format: "[%6.2f] ", Date().timeIntervalSince(start)) + s + "\n"
        if let h = FileHandle(forWritingAtPath: path) { h.seekToEndOfFile(); h.write(line.data(using: .utf8)!); try? h.close() }
    }
}
