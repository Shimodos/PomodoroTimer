import AVFoundation
import Foundation
import PomodoroCore

/// One entry of the sound list: a built-in file (bare name) or a user file (absolute path).
struct SoundOption: Identifiable, Equatable {
    let file: String
    let isBuiltIn: Bool
    var id: String { file }

    /// Localized display name (`Sound_<stem>`), or "Custom: name.mp3" for user files.
    func name(_ l: Localizer) -> String {
        if isBuiltIn {
            let stem = (file as NSString).deletingPathExtension.lowercased()
            return l.tryGet("Sound_\(stem)") ?? stem
        }
        return l.format("Sound_Custom", (file as NSString).lastPathComponent)
    }
}

/// Port of `Services/SoundService.cs` on AVAudioPlayer: one player, a new play stops the
/// previous one, volume 0…1, WAV and MP3. Missing or broken files are ignored silently.
final class SoundPlayer {
    /// Order of the built-in sounds in the settings list.
    static let order = ["bell.wav", "chime.wav", "ding.wav", "soft.wav", "marimba.wav", "beep.wav", "digital.wav", "alarm.wav"]

    private var player: AVAudioPlayer?
    private let log: (String) -> Void

    init(log: @escaping (String) -> Void = { _ in }) {
        self.log = log
    }

    static var soundsDir: URL {
        (Bundle.main.resourceURL ?? URL(fileURLWithPath: ".")).appendingPathComponent("Sounds", isDirectory: true)
    }

    static func builtIn() -> [SoundOption] {
        let files = (try? FileManager.default.contentsOfDirectory(atPath: soundsDir.path)) ?? []
        return files
            .filter { $0.lowercased().hasSuffix(".wav") }
            .sorted { a, b in
                let ia = order.firstIndex(where: { $0.caseInsensitiveCompare(a) == .orderedSame }) ?? Int.max
                let ib = order.firstIndex(where: { $0.caseInsensitiveCompare(b) == .orderedSame }) ?? Int.max
                return ia != ib ? ia < ib : a < b
            }
            .map { SoundOption(file: $0, isBuiltIn: true) }
    }

    /// Bare name → bundled file; absolute path → as is.
    static func resolve(_ file: String) -> URL {
        file.hasPrefix("/") ? URL(fileURLWithPath: file) : soundsDir.appendingPathComponent(file)
    }

    func play(_ file: String, volume: Double) {
        let url = SoundPlayer.resolve(file)
        guard FileManager.default.fileExists(atPath: url.path) else { return }
        stop()
        do {
            let p = try AVAudioPlayer(contentsOf: url)
            p.volume = Float(min(max(volume, 0), 1))
            p.prepareToPlay()
            p.play()
            player = p
        } catch {
            log("Sound error: \(url.lastPathComponent): \(error.localizedDescription)")
        }
    }

    func stop() {
        player?.stop()
        player = nil
    }
}
