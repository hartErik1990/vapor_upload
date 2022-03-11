import Fluent

struct CreateStream: AsyncMigration {
    func prepare(on database: Database) async throws {
        return try await database.schema(StreamModel.schema)
            .id()
            .field("fileName", .string, .required)
            .field("fileID", .string, .required)
            .create()
    }
    
    func revert(on database: Database) async throws {
        return try await database.schema(StreamModel.schema).delete()
    }
}
