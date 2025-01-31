import AVFoundation
import Foundation
import SocketIO

enum PersonaClientEvent: String {
    case messagesUpdate
    case aiSpeechStopped
    case aiSpeechStarted
    case userSpeechStarted
    case userSpeechEnded
    case action
    case stateUpdated
    case snapshot
    case debugEvent
    case connectError
    case disconnected
    case ready
    case error
    case personaState
    case chatDuration
    case conversationData
    case aiSpeechAmplitude
}


public class SindarinSwiftSDK: NSObject, AVAudioPlayerDelegate, AudioRecorderManagerDelegate {
    private var manager: SocketManager?
    private var socket: SocketIOClient?
    private var apiKey: String?
    private var config: [String: Any]?
    private var messages: [[String: Any]] = []
    private var conversationId: String?
    private var audioPlayer: AudioPlayer
    private var audioRecorderManager: AudioRecorderManager

    public override init() {
        self.audioRecorderManager = AudioRecorderManager()
        self.audioPlayer = AudioPlayer()
        super.init()
        self.audioRecorderManager.delegate = self
    }

    private let eventEmitter = EventEmitter()

    public func on(event: String, handler: @escaping (Any?) -> Void) {
        eventEmitter.on(event: event, handler: handler)
    }

    func emit(event: String, data: Any?) {
        eventEmitter.emit(event: event, data: data)
    }

    private func configure(_ config: [String: Any]) {
        guard let url = config["url"] as? String,
            let apiKey = config["apiKey"] as? String
            else {
            print("Invalid configuration")
            return
        }

        self.apiKey = apiKey
        self.config = config

        manager = SocketManager(
            socketURL: URL(string: url)!,
            config: [
                    .log(true),
                    .compress,
                    .reconnects(false),
                    .forceWebsockets(true),
                    .connectParams(["apiKey": apiKey]),
            ])
        self.socket = manager?.defaultSocket

        socket?.on(clientEvent: .connect) { data, ack in
            print("Socket connected")
            self.emit(event: "system", data: ["message": "Socket connected"])
            self.initializeSocket()
        }

        socket?.on(clientEvent: .disconnect) { data, ack in
            print("Socket disconnected")
            self.emit(event: "disconnected", data: nil)
        }

        socket?.on("connect_error") { data, ack in
            print("Socket connect error: \(String(describing: data[0]))")
            self.emitError(event: "connect_error", message: data[0] as? String)
        }

        socket?.on("error") { data, ack in
            print("Socket error: \(String(describing: data[0]))")
            self.emitError(event: "error", message: data[0] as? String)
        }

        socket?.on("init_response") { data, ack in
            self.emit(event: "system", data: ["message": "init_response"])
            self.handleInitResponse(data: data)
        }

        print("Connecting socket...")
        socket?.connect()
    }

    private func initializeSocket() {

        guard let config = self.config else {
            return
        }

        let personaName = config["personaName"] as? String ?? ""
        let personaId = config["personaId"] as? String ?? ""
        let details = config["details"] as? [String: Any] ?? [:]
        let userId = config["userId"] as? String ?? ""
        let metadata = config["metadata"] as? [String: Any] ?? [:]
        let personaConfig = config["personaConfig"] as? [String: Any] ?? [:]
        let options = config["options"] as? [String: Any] ?? [:]

        let inputAudioSampleRate = audioRecorderManager.sampleRate // replace with actual sample rate from your AudioQueueManager

        let initParams: [String: Any] = [
            "apiKey": self.apiKey ?? "",
            "personaName": personaName,
            "personaId": personaId,
            "details": details,
            "userId": userId,
            "metadata": metadata,
            "personaConfig": personaConfig,
            "inputAudioFormat": "pcm",
            "inputAudioSampleRate": inputAudioSampleRate,
            "outputAudioFormat": "mp3",
            "shouldNotSaveConversation": options["shouldNotSaveConversation"] ?? true,
            "debugMode": options["debugMode"] ?? false,
            "streamTranscripts": options["streamTranscripts"] ?? false,
        ]

        socket?.emit("init", initParams)
        self.emit(event: "system", data: ["message": "init"])
    }

    public func initClient(_ config: [String: Any]) {
        self.configure(config)
    }

    public func updateState(_ state: [String: Any]) {
        guard let socket = self.socket else { return }
        socket.emit("update_state", state)
    }

    public func reactTo(_ text: String) {
        guard let socket = self.socket else { return }
        socket.emit("event_text", ["conversationId": self.conversationId, "text": text])
    }

    public func pause() {
        self.audioPlayer.stop()
        self.stopRecording()
        self.emit(event: "system", data: ["message": "pause"])
    }

    public func resume() {
        self.startRecording()
        self.emit(event: "system", data: ["message": "resume"])
    }

    public func end() {
        guard let socket = self.socket else { return }
        socket.disconnect()
        self.socket = nil
        self.messages = []
        self.audioPlayer.stop()
        self.stopRecording()
        self.emit(event: "system", data: ["message": "end"])

    }

//  override func supportedEvents() -> [String]! {
//    return [
//      "connected", "disconnected", "init_response", "temporary_user_transcript",
//      "final_user_transcript", "final_ai_transcript", "system", "ready", "error",
//      "ai_speech_started", "reply_end", "user_speech_started", "user_speech_ended",
//      "ai_speech_stopped", "messages_update", "snapshot",
//    ]
//  }

//  override static func requiresMainQueueSetup() -> Bool {
//    return true
//  }

    private func emitError(event: String, message: String?) {
        self.emit(event: event, data: ["message": message ?? "Unknown error"])
    }

    private func handleInitResponse(data: [Any]) {
        guard let response = data.first as? [String: Any],
            let statusCode = response["statusCode"] as? Int
            else {
            return
        }

        if statusCode == 201 {
            if let res = response["res"] as? [String: Any], let resId = res["id"] as? String {
                self.conversationId = resId
                self.registerSocketEvents()
                self.startRecording()
                self.emit(event: "ready", data: nil)
            } else if let errors = response["errors"] as? [[String: Any]] {
                let errorMessage = errors.map { $0["message"] as? String ?? "" }.joined(separator: ", ")
                self.emitError(event: "error", message: errorMessage)
            } else {
                self.emitError(event: "error", message: "Unknown error 1")
            }
        } else {
            self.emitError(event: "error", message: "Failed to initiate socket")
        }
    }

    private func registerSocketEvents() {
        guard let socket = self.socket else { return }

        socket.on("temporary_user_transcript") { data, ack in
            self.emit(event: "system", data: ["message": "temporary_user_transcript"])

            if let transcript = data[0] as? String, let json = self.convertToDictionary(text: transcript)
            {
                let existingTempMessage = self.messages.first {
                    $0["type"] as? String == "temporary_message" && $0["source"] as? String == "user"
                }
                let existingFinalMessage = self.messages.first {
                    $0["type"] as? String == "message" && $0["source"] as? String == "user"
                        && $0["messageId"] as? String == json["messageId"] as? String
                }

                let didNewTranscriptStartAfterOldTranscript =
                    existingFinalMessage != nil
                    && json["start"] as? Int ?? 0 > (existingFinalMessage?["end"] as? Int ?? 0) - 200
                if let existingFinalMessage = existingFinalMessage, !didNewTranscriptStartAfterOldTranscript
                {
                    self.messages.removeAll {
                        $0["source"] as! String == "user"
                            && $0["messageId"] as! String == json["messageId"] as! String
                    }
                }

                if var tempMessage = existingTempMessage {
                    tempMessage["content"] = json["message"]
                } else {
                    self.messages.append([
                        "source": "user",
                        "type": "temporary_message",
                        "messageId": json["messageId"] as! String,
                        "content": json["message"] as! String,
                        ])
                }

                self.emit(event: "messages_update", data: self.messages)
            }
        }
        socket.on("final_user_transcript") { data, ack in
            self.emit(event: "system", data: ["message": "final_user_transcript"])

            if let transcript = data[0] as? String, let json = self.convertToDictionary(text: transcript)
            {
                self.messages.removeAll {
                    $0["source"] as! String == "user" && $0["type"] as! String == "temporary_message"
                        && $0["messageId"] as! String == json["messageId"] as! String
                }

                let existingMessage = self.messages.first {
                    $0["source"] as! String == "user"
                        && $0["messageId"] as! String == json["messageId"] as! String
                }
                let didNewTranscriptStartAfterOldTranscript =
                    existingMessage != nil
                    && json["start"] as? Int ?? 0 > (existingMessage?["end"] as? Int ?? 0) - 200
                if let existingMessage = existingMessage, !didNewTranscriptStartAfterOldTranscript {
                    self.messages.removeAll {
                        $0["source"] as! String == "user"
                            && $0["messageId"] as! String == json["messageId"] as! String
                    }
                }

                self.messages.append([
                    "source": "user",
                    "type": "message",
                    "messageId": json["messageId"] as! String,
                    "content": json["message"] as! String,
                    "start": json["start"] as! Int,
                    "end": json["end"] as! Int,
                    ])
                self.emit(event: "messages_update", data: self.messages)
            }
        }
        socket.on("final_ai_transcript") { data, ack in
            if let transcript = data[0] as? String, let json = self.convertToDictionary(text: transcript)
            {
                self.messages.append([
                    "source": "ai",
                    "type": "message",
                    "messageId": json["messageId"] as! String,
                    "content": json["message"] as! String,
                    ])
                self.emit(event: "messages_update", data: self.messages)
            }
        }

        socket.on("conversation_trigger") { data, ack in
            if let triggerStr = data[0] as? String, let json = self.convertToDictionary(text: triggerStr)
            {
                if let stopPlaying = json["stop_playing"] as? Bool, stopPlaying {
                    self.emit(event: "ai_speech_stopped", data: nil)
                } else if let startPlaying = json["start_playing"] as? Bool, startPlaying {
                    self.emit(event: "ai_speech_started", data: nil)
                } else if let speechStarted = json["speech_started"] as? Bool, speechStarted {
                    self.emit(event: "user_speech_started", data: nil)
                    print("user_speech_started")
                    self.audioPlayer.stop()
                } else if let speechEnded = json["speech_ended"] as? Bool, speechEnded {
                    self.emit(event: "user_speech_ended", data: nil)
                }
            }
        }

        socket.on("actions") { data, ack in
            if let jsonStr = data[0] as? String, let json = self.convertToDictionary(text: jsonStr) {
                self.emit(event: "action", data: json)
            }
        }

        socket.on("state_updated") { data, ack in
            if let stateStr = data[0] as? String, let json = self.convertToDictionary(text: stateStr) {
                self.emit(event: "state_updated", data: json)
            }
        }

        socket.on("debug_event") { data, ack in
            if let events = data[0] as? String, let json = self.convertToDictionary(text: events) {
                self.emit(event: "debug_event", data: json)
                self.emit(event: "messages_update", data: self.messages)
            }
        }

        socket.on("snapshot") { data, ack in
            if let events = data[0] as? String, let json = self.convertToDictionary(text: events) {
                self.emit(event: "snapshot", data: json)
            }
        }

        socket.on("reply_chunk") { [weak self] data, ack in
            guard let self = self, let chunk = data.first as? Data else { return }
            self.audioPlayer.bufferAudio(chunk: chunk)
        }

        socket.on("reply_end") { data, ack in
            self.emit(event: "reply_end", data: nil)
        }
    }
    private func handleTemporaryUserTranscript(json: [String: Any]) {
        let messageId = json["messageId"] as? String ?? ""
        let messageContent = json["message"] as? String ?? ""
        let start = json["start"] as? Int ?? 0
        let end = json["end"] as? Int ?? 0

        var existingTempMessage: [String: Any]? = nil
        var existingFinalMessage: [String: Any]? = nil

        for message in messages {
            if message["type"] as? String == "temporary_message" && message["source"] as? String == "user"
            {
                existingTempMessage = message
            }
            if message["type"] as? String == "message" && message["source"] as? String == "user"
                && message["messageId"] as? String == messageId
            {
                existingFinalMessage = message
            }
        }

        let didNewTranscriptStartAfterOldTranscript =
            existingFinalMessage != nil && start > (existingFinalMessage!["end"] as! Int - 200)

        if existingFinalMessage != nil {
            if !didNewTranscriptStartAfterOldTranscript {
                messages = messages.filter {
                    !($0["source"] as! String == "user" && $0["messageId"] as! String == messageId)
                }
            }
        }

        if var tempMessage = existingTempMessage {
            tempMessage["content"] = messageContent
        } else {
            self.messages.append([
                "source": "user",
                "type": "temporary_message",
                "messageId": messageId,
                "content": messageContent,
                ])
        }
        self.emit(event: "messages_update", data: self.messages)
    }

    private func convertToDictionary(text: String) -> [String: Any]? {
        if let data = text.data(using: .utf8) {
            return try? JSONSerialization.jsonObject(with: data, options: []) as? [String: Any]
        }
        return nil
    }

    // Setup audio recorder
    func didCaptureAudioChunk(_ data: Data) {
        self.socket?.emit(
            "audio_chunk_continuous",
            [
                "conversationId": self.conversationId ?? "",
                "fileBuffer": data,
            ])
//        print("Sent audio chunk")
    }

    @objc func startRecording() {
        audioRecorderManager.startRecording()
    }

    @objc func stopRecording() {
        audioRecorderManager.stopRecording()
    }

}
