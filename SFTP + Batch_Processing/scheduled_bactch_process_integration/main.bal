import ballerina/log;

public function main() returns error? {
    log:printInfo("Starting underwriting batch file processing");
    
    error? result = processUnderwritingFiles();
    
    if result is error {
        log:printError("Batch processing failed", result);
        return result;
    }
    
    log:printInfo("Batch processing completed successfully");
}