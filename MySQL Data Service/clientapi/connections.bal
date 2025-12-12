import ballerina/sql;
import ballerinax/mysql;
import ballerinax/mysql.driver as _;

configurable string dbHost = ?;
configurable int dbPort = ?;
configurable string dbUser = ?;
configurable string dbPassword = ?;
configurable string dbName = ?;

sql:ConnectionPool connPool = { 
    maxOpenConnections: 5,
    maxConnectionLifeTime: 1800,
    minIdleConnections: 2 
};

// MySQL client initialization with proper configuration
final mysql:Client mysqlClient = check new (
    host = dbHost,
    port = dbPort,
    database = dbName,
    user = dbUser,
    password = dbPassword,
    connectionPool = connPool
);

// Function to get MySQL client
public isolated function getMysqlClient() returns mysql:Client {
    return mysqlClient;
}

// Function to close database connection
public isolated function closeDatabaseConnection() returns sql:Error? {
    return mysqlClient.close();
}
