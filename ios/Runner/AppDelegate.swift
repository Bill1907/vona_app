import Flutter
import UIKit
import AVFoundation

@main
@objc class AppDelegate: FlutterAppDelegate {
  private var audioEngine: AVAudioEngine?
  private var audioTap: MTAudioProcessingTap?
  
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    let controller = window?.rootViewController as! FlutterViewController
    let audioChannel = FlutterMethodChannel(
      name: "com.vona.app/audio_analysis",
      binaryMessenger: controller.binaryMessenger
    )
    
    audioChannel.setMethodCallHandler { [weak self] call, result in
      switch call.method {
      case "startAudioAnalysis":
        self?.startAudioAnalysis(result: result)
      case "stopAudioAnalysis":
        self?.stopAudioAnalysis(result: result)
      case "getAudioLevel":
        self?.getAudioLevel(result: result)
      default:
        result(FlutterMethodNotImplemented)
      }
    }
    
    GeneratedPluginRegistrant.register(with: self)
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }
  
  private func startAudioAnalysis(result: @escaping FlutterResult) {
    audioEngine = AVAudioEngine()
    
    guard let inputNode = audioEngine?.inputNode else {
      result(FlutterError(code: "AUDIO_ERROR",
                        message: "Could not access audio input",
                        details: nil))
      return
    }
    
    let format = inputNode.outputFormat(forBus: 0)
    
    inputNode.installTap(onBus: 0,
                       bufferSize: 1024,
                       format: format) { [weak self] buffer, when in
      self?.processAudioBuffer(buffer)
    }
    
    do {
      try audioEngine?.start()
      result(nil)
    } catch {
      result(FlutterError(code: "AUDIO_ERROR",
                        message: "Could not start audio engine",
                        details: error.localizedDescription))
    }
  }
  
  private func stopAudioAnalysis(result: @escaping FlutterResult) {
    audioEngine?.stop()
    audioEngine?.inputNode.removeTap(onBus: 0)
    audioEngine = nil
    result(nil)
  }
  
  private var currentAudioLevel: Float = 0.0
  
  private func processAudioBuffer(_ buffer: AVAudioPCMBuffer) {
    guard let channelData = buffer.floatChannelData?[0] else { return }
    let frameLength = UInt32(buffer.frameLength)
    
    var sum: Float = 0
    for i in 0..<Int(frameLength) {
      let sample = abs(channelData[i])
      sum += sample
    }
    
    let average = sum / Float(frameLength)
    currentAudioLevel = average
  }
  
  private func getAudioLevel(result: @escaping FlutterResult) {
    result(Double(currentAudioLevel))
  }
}
