import ballerina/io;
import ballerina/lang.'string as langString;
import ballerina/lang.regexp as regexp;
import ballerina/log;

// Function to parse CSV content into OrderRecord array
function parseCsvContent(stream<byte[] & readonly, io:Error?> fileStream) returns OrderRecord[]|error {
    // Convert stream to string
    string csvContent = "";
    error? result = fileStream.forEach(function(byte[] & readonly chunk) {
        string|error chunkResult = langString:fromBytes(chunk);
        if chunkResult is string {
            csvContent += chunkResult;
        } else {
            // Handle error case - this will cause forEach to return an error
            panic chunkResult;
        }
    });

    if result is error {
        return result;
    }

    // Split into lines using regex
    regexp:RegExp lineRegex = check regexp:fromString("\n");
    string[] lines = lineRegex.split(csvContent);
    OrderRecord[] orders = [];

    // Skip header line (index 0)
    foreach int i in 1 ..< lines.length() {
        string line = lines[i].trim();
        if line.length() > 0 {
            regexp:RegExp commaRegex = check regexp:fromString(",");
            string[] fields = commaRegex.split(line);
            if fields.length() >= 3 {
                OrderRecord orderRecord = {
                    OrderNumber: fields[0].trim(),
                    Status: fields[1].trim(),
                    TrackingNumber: fields[2].trim()
                };
                orders.push(orderRecord);
            }
        }
    }

    return orders;
}

// Function to get Salesforce Order ID by OrderNumber
function getSalesforceOrderId(string orderNumber) returns string|error {
    string soql = string `SELECT Id,OrderNumber FROM Order WHERE OrderNumber='${orderNumber}'`;

    stream<record {}, error?> queryResult = check salesforceClient->query(soql);
    record {}[] orders = check from record {} orderRecord in queryResult
        select orderRecord;

    if orders.length() > 0 {
        record {} firstOrder = orders[0];
        // Extract Id field from the record
        anydata idValue = firstOrder["Id"];
        if idValue is string {
            return idValue;
        } else {
            return error(string `Invalid Id type for OrderNumber: ${orderNumber}`);
        }
    } else {
        return error(string `Order not found for OrderNumber: ${orderNumber}`);
    }
}

// Function to update Salesforce Order
function updateSalesforceOrder(string orderId, string status, string trackingNumber) returns error? {
    OrderUpdate updateData = {
        Status: status,
        Tracking_Number__c: trackingNumber
    };

    _ = check salesforceClient->update(sObjectName = "Order", id = orderId, sObject = updateData);
    log:printInfo(string `Successfully updated Order ${orderId} with Status: ${status}, Tracking: ${trackingNumber}`);
}

// Function to archive processed file
function archiveFile(string originalFilePath) returns error? {
    log:printInfo(string `Archiving file: ${originalFilePath}`);

    // Extract file name from path
    regexp:RegExp pathRegex = check regexp:fromString("/");
    string[] pathParts = pathRegex.split(originalFilePath);
    string fileName = pathParts[pathParts.length() - 1];

    // Construct archived file path
    string archivedPath = string `/InboundFiles/Archived/${fileName}`;

    // Get original file content
    stream<byte[] & readonly, io:Error?> fileStream = check sftpClient->get(originalFilePath);

    // Convert stream to byte array for putting to new location
    byte[] fileContent = [];
    check fileStream.forEach(function(byte[] & readonly chunk) {
        foreach byte b in chunk {
            fileContent.push(b);
        }
    });

    // Put file to archived location
    check sftpClient->put(archivedPath, fileContent);
    log:printInfo(string `File copied to archived location: ${archivedPath}`);

    // Delete original file
    check sftpClient->delete(originalFilePath);
    log:printInfo(string `Original file deleted: ${originalFilePath}`);
}

// Function to process a single CSV file
function processOrderFile(string filePath) returns error? {
    log:printInfo(string `Processing file: ${filePath}`);

    // Get file content
    stream<byte[] & readonly, io:Error?> fileStream = check sftpClient->get(filePath);

    // Parse CSV content
    OrderRecord[] orders = check parseCsvContent(fileStream);
    log:printInfo(string `Found ${orders.length()} orders in file`);

    // Process each order
    foreach OrderRecord orderRecord in orders {
        do {
            log:printInfo(string `Retrieving SF record ID for Order ${orderRecord.OrderNumber}`);
            // Get Salesforce Order ID
            string orderId = check getSalesforceOrderId(orderRecord.OrderNumber);

            // Update the order
            log:printInfo(string `Updating SF record ${orderId} for Order ${orderRecord.OrderNumber}`);
            check updateSalesforceOrder(orderId, orderRecord.Status, orderRecord.TrackingNumber);

        } on fail error e {
            log:printError(string `Failed to process order ${orderRecord.OrderNumber}: ${e.message()}`);
        }
    }

    log:printInfo(string `Completed processing file: ${filePath}`);
}