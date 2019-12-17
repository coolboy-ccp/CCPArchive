//
//  ZipFileHandler.swift
//  CCPZip
//
//  Created by 储诚鹏 on 2019/12/12.
//  Copyright © 2019 储诚鹏. All rights reserved.
//

import UIKit

class ZipFileHandler {
    
    public typealias DirectoryGuard = (exist: Bool, directory: Bool)
    
    static func modificationDate(of url: URL) throws -> Date {
        let attributes = try FileManager.default.attributesOfItem(atPath: url.path)
        return (attributes[.modificationDate] as? Date) ?? Date()
    }
    
    static func modificationDateComponents(of url: URL) throws -> DateComponents {
        let date = try modificationDate(of: url)
        return Calendar.current.dateComponents([.year, .month, .day, .hour, .minute, .second], from: date)
    }
    
    static func size(of urls: [URL]) throws -> Double {
       return try urls.reduce(0) { (rlt, url) -> Double in
            return try size(of: url) + rlt
        }
    }
    
    static func size(of url: URL) throws -> Double {
        let attributes = try FileManager.default.attributesOfItem(atPath: url.path)
        return (attributes[.size] as? Double) ?? 0
      
    }
    
    static func zipExist(_ url: URL) -> Bool {
        if fileExist(url) {
            return ["zip", "cbz"].contains(url.pathExtension)
        }
        return false
    }
    
    static func fileExist(_ url: URL) -> Bool  {
        return FileManager.default.fileExists(atPath: url.path, isDirectory: nil)
    }
    
    static func isDirectory(_ url: URL) -> DirectoryGuard {
        var isDirectory: ObjCBool = false
        let isExists = FileManager.default.fileExists(atPath: url.path, isDirectory: &isDirectory)
        return (isExists, isDirectory.boolValue)
    }
    
    static func fileURLS(with urls: [URL]) -> [URL] {
        var results = [URL]()
        for url in urls {
            results.append(contentsOf: fileURLS(with: url))
        }
        return results
    }
    
   static func fileURLS(with url: URL) -> [URL] {
        var isDirectory: ObjCBool = false
        let isExists = FileManager.default.fileExists(atPath: url.path, isDirectory: &isDirectory)
        if !isExists { return [] }
        if isDirectory.boolValue { return expandDirectory(url) }
        return [url]
    }
    
   static func expandDirectory(_ url: URL) -> [URL] {
        var urls = [URL]()
        guard let enumerator = FileManager.default.enumerator(atPath: url.path) else {
            return urls
        }
        while let sub = enumerator.nextObject() as? String {
            let subURL = url.appendingPathComponent(sub)
            var isDirectory: ObjCBool = false
            let isExists = FileManager.default.fileExists(atPath: subURL.path, isDirectory: &isDirectory)
            if !isExists { continue }
            if !isDirectory.boolValue {
                urls.append(subURL)
            }
        }
        return urls
    }

}
