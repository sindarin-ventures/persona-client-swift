import AVFoundation
import Foundation

protocol AudioRecorderManagerDelegate: AnyObject {
  func didCaptureAudioChunk(_ data: Data)
}

class AudioRecorderManager: NSObject, AVAudioRecorderDelegate {
  private var audioRecorder: AVAudioRecorder?
  private var audioSession: AVAudioSession
  private var recordingTimer: Timer?
  private var lastReadPosition: Int64 = 0  // To keep track of the last read position in the file
  weak var delegate: AudioRecorderManagerDelegate?

  override init() {
    self.audioSession = AVAudioSession.sharedInstance()
    super.init()
    setupAudioRecorder()
  }

  private func setupAudioRecorder() {
    let settings =
      [
        AVFormatIDKey: Int(kAudioFormatLinearPCM),
        AVSampleRateKey: 16000,
        AVNumberOfChannelsKey: 1,
        AVEncoderAudioQualityKey: AVAudioQuality.min.rawValue,
      ] as [String: Any]

    do {
      try audioSession.setCategory(.playAndRecord, mode: .default, options: [])
      try audioSession.setActive(true)
      audioRecorder = try AVAudioRecorder(url: self.directoryURL(), settings: settings)
      audioRecorder?.delegate = self
    } catch {
      print("Failed to setup audio recorder: \(error)")
    }
  }

  private func directoryURL() -> URL {
    let fileManager = FileManager.default
    let urls = fileManager.urls(for: .documentDirectory, in: .userDomainMask)
    let documentDirectory = urls.first!
    return documentDirectory.appendingPathComponent("userSpeech.wav")
  }

  func startRecording() {
    audioRecorder?.prepareToRecord()
    audioRecorder?.record()
    startRecordingTimer()
  }

  func stopRecording() {
    audioRecorder?.stop()
    recordingTimer?.invalidate()
    recordingTimer = nil
    lastReadPosition = 0  // Reset the read position
  }

  private func startRecordingTimer() {
    recordingTimer = Timer.scheduledTimer(
      timeInterval: 1.0, target: self, selector: #selector(readAudioChunk), userInfo: nil,
      repeats: true)
  }

  @objc private func readAudioChunk() {
    guard let recorder = audioRecorder, recorder.isRecording else { return }
    let fileHandle: FileHandle
    do {
      fileHandle = try FileHandle(forReadingFrom: self.directoryURL())
      fileHandle.seek(toFileOffset: UInt64(lastReadPosition))
      let data = fileHandle.readDataToEndOfFile()
      fileHandle.closeFile()
      lastReadPosition += Int64(data.count)
      let int16Data = convertTo16BitPcm(data)
      delegate?.didCaptureAudioChunk(int16Data)
      print("Captured audio chunk")
    } catch {
      print("Failed to read audio data: \(error)")
    }
  }

  private func convertTo16BitPcm(_ data: Data) -> Data {
    let audioBuffer = data.withUnsafeBytes {
      Array(
        UnsafeBufferPointer<Int16>(
          start: $0.bindMemory(to: Int16.self).baseAddress!,
          count: data.count / MemoryLayout<Int16>.size))
    }
    return Data(buffer: UnsafeBufferPointer(start: audioBuffer, count: audioBuffer.count))
  }

  // AVAudioRecorderDelegate method
  func audioRecorderDidFinishRecording(_ recorder: AVAudioRecorder, successfully flag: Bool) {
    if flag {
      print("Recording finished successfully")
    }
  }
}
