//
//  CCPZipError.swift
//  CCPZip
//
//  Created by 储诚鹏 on 2019/12/12.
//  Copyright © 2019 储诚鹏. All rights reserved.
//

import UIKit

public enum ZipError: Error {
    case notFound(_ url: String)
    case cantOpen(_ url: String)
    case zipFailed(_ url: String, _ reason: String)
    case unzipFailed(_ url: String, _ reason: String)
    case invalidSource(_ url: String)
    case other(_ url: String, _ reason: String)
    case emptySource
    case failedToLinkSystem
}

extension ZipError: LocalizedError {
    public var errorDescription: String? {
        let base = "[ZipError🐯🐯🐯]--"
        switch self {
        case .notFound(let url):
            return base + "not found file in url: \(url)"
        case .cantOpen(let url):
            return base + "can not open file in url: \(url)"
        case .zipFailed(let url, let reason):
            return base + "failed to zip in url: \(url), reason: \(reason)"
        case .unzipFailed(let url, let reason):
            return base + "failed to unzip in url: \(url), reason: \(reason)"
        case .invalidSource(let url):
            return base + "invalid soruce: \(url)"
        case .emptySource:
            return base + "empty url"
        case .other(let url, let reason):
            return base + "'\(url)' break in '\(reason)'"
        case .failedToLinkSystem:
            return base + "系统文件链接失败"
        }
    }
}


