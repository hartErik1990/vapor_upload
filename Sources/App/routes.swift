import Fluent
import Vapor

func routes(_ app: Application) throws {
    
    app.get("hello") { req in
        return "Hello, vapor!"
    }
    // MARK: /collect
    let collectFileController = CollectFileController()
    app.get("collect", use: collectFileController.index)
    
    /// Using `body: .collect` we can load the request into memory.
    /// This is easier than streaming at the expense of using much more system memory.
    app.on(.POST, "collect",
          // 27_981_973
           body: .collect(maxSize: 40_000_000),
           use: collectFileController.upload)
    app.on(.GET, "collect",
           use: collectFileController.index)
    // MARK: /stream
    let uploadController = StreamController()
    /// using `body: .stream` we can get chunks of data from the client, keeping memory use low.
    app.on(.POST, "stream",
        body: .stream,
        use: uploadController.upload)
    app.on(.POST, "streaming",
           body: .stream,
        use: uploadController.uploading)
    app.on(.GET, "stream", use: uploadController.index)
    app.on(.GET, "stream", ":fileID", use: uploadController.getOne)
    app.on(.GET, "stream", "all", use: uploadController.index)
    //app.on(.GET, "stream", "single", use: uploadController.)
}
