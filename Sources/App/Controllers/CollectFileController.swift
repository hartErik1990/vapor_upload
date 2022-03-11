//
//  File.swift
//  
//
//  Created by Michael Critz on 4/13/20.
//

import Fluent
import Vapor

struct CollectFileController {
    let logger = Logger(label: "imagecontroller")
    
    func index(req: Request) async throws -> [CollectModel] {
        return try await CollectModel.query(on: req.db).all()
    }
    
    func upload(req: Request) async throws -> CollectModel {
        let image = try req.content.decode(CollectModel.self)
        try await image.save(on: req.db)
        let imageName = image.id?.uuidString ?? "unknown image"
        print(imageName)
        try self.saveFile(name: imageName, data: image.data)
        return image
//        let statusPromise = req.eventLoop.makePromise(of: HTTPStatus.self)
//        saved.whenComplete { someResult in
//            switch someResult {
//            case .success:
//                print("complete")
//                let imageName = image.id?.uuidString ?? "unknown image"
//                do {
//                    print(imageName)
//                    try self.saveFile(name: imageName, data: image.data)
//                    print(image.id)
//                } catch {
//                    print("failed to save file for image")
//                    self.logger.critical("failed to save file for image \(imageName)")
//                    statusPromise.succeed(.internalServerError)
//                }
//                print("succeed to succeed file succeed succeed")
//                statusPromise.succeed(.ok)
//            case .failure(let error):
//                print("boo error")
//                self.logger.critical("failed to save file \(error.localizedDescription)")
//                statusPromise.succeed(.internalServerError)
//            }
//            print("ok yayy")
//            statusPromise.succeed(.ok)
//        }
//        print("statusPromise futureResult")
//        return statusPromise.futureResult
    }
}

extension CollectFileController {
    fileprivate func saveFile(name: String, data: Data) throws {
        let path = FileManager.default
            .currentDirectoryPath.appending("/\(name)")
        print("path futureResult")
        print(path)
//        let fileHandle = try FileHandle(forReadingFrom: url)
//        FileHandle.
        if FileManager.default.createFile(atPath: path,
                                          contents: data,
                                          attributes: nil) {
            debugPrint("saved file\n\t \(path)")
        } else {
            throw FileError.couldNotSave
        }
    }
}

enum FileError: Error {
    case couldNotSave
}
