import Fluent
import Vapor

final class StreamModel: Model, Content {
    
    init() { }
    
    static let schema = "stream"
    
    @ID(key: .id)
    var id: UUID?
    
    @Field(key: "fileName")
    var fileName: String
    
    @Field(key: "fileID")
    var fileID: String
    
    func filePath(for app: Application) -> String {
        let fileID = $fileID.value ?? ""
        let fileName = $fileName.value ?? ""
        return app.directory.workingDirectory + "uploads/\(fileID)/\(fileName)"
    }
    
//    func fileID() throws -> String {
//        guard let lastOccuranceOfPeriodIndex = fileName.lastIndex(where: {$0 == "."}) else { throw Abort(.notAcceptable) }
//        let fileNameSubString = fileName[fileName.startIndex..<lastOccuranceOfPeriodIndex]
//        let fileID = String(fileNameSubString)
//        return fileID
//    }
//    
    init(id: UUID? = nil,
         fileName: String,
         fileID: String) {
        self.id       = id
        self.fileName = fileName
        self.fileID   = fileID
    }
}
