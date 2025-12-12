import ballerina/sql;
import ballerina/time;
import ballerina/regex;

// Function to get client details from database
function getClientDetails(string clientId) returns ClientInfo|error {
    sql:ParameterizedQuery query = `SELECT client_id, first_name, last_name, date_of_birth, state_code FROM clients WHERE client_id = ${clientId}`;
    stream<ClientDbRecord, sql:Error?> resultStream = mysqlClient->query(query);
    
    ClientDbRecord[]|error clientRecords = from ClientDbRecord clientRecord in resultStream
        select clientRecord;
    
    if clientRecords is error {
        return clientRecords;
    }
    
    if clientRecords.length() == 0 {
        return error("Client not found");
    }
    
    ClientDbRecord clientRecord = clientRecords[0];
    ClientInfo clientInfo = {
        clientId: clientRecord.client_id,
        firstName: clientRecord.first_name,
        lastName: clientRecord.last_name,
        age: check calculateAge(clientRecord.date_of_birth),
        state: clientRecord.state_code
    };
    
    return clientInfo;
}

// Function to get agent details from database
function getAgentDetails(string agentId) returns AgentInfo|error {

    sql:ParameterizedQuery query = `SELECT 
                    a.agent_id,
                    a.name,
                    GROUP_CONCAT(DISTINCT al.license_code ORDER BY al.license_code) AS licenses,
                    GROUP_CONCAT(DISTINCT at.training_code ORDER BY at.training_code) AS trainings
                FROM 
                    agents a
                LEFT JOIN agent_licenses al ON a.agent_id = al.agent_id
                LEFT JOIN agent_trainings at ON a.agent_id = at.agent_id
                WHERE 
                    a.agent_id = ${agentId}
                GROUP BY 
                    a.agent_id, a.name;`;

    stream<AgentInfo, sql:Error?> resultStream = mysqlClient->query(query);
    
    AgentInfo[]|error agentRecords = from AgentInfo agentRecord in resultStream
        select agentRecord;
    
    if agentRecords is error {
        return agentRecords;
    }
    
    if agentRecords.length() == 0 {
        return error("Agent not found");
    }

    return agentRecords[0];
}

// Function to get new quote from external service
function getNewQuote(string productName, int age, string state, decimal coverageAmount) returns QuoteResponse|error {
    QuoteRequest payload = {
        productName: productName,
        age: age,
        state: state,
        coverageAmount: coverageAmount
    };
    
    map<string|string[]> headers = {};
    
    QuoteResponse|error response = quoteServiceClient->post("", payload, headers);
    
    if response is error {
        return response;
    }
    
    // QuoteResponse quote = check response.cloneWithType(QuoteResponse);
    return response;
}

function checkEligibility(string productName, string state, string licesnses, string trainings) returns boolean|error {

    string[] agentLicensesList = regex:split(licesnses, ",");
    string[] agentTrainingsList = regex:split(trainings, ",");

    RuleEngineRequest requestToRuleEngine = {state: state, product: productName, licenses: agentLicensesList, trainings: agentTrainingsList};
    RuleEngineResponse|error eligibilityResult = ruleEngine->post("", requestToRuleEngine);

    if eligibilityResult is error {
        return eligibilityResult;
    }
    
    return eligibilityResult.eligible;
}

// Function to calculate age from birthdate string
function calculateAge(string birthDateString) returns int|error {
    // Parse the birthdate string to Civil time
    time:Civil|time:Error birthDate = time:civilFromString(birthDateString + "T00:00:00Z");
    if birthDate is time:Error {
        return error("Invalid birthdate format");
    }
    
    // Get current date
    time:Utc currentUtc = time:utcNow();
    time:Civil currentDate = time:utcToCivil(currentUtc);
    
    // Calculate age
    int age = currentDate.year - birthDate.year;
    
    // Adjust if birthday hasn't occurred this year
    if currentDate.month < birthDate.month || 
       (currentDate.month == birthDate.month && currentDate.day < birthDate.day) {
        age = age - 1;
    }
    
    return age;
}
