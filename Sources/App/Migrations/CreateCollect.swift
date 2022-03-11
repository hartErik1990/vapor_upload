import Fluent

struct CreateCollect: AsyncMigration {
    func prepare(on database: Database) async throws {
        return try await database.schema(CollectModel.schema)
            .id()
            .field("data", .data, .required)
            .create()
    }
    
    func revert(on database: Database) async throws {
        return try await database.schema(CollectModel.schema).delete()
    }
}
