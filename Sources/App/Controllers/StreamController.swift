import Fluent
import Vapor
import NIOCore

struct StreamController {
    static let partSize = 4096
    let logger = Logger(label: "StreamController")
    
    func index(req: Request) async throws -> [StreamModel] {
        try await StreamModel.query(on: req.db).all()
    }
    
    func getTestVideo(_ req: Request) throws -> Response {
        // add controller code here
        // to determine which image is returned
        let inputPath = fileName(with: req.headers)
        let thisStreamModel = try await getStreamModel(id: inputPath, req: req)
        let thisModelID = thisStreamModel?.fileID
        
        let currentUploadDirectory = getCurrentUploadDirectory(app: req.application, fileToWriteTo: thisModelID!)

        let filePath = "\(currentUploadDirectory)/iframe_index.m3u8"
        let fileUrl = URL(fileURLWithPath: filePath)

        do {
            let data = try Data(contentsOf: fileUrl)
            let body = req.body
            let header = req.headers
            "m3u8": HTTPMediaType(type: "application", subType: "x-mpegURL")
            // makeResponse(body: LosslessHTTPBodyRepresentable, as: MediaType)
            let response: Response = Response(status: .ok, version: .http2, headers: .init([("m3u8", "x-mpegURL"),
                                                                                           ]), body: .init(data: data))
            return response
        } catch {
            let response: Response = request.makeResponse("image not available")
            return response
        }
    }
    func getStreamModel(id: String, req: Request) async throws -> StreamModel? {
        try await StreamModel.query(on: req.db)
            .filter(\.$fileID == id)
            .first()
    }
    
    func getStreamUrlPath(id: String, req: Request) async throws -> String? {
        try await getStreamModel(id: id, req: req)?
            .filePath(for: req.application)
    }
    
    func getOne(req: Request) async throws -> StreamModel {
        guard let streamModel = try await StreamModel.query(on: req.db).first() else {
            throw Abort(.notAcceptable)
        }
//
//        guard let streamModel = try await StreamModel.find(req.parameters.get("fileID"), on: req.db) else {
//            throw Abort(.notAcceptable)
//        }
        return streamModel
    }
    
    /// Streaming download comes with Vapor “out of the box”.
    /// Call `req.fileio.streamFile` with a path and Vapor will generate a suitable Response.
    func downloadOne(req: Request) async throws -> Response {
        let getOne = try await getOne(req: req)
        let fileName = getOne.fileName
        // try await getOne(req: req).map { upload -> Response in
        return req.fileio.streamFile(at: fileName, chunkSize: 4096, mediaType: .any) { result in
            switch result {
            case .failure(let error):
                debugPrint(error.localizedDescription)
            case .success(_):
                debugPrint("Success")
            }
        }
        //return req.fileio.streamFile(at: getOne.filePath(for: req.application))
        // }
    }
    
    func upload(req: Request) async throws -> HTTPStatus {
        //print(req.headers)
        let inputPath = fileName(with: req.headers)
        //print(inputPath)
        let duration = duration(with: req.headers)
        let createFreshVideo = "\(UUID().uuidString).mp4"
        let thisStreamModel = try await getStreamModel(id: inputPath, req: req)
        let thisModelID = thisStreamModel?.fileID
        let fileToWriteTo = thisModelID == nil ? inputPath : thisModelID
        //let videoID = fileToWriteTo == nil ? thisModelID
        print(thisStreamModel)
        print(thisModelID)
       // let path = req.application.directory.publicDirectory + inputPath
        //let path = req.application.directory.workingDirectory + inputPath
        
        let createdPath = FileManager.default
            .currentDirectoryPath.appending("/uploads/\(createFreshVideo)")
     
        //print(createdPath)
        //print(createdPath)
        let file = File(data: "", filename: createdPath)
        
        //print(file)
        let fileIO = req.application.fileio
//        let fileHandle = try await fileIO.openFile(path: path,
//                                                   mode: .write,
//                                                   flags: .allowFileCreation(posixMode: 0x744),
//                                                   eventLoop: req.eventLoop).get()
        let handle = try await fileIO.openFile(path: createdPath,
                                               mode: .write,
                                               flags: .allowFileCreation(posixMode: 0x777),
                                               eventLoop: req.eventLoop).get()
        var sequential = req.eventLoop.makeSucceededFuture(())
        let promise = req.eventLoop.makePromise(of: HTTPStatus.self)
        req.body.drain {
            switch $0 {
            case .buffer(let chunk):
                sequential = sequential.flatMap {
                    //print("fileIO.write")
                    //print(chunk.readableBytes)
                    return fileIO.write(fileHandle: handle, buffer: chunk, eventLoop: req.eventLoop)
                }
                return sequential
            case .error(let error):
                promise.fail(error)
                //print("error")
                return req.eventLoop.makeSucceededFuture(())
            case .end:
                //print("end")
                promise.succeed(.ok)
                return req.eventLoop.makeSucceededFuture(())
            }
        }
        let status = try await promise.futureResult.get()
        defer { try? handle.close() }
        switch status {
        case .ok:
            //let model = StreamModel(fileName: createdPath)
            print("model")
           // try? handle.close()
           
//            print("model")
//            try await model.save(on: req.db)
           // print(model)
            let currentUploadDirectory = getCurrentUploadDirectory(app: req.application, fileToWriteTo: fileToWriteTo!)
            let executableURL = "/Users/civilgisticslabs/Downloads/VaporUploads-main copy/Sources/App/MediaFileSegmenter/mediafilesegmenter"
            let fileOutputToWriteTo = currentUploadDirectory
            let _ = try safeShell(durationOfVideo: duration, videoFile: createdPath, fileOutputToWriteTo: fileOutputToWriteTo, executableURL: executableURL)
            let iframePath = currentUploadDirectory + "/iframe_index.m3u8"
            let model = StreamModel(fileName: iframePath, fileID: fileToWriteTo!)
            try await model.save(on: req.db)
            
//            let iFrameIndex = iFrameIndex(with: req.headers)
//
//            if FileManager.default.contents(atPath: iframePath) != nil {
//                try iFrameIndex.write(toFile: iframePath, atomically: false, encoding: .utf8)
//            }
//            FileManager.default
//                .currentDirectoryPath.appending("/uploads/iframe_index.m3u8")
//
            
//            let url = URL(fileURLWithPath: iframePath)
//            print(try Data(contentsOf: url).count)
//            print(iFrameIndex)
            //try await model.save(on: req.db)
        default:
            break
        }
        return status
    }
    
    
    func safeShell(durationOfVideo: String, videoFile: String, fileOutputToWriteTo fileOutput: String, executableURL: String) throws -> String {
        let task = Process()
        let pipe = Pipe()
        
        task.standardOutput = pipe
        task.standardError = pipe
        task.arguments = ["-t", durationOfVideo, videoFile, "-f", fileOutput]
        task.executableURL = URL(fileURLWithPath: executableURL) //<--updated
        task.qualityOfService = .userInteractive
        try task.run() //<--updated
        
        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        let output = String(data: data, encoding: .utf8)!
        dump(output)
        return output
    }
    
    func fileUpload(req: Request) async throws -> HTTPStatus {
        
        return .ok
    }
//        print(req.content.contentType?.parameters)
//        print(req.client)
//        print(req)
//        print(fileName(with: req.headers))
//        let inputPath = fileName(with: req.headers)
//       // let path = req.application.directory.workingDirectory + inputPath
//        let createdPath = FileManager.default
//            .currentDirectoryPath.appending("/\(inputPath)")
//
//        let file = File(data: "", filename: createdPath)
//        guard FileManager.default.createFile(atPath: createdPath,
//                                       contents: nil,
//                                       attributes: nil) else {
//            logger.critical("Could not upload \(createdPath)")
//            throw Abort(.internalServerError)
//        }
//        let fileIO = req.application.fileio
//        let fileHandle = try await fileIO.openFile(path: createdPath,
//                                                   mode: .write,
//                                                   flags: .allowFileCreation(posixMode: 0x744),
//                                                   eventLoop: req.eventLoop).get()
//
//        print("Upload huge files (100s of gigs, even)")
//       //let promise = req.eventLoop.makePromise(of: HTTPStatus.self)
//       req.body.drain({ part in
//           switch part {
//            case .buffer(let buffer):
//                print("- Problem 1: If we don’t handle the body as a stream, we’ll end up loading the entire file into memory on request.")
//                return fileIO.write(
//                    fileHandle: fileHandle,
//                    buffer: buffer,
//                    eventLoop: req.eventLoop)
//            case .error(let error):
//                print("- Problem 2: Needs to scale for hundreds or thousands of concurrent transfers. So, proper memory management is")
//               print(file)
//               print(error.localizedDescription)
//               print(fileHandle.description)
//                try! fileHandle.close()
//                return req.eventLoop.makeSucceededFuture(())
//            case .end:
//                print("file")
//                print(file)
//                print("crucial.")
//               // promise.succeed(.ok)
//                try! fileHandle.close()
//                return req.eventLoop.makeSucceededFuture(())
//            }
//       })
//        print("- Problem 2:")
//        return .ok
//
//        //  return promise.futureResult
//
//        // FileManager.default.currentDirectoryPath
//        // req.application.directory.
//        //        let model = StreamModel(fileName: path)
//        //        try await model.save(on: req.db)
////        let response = Response(body: .init(stream: { writer in
////            print("stream")
////            // let promise = req.eventLoop.makePromise(of: Void.self)
////            print("promise")
////            req.body.drain { part in
////                switch part {
////                case .buffer(let buffer):
////                    print("- Problem 1: If we don’t handle the body as a stream, we’ll end up loading the entire file into memory on request.")
////                    return writer.write(.buffer(buffer))
////                    //                    return req.application.fileio.write(
////                    //                        fileHandle: fileHandle,
////                    //                        buffer: buffer,
////                    //                        eventLoop: req.eventLoop
////                    //                    )
////                case .error(let error):
////                    print("- Problem 2: Needs to scale for hundreds or thousands of concurrent transfers. So, proper memory management is")
////
////                    print(error)
////                    // promise.fail(error)
////                    return writer.write(.error(error))
////                    //defer { try! writer.eventLoop.close() }
////                    // return try await req.eventLoop.makeSucceededVoidFuture().get()
////                case .end:
////                    // let end = try await writer.write(.buffer(<#T##ByteBuffer#>)).get()
////                    print("file")
////                    print(file)
////                    print("crucial.")
////                    // promise.succeed(())
////                    return writer.write(.end)
////                    //defer { try! writer.eventLoop.close() }
////                    // return req.eventLoop.makeSucceededFuture(())
////                }
////                // return promise.futureResult
////            }
////        }))
//       // return response
//        //.encodeResponse(for: req)
//        //        return try await req.application.fileio.openFile(path: file.filename,
//        //                                                         mode: .write,
//        //                                                         flags: .allowFileCreation(posixMode: 0x744),
//        //                                                         eventLoop: req.eventLoop)
//        //            .flatMap { fileHandle in
//        //                print("Upload huge files (100s of gigs, even)")
//        //                let promise = req.eventLoop.makePromise(of: HTTPStatus.self)
//        //                req.body.drain { part in
//        //                    switch part {
//        //                    case .buffer(let buffer):
//        //                        print("- Problem 1: If we don’t handle the body as a stream, we’ll end up loading the entire file into memory on request.")
//        //                        return req.application.fileio.write(
//        //                            fileHandle: fileHandle,
//        //                            buffer: buffer,
//        //                            eventLoop: req.eventLoop
//        //                        )
//        //                    case .error(let error):
//        //                        print("- Problem 2: Needs to scale for hundreds or thousands of concurrent transfers. So, proper memory management is")
//        //                        promise.fail(error)
//        //                        try! fileHandle.close()
//        //                        return req.eventLoop.makeSucceededFuture(())
//        //                    case .end:
//        //                        print("file")
//        //                        print(file)
//        //                        print("crucial.")
//        //                        promise.succeed(.ok)
//        //                        try! fileHandle.close()
//        //                        return req.eventLoop.makeSucceededFuture(())
//        //                    }
//        //                }
//        //                print("- Problem 2:")
//        //                return promise.futureResult
//        //            }.get()
//    }
    
    static func getFileSize(file: URL) throws -> (Int, Int) {
        do {
            let resources = try file.resourceValues(forKeys:[.totalFileAllocatedSizeKey])
            guard let fileAllocatedSize = resources.fileAllocatedSize else {
                throw Abort(.created)
            }
            let blocksInDouble = ceil(Double(fileAllocatedSize) / Double(Self.partSize))
            let blocks = Int(blocksInDouble)
            return (fileAllocatedSize, blocks)
        } catch {
            throw Abort(.conflict)
        }
    }
}

struct CompletedPart: Content {
    let eTag: ETag
    let partNumber: Int32
}

struct ETag: Content {
    let file: URL
    let uploadID: String
    let part: Int
    let data: Data
    let totalSize: Int
}

struct NewFile: Content {
    
   // var fileID: String
    var iframeData: Data
    var data: Data
//
//    func fileID() throws -> String {
//        guard let lastOccuranceOfPeriodIndex = fileName.lastIndex(where: {$0 == "."}) else { throw Abort(.notAcceptable) }
//        let fileNameSubString = fileName[fileName.startIndex..<lastOccuranceOfPeriodIndex]
//        let fileID = String(fileNameSubString)
//        return fileID
//    }
}
