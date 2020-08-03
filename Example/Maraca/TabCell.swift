//
//  TabCell.swift
//  Maraca_Example
//
//  Created by Chrishon Wyllie on 7/29/20.
//  Copyright © 2020 CocoaPods. All rights reserved.
//

import UIKit

class TabCell: UICollectionViewCell {
    
    override var isSelected: Bool {
        didSet {
            containerView.backgroundColor = isSelected ? .red : .groupTableViewBackground
            titleLabel.textColor = isSelected ? .white : .black
        }
    }
    
    private var containerView: UIView = {
        let v = UIView()
        v.translatesAutoresizingMaskIntoConstraints = false
        v.layer.cornerRadius = 10
        v.clipsToBounds = true
        v.backgroundColor = UIColor.groupTableViewBackground
        return v
    }()
    
    private var titleLabel: UILabel = {
        let lbl = UILabel()
        lbl.translatesAutoresizingMaskIntoConstraints = false
        lbl.font = UIFont.systemFont(ofSize: 15)
        return lbl
    }()
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        setupUIElements()
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    private func setupUIElements() {
        contentView.addSubview(containerView)
        containerView.addSubview(titleLabel)
        
        let padding: CGFloat = 8
        containerView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: padding).isActive = true
        containerView.topAnchor.constraint(equalTo: contentView.topAnchor, constant: padding).isActive = true
        containerView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -padding).isActive = true
        containerView.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -padding).isActive = true
        
        titleLabel.leadingAnchor.constraint(equalTo: containerView.leadingAnchor, constant: padding).isActive = true
        titleLabel.topAnchor.constraint(equalTo: containerView.topAnchor, constant: padding).isActive = true
        titleLabel.trailingAnchor.constraint(equalTo: containerView.trailingAnchor, constant: -padding).isActive = true
        titleLabel.bottomAnchor.constraint(equalTo: containerView.bottomAnchor, constant: -padding).isActive = true
    }
    
    func configure(with tab: Tab) {
        titleLabel.text = tab.title
    }
}
