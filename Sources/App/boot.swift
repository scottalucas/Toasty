import Vapor
import PostgreSQL

/// Called after your application has initialized.
public func boot(_ app: Application) throws {

    do {
        let _ = try User.setUpUnassignedUserAccount(on: app).wait()
    } catch {
        switch error {
        case let err as ImpError:
            if err.id == .foundDefaultUser {return}
        default:
            print (error)
            fatalError()
        }
    }

}
//UPDATE users SET id = 'FFFFFFFF-0000-0000-0000-000000000000' WHERE id = 'AE4862DD-1A77-4ED6-A0C9-1DA98F04C51E';
