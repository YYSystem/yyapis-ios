//
//  ViewController.swift
//  SampleApp
//
//  Created by Scorbunny on 2023/12/15.
//

import UIKit
import AVFoundation
import GRPC

let SAMPLE_RATE = 16000
let API_KEY = "SET_YOUR_API_KEY"

class ViewController: UIViewController, AudioControllerDelegate {
  private var audioData: NSMutableData!
  private let mainView = UIScrollView()
  private let responsesView = UIStackView()
  private var startButton: UIButton!
  private var stopButton: UIButton!
  let toolbarHeight = 56
  override func viewDidLoad() {
    super.viewDidLoad()
    // Do any additional setup after loading the view.
    AudioController.sharedInstance.delegate = self
    mainView.contentOffset = CGPoint(x: 0, y: 0)
    responsesView.axis = .vertical
    responsesView.spacing = 16
    responsesView.isLayoutMarginsRelativeArrangement = true
    responsesView.layoutMargins = UIEdgeInsets(top: 0, left: 24, bottom: 48, right: 24)
    YyStreamRecognizer.shared.apiKey = API_KEY
    YyStreamRecognizer.shared.onData = { chunk in
      if (chunk.hasError) {
        let error = chunk.error
        print("onData: chunk has error \(error)")
        do {
          try self.stopAudio()
        } catch {
          print ("ViewController(onData): Failed to stopAudio")
        }
        return
      }
      print(chunk.result.transcript)
      DispatchQueue.main.async { [weak self] in
        if let weakSelf = self {
          if weakSelf.responsesView.arrangedSubviews.isEmpty {
            let label = weakSelf.createCustomLabel()
            weakSelf.responsesView.addArrangedSubview(label)
          }
          if chunk.result.transcript.isEmpty {
            print("empty transcript")
            return
          }
          if !chunk.result.isFinal {
            if let lastLabel = weakSelf.responsesView.arrangedSubviews.last as? UILabel {
              lastLabel.text = chunk.result.transcript
              lastLabel.textColor = .secondaryLabel
              let offset = weakSelf.mainView.contentSize.height - weakSelf.mainView.bounds.size.height
              if offset > 0 {
                let bottomOffset = CGPoint(x: 0, y:  offset)
                weakSelf.mainView.setContentOffset(bottomOffset, animated: true)
              }
            }
            return
          }
          if let lastLabel = weakSelf.responsesView.arrangedSubviews.last as? UILabel {
            lastLabel.text = chunk.result.transcript
            lastLabel.textColor = .label
            let offset = weakSelf.mainView.contentSize.height - weakSelf.mainView.bounds.size.height
            if offset > 0 {
              let bottomOffset = CGPoint(x: 0, y:  offset)
              weakSelf.mainView.setContentOffset(bottomOffset, animated: true)
            }
          }
          let label = weakSelf.createCustomLabel()
          weakSelf.responsesView.addArrangedSubview(label)
        }
      }
      return
    }
    YyStreamRecognizer.shared.onError = { error in
//      do {
//        try self.stopAudio()
//      } catch {
//        print ("ViewController onError: stopAudioError \(error)")
//      }
      if let grpcError = error as? GRPCStatus {
        print("onError(GRPCStatus): \(grpcError)")
      } else {
        print("onError: \(error)")
      }
      DispatchQueue.main.async { [weak self] in
        if let weakSelf = self {
          weakSelf.showAlert(alertTitle: "ConnectionError", alertMessage: "\(error)")
        }
      }
    }
    let bottomNavigationView = BottomNavigationView(toolbarHeight: CGFloat(toolbarHeight))
    let bottomNavigationToolbarSpacer = UIView()
    bottomNavigationToolbarSpacer.backgroundColor = .clear
    bottomNavigationToolbarSpacer.autoresizingMask = .flexibleWidth
    var startButtonConfig = UIButton.Configuration.plain()
    startButtonConfig.imageColorTransformer = .init { _ in
      .label
    }
    startButtonConfig.image = UIImage(systemName: "waveform")
    var stopButtonConfig = UIButton.Configuration.filled()
    stopButtonConfig.cornerStyle = .capsule
    stopButtonConfig.image = UIImage(systemName: "waveform")
    let startAction = UIAction(title: "", handler: { [weak self] action in
      print("Start pressed")
      let sender = action.sender
      Task(priority: .medium) {
        if let senderObject = sender as? NSObject {
          await self?.recordAudio(senderObject)
        } else {
          print("Sender is not NSObject")
        }
      }
    })
    let stopAction = UIAction(title: "Recognizing", handler: { [weak self] action in
      print("Stop pressed")
      if let sender = action.sender as? NSObject {
        do {
          try self?.stopAudio(sender)
        } catch {
          print ("Error(stopAudio):,  \(error)")
        }
      } else {
        print("Sender is not NSObject")
      }
    })
    startButton = UIButton(configuration: startButtonConfig, primaryAction: startAction)
    startButton.setContentHuggingPriority(.required, for: .horizontal)
    stopButton = UIButton(configuration: stopButtonConfig, primaryAction: stopAction)
    stopButton.setContentHuggingPriority(.required, for: .horizontal)
    stopButton.isHidden = true
    bottomNavigationView.toolbar.addArrangedSubview(bottomNavigationToolbarSpacer)
    bottomNavigationView.toolbar.addArrangedSubview(startButton)
    bottomNavigationView.toolbar.addArrangedSubview(stopButton)
    mainView.addSubview(responsesView)
    view.addSubview(mainView)
    view.addSubview(bottomNavigationView)
    bottomNavigationView.translatesAutoresizingMaskIntoConstraints = false
    responsesView.translatesAutoresizingMaskIntoConstraints = false
    mainView.translatesAutoresizingMaskIntoConstraints = false
    NSLayoutConstraint.activate([
      bottomNavigationView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -CGFloat(toolbarHeight)),
      bottomNavigationView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
      bottomNavigationView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
      bottomNavigationView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
      mainView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
      mainView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
      mainView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
      mainView.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -CGFloat(toolbarHeight)),
      responsesView.topAnchor.constraint(equalTo: mainView.topAnchor),
      responsesView.widthAnchor.constraint(equalTo: mainView.widthAnchor),
      responsesView.bottomAnchor.constraint(lessThanOrEqualTo: mainView.bottomAnchor),
    ])
  }
  func toggleButtons() {
    DispatchQueue.main.async { [weak self] in
      if let weakSelf = self {
        weakSelf.startButton.isHidden = !weakSelf.startButton.isHidden
        weakSelf.stopButton.isHidden = !weakSelf.stopButton.isHidden
      }
    }
  }
  func processSampleData(_ data: Data) {
    audioData.append(data)
    let chunkSize: Int = Int(0.1 * Double(SAMPLE_RATE)) * 2
    if (audioData.length > chunkSize) {
      Task {
        if (!YyStreamRecognizer.shared.isStreaming()) {
          try await YyStreamRecognizer.shared.send(audioData as Data, streamingConfig: Yysystem_StreamingConfig.with {
            $0.model = 10
            $0.enableInterimResults = true
            $0.sampleRateHertz = Int32(SAMPLE_RATE)
            $0.languageCode = 4
          })
          self.audioData = NSMutableData()
          return
        }
        try await YyStreamRecognizer.shared.send(audioData as Data)
        self.audioData = NSMutableData()
        return
      }
    }
  }
  func requestRecordPermission () async throws {
    //  https://developer.apple.com/documentation/avfaudio/avaudioapplication/4144305-requestrecordpermission
    if #available(iOS 17.0, *) {
      switch AVAudioApplication.shared.recordPermission {
      case .undetermined:
        print("Permission has not been requested yet")
        if await AVAudioApplication.requestRecordPermission() {
          print("Permission is granted")
        } else {
          print("Permission is denied")
          throw NSError(domain: "PermissionError", code: -1, userInfo: ["message": "Record Permission has been denied"])
        }
        break
      case .denied:
        print("Permission has been denied")
        throw NSError(domain: "PermissionError", code: -1, userInfo: ["message": "Record Permission has been denied"])
      case .granted:
        print("Permission is already granted")
        break;
      default:
        break
      }
    } else {
      var isGranted = true
      switch AVAudioSession.sharedInstance().recordPermission {
      case .undetermined:
        print("Permission has not been requested yet")
        AVAudioSession.sharedInstance().requestRecordPermission { granted in
          if granted {
            print("Permission is granted")
          } else {
            print("Permission is denied")
            isGranted = false
          }
        }
        break
      case .denied:
        print("Permission has been denied")
        isGranted = false
        break
      case .granted:
        print("Permission is already granted")
        break
      default:
        break
      }
      if !isGranted {
        throw NSError(domain: "PermissionError", code: -1, userInfo: ["message": "Record Permission has been denied"])
      }
    }
  }
  func recordAudio(_ sender: NSObject? = nil) async {
    do {
      try await requestRecordPermission()
    } catch {
      showAlert(alertTitle: "PermissionError", alertMessage: "設定 > プライバシーとセキュリティ > マイク から SampleApp のマイクアクセスを許可してください。")
      return
    }
    let audioSession = AVAudioSession.sharedInstance()
    do {
      try audioSession.setCategory(AVAudioSession.Category.record)
    } catch {
      print("Error: audio session failed to set category")
      showAlert(alertTitle: "AudioError")
      return
    }
    audioData = NSMutableData()
    var status: Int32
    status = AudioController.sharedInstance.prepare(specifiedSampleRate: SAMPLE_RATE)
    if (status != noErr) {
      print("Error: \(status)")
      showAlert(alertTitle: "AudioError")
      return
    }
    status = AudioController.sharedInstance.start()
    if (status != noErr) {
      print("Error: \(status)")
      showAlert(alertTitle: "AudioError")
      return
    }
    self.toggleButtons()
  }
  func stopAudio(_ sender: NSObject? = nil) throws {
    let status = AudioController.sharedInstance.stop()
    if (status != noErr) {
      print("Error: \(status)")
    }
    try YyStreamRecognizer.shared.stop()
    self.toggleButtons()
  }
  func createCustomLabel(text: String? = "") -> UILabel {
    let label = UILabel()
    label.text = text
    label.font = .preferredFont(forTextStyle: .title1)
    label.font = .systemFont(ofSize: 22)
    label.numberOfLines = 0
    label.lineBreakMode = .byCharWrapping
    return label
  }
  func showAlert(alertTitle: String? = "Error", alertMessage: String? = "") {
    let alert = UIAlertController(title: alertTitle, message: alertMessage, preferredStyle: .alert)
    let okAction = UIAlertAction(title: "OK", style: .default) { _ in
      print("OK")
    }
    alert.addAction(okAction)
    DispatchQueue.main.async { [weak self] in
      if let weakSelf = self {
        weakSelf.present(alert, animated: true, completion: nil)
      }
    }
  }
}
