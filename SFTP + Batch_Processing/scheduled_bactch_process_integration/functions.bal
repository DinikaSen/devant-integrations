import ballerina/ftp;
import ballerina/io;
import ballerina/lang.regexp;
import ballerina/log;
import ballerina/sql;

// Function to get policy enrichment data from MySQL
function getPolicyEnrichmentData(string policyId) returns PolicyEnrichmentData|error {
    sql:ParameterizedQuery query = `
        SELECT c.first_name as clientFirstName, c.last_name as clientLastName, pt.name as policyTypeName
        FROM policies p
        JOIN clients c ON p.client_id = c.client_id
        JOIN policy_types pt ON p.policy_type_id = pt.policy_type_id
        WHERE p.policy_id = ${policyId}
    `;

    PolicyEnrichmentData enrichmentData = check mysqlClient->queryRow(query);
    return enrichmentData;
}

// Function to process a single CSV file
function processCsvFile(string fileName) returns error? {
    log:printInfo("Processing file: " + fileName);

    // Read CSV file from SFTP
    stream<byte[] & readonly, io:Error?> fileStream = check sftpClient->get("/lifequest/underwriting/incoming/" + fileName);

    // Convert stream to string
    byte[] fileContent = [];
    check fileStream.forEach(function(byte[] & readonly chunk) {
        fileContent.push(...chunk);
    });

    string csvContent = check string:fromBytes(fileContent);
    regexp:RegExp lineRegex = re `,?\r?\n`;
    string[] lines = lineRegex.split(csvContent);

    // Skip header line and process data lines
    EnrichedUnderwritingRecord[] enrichedRecords = [];

    foreach int i in 1 ..< lines.length() {
        string line = lines[i].trim();
        if line.length() == 0 {
            continue;
        }

        regexp:RegExp fieldRegex = re `,`;
        string[] fields = fieldRegex.split(line);
        if fields.length() != 5 {
            log:printWarn("Skipping invalid line: " + line);
            continue;
        }

        UnderwritingRecord underwritingRecord = {
            quoteId: fields[0],
            policyId: fields[1],
            status: fields[2],
            decisionDate: fields[3],
            agentId: fields[4]
        };

        // Get enrichment data from MySQL
        PolicyEnrichmentData|error enrichmentResult = getPolicyEnrichmentData(underwritingRecord.policyId);
        if enrichmentResult is error {
            log:printError("Failed to get enrichment data for policy: " + underwritingRecord.policyId, enrichmentResult);
            continue;
        }

        PolicyEnrichmentData enrichmentData = enrichmentResult;
        string clientName = enrichmentData.clientFirstName + " " + enrichmentData.clientLastName;

        EnrichedUnderwritingRecord enrichedRecord = {
            quoteId: underwritingRecord.quoteId,
            policyId: underwritingRecord.policyId,
            status: underwritingRecord.status,
            decisionDate: underwritingRecord.decisionDate,
            agentId: underwritingRecord.agentId,
            clientName: clientName,
            productType: enrichmentData.policyTypeName
        };

        enrichedRecords.push(enrichedRecord);
    }

    // Convert to JSON and write to outgoing location
    json jsonOutput = enrichedRecords.toJson();

    // Extract base filename without extension
    int? csvIndex = fileName.indexOf(".csv");
    string baseFileName = "";
    if csvIndex is int {
        baseFileName = fileName.substring(0, csvIndex);
    } else {
        baseFileName = fileName;
    }
    string jsonFileName = baseFileName + ".json";

    check io:fileWriteJson("/tmp/" + jsonFileName, jsonOutput);

    // Read the JSON file and upload to SFTP outgoing location
    string jsonString = jsonOutput.toJsonString();

    check sftpClient->put("/lifequest/underwriting/outgoing/" + jsonFileName, jsonString);

    // Move original CSV to archive location
    check sftpClient->rename(
        "/lifequest/underwriting/incoming/" + fileName,
        "/lifequest/underwriting/archive/" + fileName
    );

    log:printInfo("Successfully processed file: " + fileName);
}

// Function to scan and process all matching CSV files
function processUnderwritingFiles() returns error? {
    log:printInfo("Starting underwriting file processing job");

    // List files in incoming directory
    ftp:FileInfo[] fileList = check sftpClient->list("/lifequest/underwriting/incoming");
    int processedCount = 0;

    foreach ftp:FileInfo fileInfo in fileList {
        string fileName = fileInfo.name;

        // Check if file matches pattern: underwriting_partner_date.csv
        if fileName.startsWith("underwriting_") && fileName.endsWith(".csv") && fileInfo.isFile {
            error? processResult = processCsvFile(fileName);
            if processResult is error {
                log:printError("Failed to process file: " + fileName, processResult);
                return processResult;
            } else {
                processedCount += 1;
            }
        }
    }

    log:printInfo("Completed underwriting file processing job. Files processed: " + processedCount.toString());
}