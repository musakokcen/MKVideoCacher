//
//  VideoCache.swift
//  MKVideoCache
//
//  Created by musa on 3.05.2020.
//

import UIKit
import AVFoundation
import CoreData

public class VideoCache :  NSObject, AVAssetResourceLoaderDelegate {
    
    private var limit : Double = 256
    private var serverUrl : URL?
    private var localUrl : URL?
    private var player : AVPlayer?
    private var item : AVPlayerItem?
    private var asset : AVURLAsset?
    
    
    
    public init(limit:Double) {
        self.limit = limit
    }
    
    public func setPlayer(with url: URL) -> AVPlayer {
        
        let cacheUrl = fetchCachedDataInfo(for: url.absoluteString)
        
        if let cacheUrl = cacheUrl, let cached = URL(string: cacheUrl) {
            self.asset = AVURLAsset(url: cached)
            print("item is played from cache")
        } else {
            self.asset = AVURLAsset(url: url)
            print("item is played from URL")
        }
        
        self.asset?.resourceLoader.setDelegate(self, queue: DispatchQueue.main)
        if let asset = self.asset{
            self.item = AVPlayerItem(asset: asset)
            if let item = self.item {
                self.player = AVPlayer(playerItem:item)
            }
            
            if cacheUrl == nil {
                self.serverUrl = url
                if let serverUrl = self.serverUrl {
                    self.localUrl = createLocalUrl(with:serverUrl)
                    NotificationCenter.default.addObserver(self, selector: #selector(playerItemDidReachEnd), name: NSNotification.Name.AVPlayerItemDidPlayToEndTime, object: self.item)
                }
            }
        }
        
        return self.player ?? AVPlayer()
    }
    
    
    @objc private func playerItemDidReachEnd(notification: NSNotification) {
        
        guard let serverUrl = self.serverUrl else {return}
        guard let localUrl = self.localUrl else {return}
        guard let asset = self.asset else {return}
        
        
        if notification.object as? AVPlayerItem  == self.player?.currentItem {
            
            let exporter = AVAssetExportSession(
                asset: asset,
                presetName: AVAssetExportPresetHighestQuality)
            
            exporter?.outputURL = localUrl
            exporter?.outputFileType = AVFileType.mp4
            
            exporter?.exportAsynchronously(completionHandler: {
                
                // if error = nil, item is cached
                if exporter?.error == nil {
                    
                    self.saveCachedDataInfo(for: localUrl.absoluteString, serverUrl: serverUrl, completion: {success, error in
                        if success{
                            
                            self.manageCachedDataStorage(with : self.limit)
                            
                        } else {
                            print("exported but the info could not be saved ",error as Any)
                        }
                    })
                    
                } else {
                    
                    print(exporter?.error as Any)
                    
                    self.saveCachedDataInfo(for: localUrl.absoluteString, serverUrl : serverUrl, completion: {success, error in
                        if success{
                            print("already in cache - saved to coreData: ",success)
                            
                        } else {
                            print("already in cache - but the info could not be saved ",error as Any)
                        }
                    })
                }
            })
        }
    }
    
    
    private func createLocalUrl(with url : URL) -> URL?{
        if let filename = (url.absoluteString as NSString?)?.lastPathComponent {
            
            if let documentsDirectory = FileManager.default.urls(for: FileManager.SearchPathDirectory.documentDirectory, in: FileManager.SearchPathDomainMask.userDomainMask).last {
                
                let outputURL = documentsDirectory.appendingPathComponent(filename)
                
                return outputURL
            }
        }
        return nil
    }
    
    //MARK: Save cached data access info to the CoreData
    private func saveCachedDataInfo(for outputURL : String, serverUrl: URL, completion : @escaping ((Bool, String?) -> Void)){
        
        DispatchQueue.main.async {
            
            if let context = self.persistentContainer?.viewContext {
                let newCache = NSEntityDescription.insertNewObject(forEntityName: "CacheModel", into: context)
                
                newCache.setValue(outputURL, forKey: "localUrl")
                newCache.setValue(serverUrl.absoluteString, forKey: "serverUrl")
                
                do {
                    try context.save()
                    completion(true, nil)
                    
                } catch let error {
                    completion(false, error.localizedDescription)
                }
            }
            
        }
        
    }
    
    public func fetchCachedDataInfo(for serverUrl : String) -> String?{
        
        var fileUrl : String?
        let context = self.persistentContainer?.viewContext
        
        let request = NSFetchRequest<NSFetchRequestResult>(entityName: "CacheModel")
        request.returnsObjectsAsFaults = false
        
        do {
            let cachedData = try context?.fetch(request)
            
            if let cachedData = cachedData as? [NSManagedObject]{
                
                cachedData.forEach { (obj) in
                    if let sUrl = obj.value(forKey: "serverUrl") as? String{
                        
                        if sUrl == serverUrl {
                            // get url of the cached data
                            if let localUrl = obj.value(forKey: "localUrl") as? String {
                                if let url = URL(string: localUrl) {
                                    if self.isFileExist(at: url.path){
                                        
                                        //cache exists
                                        fileUrl = localUrl
                                        
                                    } else {
                                        clearCoreData(at: localUrl)
                                    }
                                }
                            }
                        }
                        
                    }
                }
            }
        } catch let error {
            print(error.localizedDescription)
        }
        
        return fileUrl
    }
    
    private func isFileExist(at localPath : String) -> Bool {
        if (FileManager.default.fileExists(atPath: localPath))   {
            return true
        } else {
            return false
        }
    }
    
    func manageCachedDataStorage(with limit: Double){
        
        let context = self.persistentContainer?.viewContext
        let request = NSFetchRequest<NSFetchRequestResult>(entityName: "CacheModel")
        request.returnsObjectsAsFaults = false
        do {
            let cachedData = try context?.fetch(request)
            if var cachedData = cachedData as? [NSManagedObject]{
                
                var fileSizes : [Double] = []
                
                cachedData.forEach { (obj) in
                    let localUrl = obj.value(forKey: "localUrl") as? String
                    if let localUrl = localUrl {
                        if let path = URL(string: localUrl)?.path{
                            
                            let size =  getSizeOfData(path: path)
                            fileSizes.append(size)
                            
                        }
                    }
                }
                
                var total = fileSizes.reduce(0, +)
                
                while total > limit {
                    let data = cachedData.first
                    if let locUrl = data?.value(forKey: "localUrl") as? String{
                        
                        // remove urls from coreData
                        clearCoreData(at: locUrl)
                        
                        if let localUrl = URL(string: locUrl){
                            //remove cache from filemanager
                            clearCachedData(at: localUrl)
                        }
                        
                        // remove from loop
                        cachedData.removeFirst()
                        
                        // recalculate cached data size
                        total -= fileSizes.first ?? 0.0
                    }
                }
            }
        } catch let error {
            print(error.localizedDescription)
        }
        
    }
    
    //MARK: calculate size of a data
    private func getSizeOfData(path: String)-> Double  {
        
        let fileManager = FileManager.default
        do {
            let attributes = try fileManager.attributesOfItem(atPath: path)
            let fileSize = attributes[FileAttributeKey.size]
            if (fileSize as? UInt64) != nil{
                let dict = attributes as NSDictionary
                let size = dict.fileSize()
                
                return Double(size)/(1024.0*1024.0)
            }
        }
        catch let error as NSError {
            print("Something went wrong: \(error.localizedDescription)")
            
            return 0.0
        }
        
        return 0.0
    }
    
    //MARK: remove data from filemanager
    private func clearCachedData(at localURL : URL){
        do {
            try FileManager.default.removeItem(at: localURL)
        } catch {
            print(error.localizedDescription)
        }
    }
    
    //MARK: remove cached data info from CoreData
    private func clearCoreData(at localURL: String){
        
        
        if let context = self.persistentContainer?.viewContext {
            let request = NSFetchRequest<NSFetchRequestResult>(entityName: "CacheModel")
            request.returnsObjectsAsFaults = false
            do {
                let cachedDataUrls = try context.fetch(request)
                if let cachedDataUrls = cachedDataUrls as? [NSManagedObject]{
                    for dataUrl in cachedDataUrls{
                        if let localUrl = dataUrl.value(forKey: "localUrl") as? String {
                            if localUrl == localURL {
                                context.delete(dataUrl)
                            }
                        }
                    }
                    
                    try context.save()
                }
                
            } catch let error as NSError {
                print("delete fail--",error.localizedDescription)
            }
        }
    }
    
    private lazy var persistentContainer: NSPersistentContainer? = {
        let modelURL = Bundle(for: VideoCache.self).url(forResource: "CacheModel", withExtension: "momd")
        
        var container: NSPersistentContainer
        
        guard let model = modelURL.flatMap(NSManagedObjectModel.init) else {
            print("Fail to load the trigger model!")
            return nil
        }
        
        container = NSPersistentContainer(name: "CacheModel", managedObjectModel: model)
        
        container.loadPersistentStores(completionHandler: { (storeDescription, error) in
            if let error = error as NSError? {
                print("Unresolved error \(error), \(error.userInfo)")
            }
        })
        
        return container
    }()
    
    private var managedObjectContext: NSManagedObjectContext?
    
    public override init() {
        super.init()
        managedObjectContext = persistentContainer?.viewContext
        
        guard managedObjectContext != nil else {
            print("Can't get right managed object context.")
            return
        }
    }
    
    public func appWillTerminate(){
        
        let context = persistentContainer?.viewContext
        let request = NSFetchRequest<NSFetchRequestResult>(entityName: "CacheModel")
        request.returnsObjectsAsFaults = false
        do {
            let cachedData = try context?.fetch(request)
            if let cachedData = cachedData as? [NSManagedObject]{
                
                cachedData.forEach { (obj) in
                    if let localUrl = obj.value(forKey: "localUrl") as? String {
                        if let localUrl = URL(string: localUrl){
                            do {
                                try FileManager.default.removeItem(at: localUrl)
                                print("cache cleaned", localUrl as Any)
                                context?.delete(obj)
                            } catch {
                                print(error.localizedDescription)
                            }
                        }
                        
                    }
                    
                }
            }
        } catch let error {
            print(error.localizedDescription)
        }
    }
}
