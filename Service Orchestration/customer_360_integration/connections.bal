import ballerinax/mysql;
import ballerina/sql;
import ballerina/http;
import ballerinax/mysql.driver as _;

sql:ConnectionPool connPool = { 
    maxOpenConnections: 5,
    maxConnectionLifeTime: 1800,
    minIdleConnections: 2 
};

// MySQL client initialization
final mysql:Client mysqlClient = check new (
    host = dbHost,
    user = dbUser,
    password = dbPassword,
    database = dbName,
    port = dbPort,
    connectionPool = connPool
);

// HTTP client for quote service
http:Client quoteServiceClient = check new (quoteServiceUrl);

// HTTP client for rule engine
http:Client ruleEngine = check new (ruleEngineUrl);