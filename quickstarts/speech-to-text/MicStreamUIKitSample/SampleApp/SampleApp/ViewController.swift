//
//  ViewController.swift
//  SampleApp
//
//  Created by Scorbunny on 2023/12/15.
//

import Combine
import UIKit
import AVFoundation
import os

class ViewController: UIViewController, AudioControllerDelegate {
  let SAMPLE_RATE = 16000
  private var audioData: NSMutableData!
  private var mainView: MainView!
  private var recognizerViewModel: RecognizerViewModel!
  private var cancellables: Set<AnyCancellable> = []
  private var logger = Logger(subsystem: "com.example.SampleApp", category: "ViewController")
  override func viewDidLoad() {
    super.viewDidLoad()
    AudioController.shared.delegate = self
    recognizerViewModel = RecognizerViewModel()
    mainView = MainView(viewModel: recognizerViewModel)
    setupMainView()
    bindViewModel()
    setupRightBarButton()
  }
  private func setupMainView() {
    mainView.translatesAutoresizingMaskIntoConstraints = false
    view.addSubview(mainView)
    NSLayoutConstraint.activate([
      mainView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
      mainView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
      mainView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
      mainView.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor),
    ])
  }
  private func bindViewModel() {
    recognizerViewModel.$isRecognizing
      .receive(on: DispatchQueue.main)
      .sink { [weak self] isRecognizing in
        self?.setupRightBarButton(isRecognizing: isRecognizing)
        if !isRecognizing {
          let status = AudioController.shared.stop()
          if (status != noErr) {
            self?.logger.error("Error: \(status)")
            self?.showAlert(alertTitle: "AudioError")
          }
        }
      }
      .store(in: &cancellables)
    recognizerViewModel.$errorText
      .receive(on: DispatchQueue.main)
      .sink {[weak self] errorText in
        if errorText.isEmpty { return }
        self?.showAlert(alertTitle: "RecognitionError", alertMessage: errorText)
      }
      .store(in: &cancellables)
  }
  private func setupRightBarButton(isRecognizing: Bool = false) {
    let buttonTitle = isRecognizing ? "Stop" : "Record"
    let buttonImage = UIImage(systemName: isRecognizing ? "stop.fill" : "record.circle.fill")
    let action = UIAction { [weak self] action in
      if isRecognizing {
        self?.logger.info("Stop pressed")
        self?.recognizerViewModel.stopRecognition()
      } else {
        self?.logger.info("Start pressed")
        let sender = action.sender
        Task(priority: .medium) {
          if let senderObject = sender as? NSObject {
            await self?.recordAudio(senderObject)
          } else {
            self?.logger.info("Sender is not NSObject")
          }
        }
      }
    }
    navigationItem.rightBarButtonItem = UIBarButtonItem(title: buttonTitle, image: buttonImage, primaryAction: action, menu: nil)
  }
  func processSampleData(_ data: Data) {
    audioData.append(data)
    let chunkSize: Int = Int(0.1 * Double(SAMPLE_RATE)) * 2
    if (audioData.length > chunkSize) {
      Task {
        try await recognizerViewModel.write(audioData as Data)
        self.audioData = NSMutableData()
        return
      }
    }
  }
  func showAlert(alertTitle: String? = "Error", alertMessage: String? = "") {
    let alert = UIAlertController(title: alertTitle, message: alertMessage, preferredStyle: .alert)
    let okAction = UIAlertAction(title: "OK", style: .default) { _ in
      self.logger.info("OK")
    }
    alert.addAction(okAction)
    DispatchQueue.main.async { [weak self] in
      if let weakSelf = self {
        weakSelf.present(alert, animated: true, completion: nil)
      }
    }
  }
  func recordAudio(_ sender: NSObject? = nil) async {
    do {
      try await AudioController.shared.requestRecordPermission()
    } catch {
      showAlert(alertTitle: "PermissionError", alertMessage: "設定 > プライバシーとセキュリティ > マイク から SampleApp のマイクアクセスを許可してください。")
      return
    }
    audioData = NSMutableData()
    var status: Int32
    status = AudioController.shared.prepare(specifiedSampleRate: SAMPLE_RATE)
    if (status != noErr) {
      logger.error("Error: \(status)")
      showAlert(alertTitle: "AudioError")
      return
    }
    status = AudioController.shared.start()
    if (status != noErr) {
      logger.error("Error: \(status)")
      showAlert(alertTitle: "AudioError")
      return
    }
    recognizerViewModel.startRecognition()
  }

}
