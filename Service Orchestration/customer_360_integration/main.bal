import ballerina/http;
import ballerina/io;

// HTTP service for client 360 endpoint
service / on new http:Listener(8080) {

    // Resource function to handle GET /clients/{clientId}/quotes/summary
    resource function get clients/[string clientId]/quotes/summary(string productName, decimal coverageAmount, string agentId) returns Client360Response|http:InternalServerError|http:NotFound {

        // Get agent details from database
        AgentInfo|error agentResult = getAgentDetails(agentId);
        if agentResult is error {
            io:println("Error etrieving agent details: " + agentResult.message());
            if agentResult.message() == "Agent not found" {
                http:NotFound notFoundResponse = {
                    body: {
                        message: string `Agent with ID ${agentId} not found`
                    }
                };
                return notFoundResponse;
            }
            http:InternalServerError errorResponse = {
                body: {
                    message: "Error retrieving agent details"
                }
            };
            return errorResponse;
        }

        // Get client details from database
        ClientInfo|error clientResult = getClientDetails(clientId);
        if clientResult is error {
            io:println("Error etrieving client details: " + clientResult.message());
            if clientResult.message() == "Client not found" {
                http:NotFound notFoundResponse = {
                    body: {
                        message: string `Client with ID ${clientId} not found`
                    }
                };
                return notFoundResponse;
            }
            http:InternalServerError errorResponse = {
                body: {
                    message: "Error retrieving client details"
                }
            };
            return errorResponse;
        }

        // Check agent eligibility from rule engine
        boolean|error isEligible = checkEligibility(productName, clientResult.state, agentResult.licenses, agentResult.trainings);
        if isEligible is error {
            io:println("Error validating agent's eligibility: " + isEligible.message());
            http:InternalServerError errorResponse = {
                body: {
                    message: "Error validating agent eligibility"
                }
            };
            return errorResponse;
        }

        Client360Response finalResponse = {
            eligibility: ""
        };

        if (isEligible) {
            // Get new quote from external service
            QuoteResponse|error quoteResult = getNewQuote(productName, clientResult.age, clientResult.state, coverageAmount);
            if quoteResult is error {
                io:println("Error retrieving quote information: " + quoteResult.message());
                http:InternalServerError errorResponse = {
                    body: {
                        message: "Error retrieving quote information"
                    }
                };
                return errorResponse;
            }

            ClientQuoteSummary finalQuoteSummary = transform(clientResult, quoteResult);
            NewQuoteResponse newQuoteResponse = transform1(clientResult, quoteResult);

            finalResponse = {
                eligibility: "You are eligible to sell this product to the customer",
                "newQuoteResponse": newQuoteResponse
            };
        } else {
            finalResponse = {
                eligibility: "Sorry, You are not eligible to sell this product to the customer"
            };
        }

        return finalResponse;
    }
}
