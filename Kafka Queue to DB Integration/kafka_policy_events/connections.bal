import ballerina/http;
import ballerina/sql;
import ballerinax/mysql;
import ballerinax/mysql.driver as _;

sql:ConnectionPool connPool = { 
    maxOpenConnections: 5,
    maxConnectionLifeTime: 1800,
    minIdleConnections: 2 
};

// MySQL client initialization with proper configuration
// MySQL client initialization with proper configuration
final mysql:Client clientDB = check new (
    host = clientDBUrl,
    port = clientDBPort,
    database = clientDBName,
    user = clientDBUser,
    password = clientDBPassword,
    connectionPool = connPool
);

final http:Client quotesEndpoint = check new (quoteApprovalEndpoint);
