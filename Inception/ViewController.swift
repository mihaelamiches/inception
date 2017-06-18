//
//  ViewController.swift
//  Inception
//
//  Created by Mihaela Miches on 6/10/17.
//  Copyright © 2017 me. All rights reserved.
//

import UIKit
import SceneKit
import ARKit
import CoreML

class ViewController: UIViewController, ARSCNViewDelegate {
    @IBOutlet var sceneView: ARSCNView!
    var anchors: [ARAnchor] = []
    
    var emojis: [Emoji] = []
    let inceptionv3 = Inceptionv3()
    
    var emojiCache: [Date: Emojified] = [:]
    var lastPredicted = Date()
    var lastRefreshed = Date()
    
    let attentionSpan = 1
    
    
    //MARK: - View Lifecycle
    override func viewDidLoad() {
        super.viewDidLoad()
        
        addThermalStateObserver()
        loadEmojis()
        loadScene()
    }
    
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        
        startSession()
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        
        pauseSession()
    }
    
    // MARK: - Session
    func loadScene() {
        sceneView.delegate = self
        sceneView.showsStatistics = true
        sceneView.scene = SCNScene()
    }
    
    func startSession() {
        removeAnchors()
        sceneView.session.run(ARWorldTrackingSessionConfiguration())
        print("🌏")
    }
    
    func pauseSession() {
        sceneView.session.pause()
    }
    
    
    // MARK: - Anchors
    func removeAnchors() {
        anchors.forEach { sceneView.session.remove(anchor: $0) }
        anchors = []
    }
    
    func dispatchAnchor(after: Int = 0) {
        DispatchQueue.main.asyncAfter(deadline: (DispatchTime.now() + Double(after))) {
            self.addSceneAnchor()
        }
    }
    
    func addSceneAnchor() {
        guard let frame = sceneView.session.currentFrame  else { return print("🙅🏻⚓️") }
        
        removeAnchors()
        
        let translation = matrix_identity_float4x4
        let transform = simd_mul(frame.camera.transform, translation)
        let anchor = ARAnchor(transform: transform)
        
        anchors.append(anchor)
        sceneView.session.add(anchor: anchor)
    }
    
    // MARK: - Cache
    func clearCache(_ purge: Bool = false) {
        let lifespan = 5
        guard purge == false else { emojiCache = [:]; return }
        
        let alive = Calendar.current.date(byAdding: .second, value: -lifespan, to: Date()) ?? Date()
        emojiCache = emojiCache.filter {  $0.key >= alive }
    }
    
    // MARK: - Emojify
    func loadEmojis() {
        guard let url = Bundle.main.path(forResource: "emojis", ofType: "json"),
            let path = URL(string: "file://\(url)"),
            let json = try? JSONSerialization.jsonObject(with: Data(contentsOf: path), options: .mutableLeaves),
            let dict = json as? [Dictionary<String,Any>]
            else { return print("😅") }
        
        self.emojis = dict.flatMap { Emoji(from: $0) }
    }
    
    //needs to be a mlmodel
    func emojify(_ prediction: String) -> [String] {
        let input = prediction.lowercased()
        let words = input.split(separator: " ").map { String($0).trimmingCharacters(in: .whitespaces) }
        
        let exact = emojis.filter { $0.description.lowercased() == input  }.map { $0.value }
        guard exact.count == 0 else { return exact }
        
        let close = emojis.filter { $0.description.lowercased().contains(input) || input.contains($0.description.lowercased()) || $0.tags.contains(input)  }.map { $0.value }
        
        let similar: [String] = words.reduce([]) { (acc, part) -> [String] in
            let word = part
            let same: [String] =  emojis.filter { $0.description.contains(word) }.map { $0.value }
            return acc + same
            } + close
        
        let probs = similar.reduce([:]) {  (acc, part) -> [String: Int] in
            var next = acc
            if !acc.contains { $0.0 == part } {
                next[part] = 1
                return next
            }
            
            next[part]! += 1
            return next
        }
        
        let likely = probs.sorted { $0.1 > $1.1 }.map { $0.key }.filter{ $0.characters.count > 0 }.first
        return likely != nil ? [likely!] : []
    }
    
    func detectSceneContents() -> String {
        guard let capturedImage = sceneView.session.currentFrame?.capturedImage,
            let inceptionScene = capturedImage.resized(for: .inception),
            let inception = try? inceptionv3.prediction(image: inceptionScene)
            else { return "😅" }
        
        return inception.classLabel
    }
    
    func snapshotScene() {
        clearCache()
        
        let contents = detectSceneContents()
        let emoji = contents.split(separator: ",").flatMap { emojify(String($0)).first }.shuffled().first
        
        if contents.characters.count > 0 {
            lastPredicted = Date()
            emojiCache[lastPredicted] = (contents == "nematode, nematode worm, roundworm") ? ("", "🤔") : (contents, emoji ?? "")
        }
    }
    
    // MARK:- Scene Nodes
    func anchorNode(type: AnchorType, value: Emojified) -> SCNNode {
        let layer = CALayer()
        let size = 600
        layer.frame = CGRect(origin: .zero, size: CGSize(width: size, height: size))
        layer.backgroundColor = UIColor.clear.cgColor
        let text = type == .emoji ? value.1 : value.0
        
        let textLayer = CATextLayer()
        textLayer.frame = layer.frame
        textLayer.foregroundColor = UIColor.pink.cgColor
        textLayer.fontSize = type == .emoji ? layer.bounds.size.height : (text.characters.count > 30 ? 50 : 90)
        textLayer.string =  text
        textLayer.alignmentMode = type == .emoji ? kCAAlignmentCenter : kCAAlignmentLeft
        textLayer.isWrapped = true
        textLayer.display()
        
        layer.addSublayer(textLayer)
        
        let textGeometry = SCNBox(width: 0.05, height: 0.05, length: 0.05, chamferRadius: 0)
        textGeometry.firstMaterial?.diffuse.contents = layer
        textGeometry.firstMaterial?.locksAmbientWithDiffuse = true
        
        let node = SCNNode(geometry: textGeometry)
        node.position = SCNVector3(0, 0, -0.2)
        node.accessibilityLabel = String(value.0.split(separator: ",").first ?? "")
        node.isAccessibilityElement = true
        
        return node
    }
    
    
    func sceneNode() -> SCNNode {
        guard let lastEmoji = emojiCache[lastPredicted] else {
            return anchorNode(type: .emoji, value: ("","🤔"))
        }
        
        let descriptionNode = anchorNode(type: .about, value: lastEmoji)
        let emoji = anchorNode(type: .emoji, value: lastEmoji)
        
        descriptionNode.addChildNode(emoji)
        
        return descriptionNode
    }
    
    // MARK: - Scene Delegate
    func renderer(_ renderer: SCNSceneRenderer, updateAtTime time: TimeInterval) {
      let predictRate = 1
      let refreshRate = UIAccessibilityIsVoiceOverRunning() ? 2 : 1 // give it time to read
      let now = Date()
        
      if Calendar.current.dateComponents([.second], from: lastPredicted, to: now).second ?? 0 >= predictRate {
        snapshotScene()
      }
        
      if Calendar.current.dateComponents([.second], from: lastRefreshed, to: now).second ?? 0 >= refreshRate {
        dispatchAnchor()
        lastRefreshed = now
      }
    }
    
    func renderer(_ renderer: SCNSceneRenderer, didAdd node: SCNNode, for anchor: ARAnchor) {
        DispatchQueue.main.async {
            let child = self.sceneNode()
            UIAccessibilityPostNotification(UIAccessibilityAnnouncementNotification, child.accessibilityLabel)
            node.addChildNode(child)
        }
    }
    
    func renderer(_ renderer: SCNSceneRenderer, didRemove node: SCNNode, for anchor: ARAnchor) {
        node.enumerateChildNodes { (child, _) in
            child.removeFromParentNode()
        }
    }
}

