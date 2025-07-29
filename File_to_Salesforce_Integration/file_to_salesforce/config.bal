// SFTP Configuration
configurable string ftpHost = ?;
configurable int ftpPort = 22;
configurable string ftpUsername = ?;
configurable string ftpPassword = ?;
configurable string ftpFilePath = "/InboundFiles";
configurable string ftpFilePattern = "(*).csv";

// Salesforce Configuration
configurable string salesforceBaseUrl = ?;
configurable string salesforceClientId = ?;
configurable string salesforceClientSecret = ?;
configurable string salesforceRefreshUrl = ?;
configurable string salesforceRefreshToken = ?;
