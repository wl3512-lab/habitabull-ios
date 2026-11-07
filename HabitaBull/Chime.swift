//
// the rest bell, the same two rising notes as the web app. it mixes with your
// music and stays quiet when the phone is on silent. when the phone is locked,
// the rest alert plays this same sound

import AVFoundation

enum Chime {
    private static var player: AVAudioPlayer?

    static func play() {
        guard let url = Bundle.main.url(forResource: "chime", withExtension: "wav") else { return }
        try? AVAudioSession.sharedInstance().setCategory(.ambient)
        player = try? AVAudioPlayer(contentsOf: url)
        player?.play()
    }
}
