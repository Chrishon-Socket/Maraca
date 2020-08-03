//
//  TabsSelectionView.swift
//  Maraca_Example
//
//  Created by Chrishon Wyllie on 7/29/20.
//  Copyright © 2020 CocoaPods. All rights reserved.
//

import UIKit

class TabsSelectionView: UIView {
    
    private let cellReuseIdentifier: String = "cellReuseIdentifier"
    
    private var tabs: [Tab] = []
    
    private lazy var collectionView: UICollectionView = {
        let layout = UICollectionViewFlowLayout()
        layout.minimumLineSpacing = 0
        layout.minimumInteritemSpacing = 0
        layout.scrollDirection = .horizontal
        
        let cv = UICollectionView(frame: .zero, collectionViewLayout: layout)
        cv.translatesAutoresizingMaskIntoConstraints = false
        cv.backgroundColor = .white
        cv.delegate = self
        cv.dataSource = self
        cv.allowsSelection = true
        cv.alwaysBounceHorizontal = true
        return cv
    }()
    
    init() {
        super.init(frame: .zero)
        translatesAutoresizingMaskIntoConstraints = false
        addSubview(collectionView)
        collectionView.register(TabCell.self, forCellWithReuseIdentifier: cellReuseIdentifier)
        collectionView.leadingAnchor.constraint(equalTo: leadingAnchor).isActive = true
        collectionView.topAnchor.constraint(equalTo: topAnchor).isActive = true
        collectionView.trailingAnchor.constraint(equalTo: trailingAnchor).isActive = true
        collectionView.bottomAnchor.constraint(equalTo: bottomAnchor).isActive = true
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    func indexOf(tab: Tab) -> Int? {
        
        guard let arrayElementIndex = tabs.firstIndex(of: tab) else {
            return nil
        }
        return Int(arrayElementIndex)
    }
    
    func add(tab: Tab) {
        tabs.append(tab)
        collectionView.reloadData()
        let lastIndexPath = IndexPath(item: tabs.count - 1, section: 0)
        collectionView.scrollToItem(at: lastIndexPath, at: UICollectionViewScrollPosition.right, animated: true)
        collectionView.selectItem(at: lastIndexPath, animated: true, scrollPosition: UICollectionViewScrollPosition.right)
    }
    
    func updateTab(at index: Int, with tab: Tab) {
        tabs[index] = tab
        collectionView.reloadData()
        let indexPath = IndexPath(item: index, section: 0)
        collectionView.scrollToItem(at: indexPath, at: UICollectionViewScrollPosition.right, animated: true)
        collectionView.selectItem(at: indexPath, animated: true, scrollPosition: UICollectionViewScrollPosition.right)
    }
    
    func removeTab(at index: Int) {
        tabs.remove(at: index)
        collectionView.reloadData()
    }
    
    func didSelectItem(completion: @escaping (IndexPath, Tab) -> ()) {
        didSelectHandler = completion
    }
    
    private var didSelectHandler: ((IndexPath, Tab) -> ())?
}

extension TabsSelectionView: UICollectionViewDelegate, UICollectionViewDataSource, UICollectionViewDelegateFlowLayout {
    
    func numberOfSections(in collectionView: UICollectionView) -> Int {
        return 1
    }
    
    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        return tabs.count
    }
    
    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        let cell = collectionView.dequeueReusableCell(withReuseIdentifier: cellReuseIdentifier, for: indexPath) as? TabCell
        
        let tab = tabs[indexPath.item]
        cell?.configure(with: tab)
        
        return cell!
    }
    
    func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, sizeForItemAt indexPath: IndexPath) -> CGSize {
        
        let tab = tabs[indexPath.item]
        let width = calculateCellWidth(from: tab.title)
        let height: CGFloat = collectionView.frame.size.height
        return CGSize(width: width, height: height)
    }
    
    private func calculateCellWidth(from text: String) -> CGFloat {
        let font = UIFont.systemFont(ofSize: 15)
        let arbitrarySize = CGSize(width: 200, height: CGFloat.greatestFiniteMagnitude)
        let options: NSStringDrawingOptions = [.usesLineFragmentOrigin, .usesFontLeading]
        let textFrame = NSString(string: text).boundingRect(with: arbitrarySize, options: options, attributes: [NSAttributedString.Key.font: font], context: nil)
        
        let totalPadding: CGFloat = 32 + 2
        let calculatedWidth: CGFloat = textFrame.size.width + totalPadding
        return calculatedWidth
    }
    
    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        let tab = tabs[indexPath.item]
        didSelectHandler?(indexPath, tab)
        collectionView.scrollToItem(at: indexPath, at: UICollectionViewScrollPosition.right, animated: true)
    }
}
