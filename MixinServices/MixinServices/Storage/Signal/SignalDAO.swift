import GRDB

public class SignalDAO {
    
    public var db: Database {
        SignalDatabase.current
    }
    
}
