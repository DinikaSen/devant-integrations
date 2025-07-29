import ballerina/ftp;
import ballerina/log;

listener ftp:Listener orderStatusFileListener = check new({
    protocol: ftp:SFTP,
    host: ftpHost,
    auth: {
        credentials: {
            username: ftpUsername,
            password: ftpPassword
        }
    },
    port: 22,
    path: "/InboundFiles",
    pollingInterval: 2,
    fileNamePattern: "(.*).csv"
});

service ftp:Service on orderStatusFileListener {
    remote function onFileChange(ftp:WatchEvent & readonly watchEvent, ftp:Caller caller) returns error? {
        log:printInfo("File change event detected");
        
        // Process added files
        foreach ftp:FileInfo addedFile in watchEvent.addedFiles {
            string filePath = addedFile.pathDecoded;
            log:printInfo("File added: " + filePath);
            
            // Process the file
            do {
                check processOrderFile(addedFile.pathDecoded);
                
                // Archive the processed file
                check archiveFile(addedFile.pathDecoded);
                log:printInfo(string `Successfully archived file: ${filePath}`);
                
            } on fail error e {
                log:printError(string `Error processing file ${filePath}: ${e.message()}`);
                do {
                    check archiveFile(addedFile.pathDecoded);
                    log:printInfo(string `File archived despite processing error: ${filePath}`);
                } on fail error archiveError {
                    log:printError(string `Failed to archive file ${filePath}: ${archiveError.message()}`);
                }
            }
        }
        
        // Log deleted files
        foreach string deletedFile in watchEvent.deletedFiles {
            log:printInfo("File deleted: " + deletedFile);
        }
    }
}