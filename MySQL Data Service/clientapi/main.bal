import ballerina/http;
import ballerina/sql;
import ballerinax/mysql;

listener http:Listener httpDefaultListener = http:getDefaultListener();

service /lifequest on httpDefaultListener {
    
    // GET all clients
    resource function get clients() returns http:Ok|http:InternalServerError {
        do {
            mysql:Client dbClient = getMysqlClient();
            sql:ParameterizedQuery query = `SELECT * FROM clients`;
            stream<ClientRecord, sql:Error?> clientStream = dbClient->query(query);
            
            ClientRecord[] clients = [];
            error? streamError = clientStream.forEach(function(ClientRecord clientRecord) {
                clients.push(clientRecord);
            });
            
            if streamError is error {
                string errorMessage = streamError.message();
                http:InternalServerError serverError = {
                    body: createErrorResponse("Failed to retrieve clients", errorMessage)
                };
                return serverError;
            }
            
            http:Ok success = {
                body: clients
            };
            return success;
        } on fail error err {
            
            http:InternalServerError serverError = {
                body: createErrorResponse("Internal server error", err.message())
            };
            return serverError;
        }
    }

    // GET client by ID
    resource function get clients/[string clientId]() returns http:Ok|http:NotFound|http:InternalServerError {
        do {
            mysql:Client dbClient = getMysqlClient();
            sql:ParameterizedQuery query = `SELECT * FROM clients WHERE client_id = ${clientId}`;
            ClientRecord|sql:Error clientResult = dbClient->queryRow(query);

            if clientResult is error {
                if clientResult is sql:NoRowsError {
                    http:NotFound notFound = {
                        body: createErrorResponse("Client not found", string `Client with ID ${clientId} not found`)
                    };
                    return notFound;
                }
                string errorMessage = clientResult.message();
                http:InternalServerError serverError = {
                    body: createErrorResponse("Failed to retrieve client", errorMessage)
                };
                return serverError;
            }
            
            http:Ok success = {
                body: clientResult
            };
            return success;
        } on fail error err {
            http:InternalServerError serverError = {
                body: createErrorResponse("Internal server error", err.message())
            };
            return serverError;
        }
    }

    resource function post clients(@http:Payload ClientCreateRequest clientData) returns http:Created|http:BadRequest|http:InternalServerError {
        do {
            mysql:Client dbClient = getMysqlClient();
            string clientId = clientData.client_id;
            string firstName = clientData.first_name;
            string lastName = clientData.last_name;
            string dateOfBirth = clientData.date_of_birth;
            string email = clientData.email;
            string phone = clientData.phone;
            
            sql:ParameterizedQuery insertQuery = `INSERT INTO clients (client_id, first_name, last_name, date_of_birth, email, phone) 
                                                  VALUES (${clientId}, ${firstName}, ${lastName}, 
                                                         ${dateOfBirth}, ${email}, ${phone})`;
            
            sql:ExecutionResult|sql:Error insertResult = dbClient->execute(insertQuery);

            if insertResult is error {
                
                string errorMessage = insertResult.message();
                http:InternalServerError serverError = {
                    body: createErrorResponse("Failed to create client", errorMessage)
                };
                return serverError;
            }

            // Create the client record to return
            ClientRecord createdClient = {
                client_id: clientId,
                first_name: firstName,
                last_name: lastName,
                date_of_birth: dateOfBirth,
                email: email,
                phone: phone
            };

            http:Created created = {
                body: createdClient
            };
            return created;
        } on fail error err {
            http:InternalServerError serverError = {
                body: createErrorResponse("Internal server error", err.message())
            };
            return serverError;
        }
    }

    // UPDATE existing client
    resource function put clients/[string clientId](@http:Payload ClientUpdateRequest clientData) returns http:Ok|http:NotFound|http:InternalServerError {
        do {
            mysql:Client dbClient = getMysqlClient();
            
            // First check if client exists
            sql:ParameterizedQuery checkQuery = `SELECT client_id FROM clients WHERE client_id = ${clientId}`;
            string|sql:Error existsResult = dbClient->queryRow(checkQuery);
            
            if existsResult is error {
                
                if existsResult is sql:NoRowsError {
                    http:NotFound notFound = {
                        body: createErrorResponse("Client not found", string `Client with ID ${clientId} not found`)
                    };
                    return notFound;
                }
                string errorMessage = existsResult.message();
                http:InternalServerError serverError = {
                    body: createErrorResponse("Failed to check client existence", errorMessage)
                };
                return serverError;
            }
            
            // Update the client
            string firstName = clientData.first_name;
            string lastName = clientData.last_name;
            string dateOfBirth = clientData.date_of_birth;
            string email = clientData.email;
            string phone = clientData.phone;
            
            sql:ParameterizedQuery updateQuery = `UPDATE clients SET first_name = ${firstName}, 
                                                  last_name = ${lastName}, date_of_birth = ${dateOfBirth}, 
                                                  email = ${email}, phone = ${phone} 
                                                  WHERE client_id = ${clientId}`;
            
            sql:ExecutionResult|sql:Error updateResult = dbClient->execute(updateQuery);

            if updateResult is error {
                string errorMessage = updateResult.message();
                http:InternalServerError serverError = {
                    body: createErrorResponse("Failed to update client", errorMessage)
                };
                return serverError;
            }

            // Create the updated client record to return
            ClientRecord updatedClient = {
                client_id: clientId,
                first_name: firstName,
                last_name: lastName,
                date_of_birth: dateOfBirth,
                email: email,
                phone: phone
            };

            http:Ok success = {
                body: updatedClient
            };
            return success;
        } on fail error err {
            http:InternalServerError serverError = {
                body: createErrorResponse("Internal server error", err.message())
            };
            return serverError;
        }
    }

    // DELETE client
    resource function delete clients/[string clientId]() returns http:NoContent|http:NotFound|http:InternalServerError {
        do {
            mysql:Client dbClient = getMysqlClient();
            
            // First check if client exists
            sql:ParameterizedQuery checkQuery = `SELECT client_id FROM clients WHERE client_id = ${clientId}`;
            string|sql:Error existsResult = dbClient->queryRow(checkQuery);
            
            if existsResult is error {
                if existsResult is sql:NoRowsError {
                    http:NotFound notFound = {
                        body: createErrorResponse("Client not found", string `Client with ID ${clientId} not found`)
                    };
                    return notFound;
                }
                string errorMessage = existsResult.message();
                http:InternalServerError serverError = {
                    body: createErrorResponse("Failed to check client existence", errorMessage)
                };
                return serverError;
            }
            
            // Delete the client
            sql:ParameterizedQuery deleteQuery = `DELETE FROM clients WHERE client_id = ${clientId}`;
            sql:ExecutionResult|sql:Error deleteResult = dbClient->execute(deleteQuery);

            if deleteResult is error {
                string errorMessage = deleteResult.message();
                http:InternalServerError serverError = {
                    body: createErrorResponse("Failed to delete client", errorMessage)
                };
                return serverError;
            }

            http:NoContent noContent = {};
            return noContent;
        } on fail error err {
            http:InternalServerError serverError = {
                body: createErrorResponse("Internal server error", err.message())
            };
            return serverError;
        }
    }
}