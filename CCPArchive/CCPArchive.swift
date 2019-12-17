//
//  CCPArchive.swift
//  CCPArchive
//
//  Created by 储诚鹏 on 2019/12/13.
//  Copyright © 2019 储诚鹏. All rights reserved.
//

import UIKit
import Zip

public class CCPArchive {
    
    public static func zip(soruce: CCPArchiveSource, destination: URL? = nil, password: String? = nil, option: ZipOption = .default,  progressHandler: ProgressCallback? = nil) throws -> Destination {
        let url = try soruce.url()
        let guarder = ZipFileHandler.isDirectory(url)
        if !guarder.exist {
            throw ZipError.notFound(url.path)
        }
        let dropCount = guarder.directory ? url.path.count : url.deletingLastPathComponent().path.count
        let desURL = destination ?? url.deletingLastPathComponent().appendingPathComponent("\(url.lastPathComponent).zip")
        let fileURLs = ZipFileHandler.fileURLS(with: url)
        let pg = progress(try ZipFileHandler.size(of: fileURLs))
        let bufferSize = 16 * 1024
        let zip = zipOpen(desURL.path, APPEND_STATUS_CREATE)
        defer {
            zipClose(zip, nil)
        }
        var completedUnitCount: Int64 = 0
        for fileURL in fileURLs {
            guard let input = fopen(fileURL.path, "r") else {
                throw ZipError.cantOpen(fileURL.path)
            }
            var zipInfo = zip_fileinfo(tmz_date: tm_zip(tm_sec: 0, tm_min: 0, tm_hour: 0, tm_mday: 0, tm_mon: 0, tm_year: 0), dosDate: 0, internal_fa: 0, external_fa: 0)
            try setupTM(with: fileURL, zip: &zipInfo)
            let fileName = String(fileURL.path.dropFirst(dropCount))
            zipOpenNewFileInZip3(zip, fileName, &zipInfo, nil, 0, nil, 0, nil, Z_DEFLATED, option.zip, 0, -MAX_WBITS, DEF_MEM_LEVEL, Z_DEFAULT_STRATEGY, password, 0)
            
            let buffer = malloc(bufferSize)
            while feof(input) == 0 {
                let length = fread(buffer, 1, bufferSize, input)
                zipWriteInFileInZip(zip, buffer, UInt32(length))
                completedUnitCount += Int64(length)
                pg.completedUnitCount = completedUnitCount
                progressHandler?(pg)
            }
            zipCloseFileInZip(zip)
            free(buffer)
            fclose(input)
        }
        
        return desURL
    }
    
    fileprivate static func throwIfNotOK(_ rlt: Int32, _ url: URL, _ reason: String) throws {
        if rlt != UNZ_OK {
            throw ZipError.unzipFailed(url.path, reason)
        }
    }
    
    fileprivate static func createDirectory(_ result: URL, _ source: URL) throws {
        let current = Date()
        let attributes: [FileAttributeKey : Any] = [.creationDate : current, .modificationDate : current]
        do {
            try FileManager.default.createDirectory(at: result.deletingLastPathComponent(), withIntermediateDirectories: true, attributes: attributes)
        } catch {
            throw ZipError.other(source.path, error.localizedDescription)
        }
    }
    
    
    static var needAppend = true
    fileprivate static func destinationURL(des: URL?, source: URL, override: Bool, sourceFileName: String) throws -> Destination {
        print(source, sourceFileName)
        var result = des ?? source.deletingLastPathComponent()
        result.appendPathComponent(sourceFileName)
        var append = 1
        if needAppend {
            while FileManager.default.fileExists(atPath: result.path) {
                needAppend = false
                if override {  return result }
                let lastPath = result.lastPathComponent.replacingOccurrences(of: ".", with: "_\(append).")
                result = result.deletingLastPathComponent().appendingPathComponent(lastPath)
                append += 1
            }
        }
        if result.deletingLastPathComponent() == source.deletingLastPathComponent() {
            return result
        }
        if let last = sourceFileName.last, last == "/" {
            try createDirectory(result, source)
            return result
        }
        try createDirectory(result.deletingLastPathComponent(), source)
        return result
    }
    
    //
    // Determine whether this is a symbolic link:
    // - File is stored with 'version made by' value of UNIX (3),
    //   as per http://www.pkware.com/documents/casestudies/APPNOTE.TXT
    //   in the upper byte of the version field.
    // - BSD4.4 st_mode constants are stored in the high 16 bits of the
    //   external file attributes (defacto standard, verified against libarchive)
    //
    // The original constants can be found here:
    //    http://minnie.tuhs.org/cgi-bin/utree.pl?file=4.4BSD/usr/include/sys/stat.h
    //
    fileprivate static func isSystemFile(fileInfo: unz_file_info) -> Bool {
        let ZipUNIXVersion: uLong = 3
        let BSD_SFMT: uLong = 0170000
        let BSD_INLNK: uLong = 0120000
        print(fileInfo.external_fa >> 16, fileInfo.external_fa >> 16 & BSD_SFMT)
        return fileInfo.version >> 8 == ZipUNIXVersion && (BSD_INLNK == (BSD_SFMT & (fileInfo.external_fa >> 16)))
    }
    
    public static func unzip(soruce: CCPArchiveSource, destination: URL? = nil, password: String? = nil, option: ZipOption = .default, override: Bool = false, progressHandler: ProgressCallback? = nil) throws -> [Destination] {
        let url = try soruce.url()
        guard ZipFileHandler.zipExist(url) else {
            throw ZipError.notFound(url.path)
        }
        let bufferSize: UInt32 = 4 * 1024
        var buffer = Array<CUnsignedChar>(repeating: 0, count: Int(bufferSize))
        var rlt: Int32 = 0
        let pg = progress(try ZipFileHandler.size(of: url))
        guard let zip = unzOpen64(url.path) else {
            throw ZipError.cantOpen(url.path)
        }
        defer {
            unzClose(zip)
        }
        var gInfo: unz_global_info = unz_global_info()
        //inital set
        unzGetGlobalInfo(zip, &gInfo)
        var result = [Destination]()
        guard unzGoToFirstFile(zip) == UNZ_OK else {
            throw ZipError.unzipFailed(url.path, "打开第一个文件失败")
        }
        repeat {
            rlt = password != nil ? unzOpenCurrentFilePassword(zip, password!) : unzOpenCurrentFile(zip)
            try throwIfNotOK(rlt, url, "无法打开当前文件")
            var fileInfo = unz_file_info()
            rlt = unzGetCurrentFileInfo(zip, &fileInfo, nil, 0, nil, 0, nil, 0)
            do {
                try throwIfNotOK(rlt, url, "无法获取当前文件信息")
            } catch  {
                unzCloseCurrentFile(zip)
                throw error
            }
            let cFileName = UnsafeMutablePointer<Int8>.allocate(capacity: Int(fileInfo.size_filename) + 1)
            rlt = unzGetCurrentFileInfo(zip, &fileInfo, cFileName, fileInfo.size_filename + 1, nil, 0, nil, 0)
            // cFileName[Int(fileInfo.size_filename)] = 0
            var fileName = String(cString: cFileName)
            fileName = fileName.replacingOccurrences(of: "\\", with: "/")
            free(cFileName)
            let desURL = try destinationURL(des: destination, source: url, override: override, sourceFileName: fileName)
            // TO CRC CHECK
            /*-----*/
            if isSystemFile(fileInfo: fileInfo) {
                var readBytes: Int32 = 0
                var desPath = ""
                repeat {
                    readBytes = unzReadCurrentFile(zip, &buffer, bufferSize)
                    buffer[Int(readBytes)] = 0
                    desPath += String(cString: buffer)
                } while readBytes > 0
                guard let sys = (desPath as NSString).utf8String, let des = (desURL.path as NSString).utf8String, symlink(sys, des) != 0 else {
                    throw ZipError.failedToLinkSystem
                }
            }
            else {
                guard let fp = fopen(desURL.path, "wb") else {
                    unzCloseCurrentFile(zip)
                    if errno == ENOSPC {
                        throw ZipError.other(desURL.path, "打开文件失败")
                    }
                    unzGoToNextFile(zip)
                    continue
                }
                while true {
                    let readBytes = unzReadCurrentFile(zip, &buffer, bufferSize)
                    if readBytes == 0 { break }
                    fwrite(buffer, Int(readBytes), 1, fp)
                }
                fclose(fp)
                if ZipFileHandler.zipExist(desURL) {
                    let urls = try unzip(soruce: desURL, destination: desURL.deletingLastPathComponent(), password: password, option: option, override: override, progressHandler: nil)
                    if urls.count > 0 {
                        do {
                            try FileManager.default.removeItem(at: desURL)
                        } catch {
                            throw  ZipError.other(desURL.path, error.localizedDescription)
                        }
                    }
                }
                let permission = fileInfo.external_fa >> 16
                if permission != 0 {
                    do {
                        try FileManager.default.setAttributes([.posixPermissions : permission], ofItemAtPath: desURL.path)
                    } catch {
                        throw ZipError.other(desURL.path, error.localizedDescription)
                    }
                }
            }
            if unzCloseCurrentFile(zip) == UNZ_CRCERROR {
                throw ZipError.unzipFailed(desURL.path, "关闭当前文件出错")
            }
            rlt = unzGoToNextFile(zip)
            result.append(desURL)
        }
            while (rlt != UNZ_END_OF_LIST_OF_FILE)
        
        
        return result
    }
    
    private static func setupTM(with url: URL, zip: inout zip_fileinfo) throws {
        let dateComponents = try ZipFileHandler.modificationDateComponents(of: url)
        zip.tmz_date.tm_year = UInt32(dateComponents.year ?? 0)
        zip.tmz_date.tm_mon = UInt32(dateComponents.month ?? 0)
        zip.tmz_date.tm_mday = UInt32(dateComponents.day ?? 0)
        zip.tmz_date.tm_hour = UInt32(dateComponents.hour ?? 0)
        zip.tmz_date.tm_min = UInt32(dateComponents.minute ?? 0)
        zip.tmz_date.tm_sec = UInt32(dateComponents.second ?? 0)
    }
    
    private static func progress(_ total: Double) -> Progress {
        let progress = Progress(totalUnitCount: Int64(total))
        progress.isCancellable = false
        progress.isPausable = false
        progress.kind = .file
        return progress
    }
    
    
}
