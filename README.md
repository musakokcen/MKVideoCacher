# MKVideoCacher

[![CI Status](https://img.shields.io/travis/musatrtr@gmail.com/MKVideoCacher.svg?style=flat)](https://travis-ci.org/musatrtr@gmail.com/MKVideoCacher)
[![Version](https://img.shields.io/cocoapods/v/MKVideoCacher.svg?style=flat)](https://cocoapods.org/pods/MKVideoCacher)
[![License](https://img.shields.io/cocoapods/l/MKVideoCacher.svg?style=flat)](https://cocoapods.org/pods/MKVideoCacher)
[![Platform](https://img.shields.io/cocoapods/p/MKVideoCacher.svg?style=flat)](https://cocoapods.org/pods/MKVideoCacher)

## Example


Add this code to your Podfile;

    pod 'MKVideoCacher', :git => 'https://github.com/musatrtr/MKVideoCacher'


To run the example project, clone the repo, and run `pod install` from the Example directory first.

The video will be cached after it is played.

You can implement it as follows;

Before the class;

    import MKVideoCacher


Inside the class;

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
                layer.frame = self.view.frame
                self.view.layer.addSublayer(layer)
                player?.play()
            }
        }
    }

If you want to remove the cache when app is terminated, add this code to appDelegate;

Before the class;

    import MKVideoCacher


Inside the class;
      
    func applicationWillTerminate(_ application: UIApplication) {
       let videoCache = VideoCache(limit : 256)
       videoCache.appWillTerminate()
    }

## Requirements

## Installation

MKVideoCacher is available through [CocoaPods](https://cocoapods.org). To install
it, simply add the following line to your Podfile:

```ruby
pod 'MKVideoCacher'
```

## Author

musatrtr@gmail.com

## License

MKVideoCacher is available under the MIT license. See the LICENSE file for more info.
