import ballerina/ftp;
import ballerinax/salesforce;


final ftp:Client sftpClient = check new({
    protocol: ftp:SFTP,
    host: ftpHost,
    auth: {
        credentials: {
            username: ftpUsername,
            password: ftpPassword
        }
    },
    port: ftpPort
});

// Salesforce Client
final salesforce:Client salesforceClient = check new ({
    baseUrl: salesforceBaseUrl,
    auth: {
        refreshUrl: salesforceRefreshUrl,
        refreshToken: salesforceRefreshToken,
        clientId: salesforceClientId,
        clientSecret: salesforceClientSecret
    }
});
