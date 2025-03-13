//
//  MainView.swift
//  SampleApp
//
//  Created by Scorbunny on 2025/03/12.
//

import Combine
import UIKit

class MainView: UIView {
  private let label: UILabel = {
    let label = UILabel()
    label.translatesAutoresizingMaskIntoConstraints = false
    label.numberOfLines = 0
    label.text = "ここにテキストが表示されます。"
    label.textAlignment = .center
    label.lineBreakMode = .byWordWrapping
    return label
  }()
  private let mainStackView: UIStackView = {
    let stackView = UIStackView()
    stackView.translatesAutoresizingMaskIntoConstraints = false
    stackView.axis = .vertical
    stackView.spacing = 16
    stackView.alignment = .fill
    return stackView
  }()
  private var cancellables: Set<AnyCancellable> = []
  init(viewModel: RecognizerViewModel) {
    super.init(frame: .zero)
    mainStackView.addArrangedSubview(label)
    addSubview(mainStackView)
    NSLayoutConstraint.activate([
      mainStackView.leadingAnchor.constraint(equalTo: safeAreaLayoutGuide.leadingAnchor, constant: 16),
      mainStackView.trailingAnchor.constraint(equalTo: safeAreaLayoutGuide.trailingAnchor, constant: -16),
      mainStackView.topAnchor.constraint(greaterThanOrEqualTo: safeAreaLayoutGuide.topAnchor, constant: 16),
      mainStackView.bottomAnchor.constraint(lessThanOrEqualTo: safeAreaLayoutGuide.bottomAnchor, constant: -16),
      mainStackView.centerYAnchor.constraint(equalTo: safeAreaLayoutGuide.centerYAnchor),
    ])
    bind(to: viewModel)
  }
  required init?(coder: NSCoder) {
      fatalError("init(coder:) has not been implemented")
  }
  private func bind(to viewModel: RecognizerViewModel) {
    viewModel.$recognitionResult
      .receive(on: DispatchQueue.main)
      .sink { [weak self] recognitionResult in
        self?.label.text = recognitionResult.text
        self?.label.textColor = recognitionResult.isFinal ? .label : .secondaryLabel
      }
      .store(in: &cancellables)
  }
}
