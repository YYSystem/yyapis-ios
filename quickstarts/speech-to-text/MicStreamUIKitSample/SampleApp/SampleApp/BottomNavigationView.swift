//
//  BottomNavigationView.swift
//  SampleApp
//
//  Created by Scorbunny on 2023/12/18.
//

import UIKit

class BottomNavigationView: UIStackView {
  let toolbar: UIStackView
  init(toolbarHeight: CGFloat = 48) {
    toolbar = UIStackView()
    super.init(frame: .zero)
    self.axis = .vertical
    self.backgroundColor = .secondarySystemBackground
    toolbar.axis = .horizontal
    //    toolbar.distribution = .fill
    toolbar.alignment = .center
    //    toolbar.spacing = 8
    toolbar.isLayoutMarginsRelativeArrangement = true
    toolbar.layoutMargins = UIEdgeInsets(top: 0, left: 24, bottom: 0, right: 24)
    toolbar.layer.zPosition = 1500
    let spacer = UIView()
    spacer.backgroundColor = .clear
    spacer.autoresizingMask = .flexibleHeight
    self.addSubview(toolbar)
    self.addSubview(spacer)
    toolbar.translatesAutoresizingMaskIntoConstraints = false
    NSLayoutConstraint.activate([
      toolbar.heightAnchor.constraint(equalToConstant: CGFloat(toolbarHeight)),
      toolbar.widthAnchor.constraint(equalTo: self.widthAnchor),
    ])
  }
  required init(coder: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }
}
