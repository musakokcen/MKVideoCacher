//
//  ViewController.swift
//  MKVideoCacher
//
//  Created by musatrtr@gmail.com on 05/05/2020.
//  Copyright (c) 2020 musatrtr@gmail.com. All rights reserved.
//

import UIKit
import AVFoundation
import MKVideoCacher

class ViewController: UIViewController {

    @IBAction func replayTapped(_ sender: Any) {
        if let url = URL(string: url1) {
            self.player = manager?.setPlayer(with : url)
            self.layer?.player = player
        player?.play()
        
    }
    }
    
    
    let url1 =  "http://commondatastorage.googleapis.com/gtv-videos-bucket/sample/ForBiggerMeltdowns.mp4"


       var player : AVPlayer?
       var layer : AVPlayerLayer?
       var manager : VideoCache?
       
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        self.manager = VideoCache(limit : 256)
        if let manager = self.manager, let url = URL(string: url1) {
            self.player = manager.setPlayer(with : url)
            layer = AVPlayerLayer(player: player)
            if let layer = self.layer{
                layer.frame = CGRect(
                    x: (self.view.frame.width - 300) / 2 ,
                    y: (self.view.frame.height - 165) / 2,
                    width: 300,
                    height: 165)
                
                self.view.layer.addSublayer(layer)
                player?.play()
            }
           
        }
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }

}

