import ballerina/ftp;
import ballerina/sql;
import ballerinax/mysql;
import ballerinax/mysql.driver as _;

// SFTP client initialization
public final ftp:Client sftpClient = check new (sftpConfig);

sql:ConnectionPool connPool = { 
    maxOpenConnections: 5,
    maxConnectionLifeTime: 1800,
    minIdleConnections: 2 
};

// MySQL client initialization
public final mysql:Client mysqlClient = check new (
    host = dbHost,
    port = dbPort,
    user = dbUsername,
    password = dbPassword,
    database = dbName,
    connectionPool = connPool
);
