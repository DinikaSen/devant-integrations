import ballerina/http;
import ballerina/log;
import ballerinax/kafka;

listener kafka:Listener lifeQuestEventsListener = new (bootstrapServers = kafkaServer, topics = ["lifequest-events"], securityProtocol = kafka:PROTOCOL_SSL, groupId = "consumer-group-1", secureSocket = {
    cert: kafkaCACert,
    key: {
        certFile: kafkaServiceCert,
        keyFile: kafkaServiceKey
    },
    protocol: {
        name: kafka:TLS
    }
}
);

service kafka:Service on lifeQuestEventsListener {

    remote function onConsumerRecord(kafka:AnydataConsumerRecord[] records) returns error? {

        foreach kafka:AnydataConsumerRecord kafkaRecord in records {

            log:printInfo("Received message from Kafka",
                    topic = kafkaRecord.offset.partition.topic,
                    partition = kafkaRecord.offset.partition.partition,
                    offset = kafkaRecord.offset.offset
            );

            anydata messageValue = kafkaRecord.value;
            string payloadTypeString = (typeof messageValue).toString();
            log:printInfo("Raw message payload type", payloadType = payloadTypeString);

            do {
                // Handle different types of message values including bytes
                string messageStr;
                if messageValue is byte[] {
                    messageStr = check string:fromBytes(messageValue);
                } else if messageValue is string {
                    messageStr = messageValue;
                } else {
                    messageStr = messageValue.toString();
                }

                //log:printInfo("Raw message content", messageContent = messageStr);

                json messageJson = check messageStr.fromJsonString();

                // Safe access to eventType field
                if messageJson is map<json> {
                    json eventTypeJson = messageJson["eventType"];
                    if eventTypeJson is string {
                        string eventType = eventTypeJson;

                        log:printInfo("Processing message", eventType = eventType);

                        if eventType == "ADDRESS_CHANGE" {
                            AddressChangeMessage addressChangeMessage = check messageJson.cloneWithType();
                            check handleAddressChange(addressChangeMessage);
                            log:printInfo("Address change processed successfully", clientId = addressChangeMessage.clientId);
                        } else if eventType == "QUOTE_STATUS_UPDATE" {
                            QuoteApprovalMessage quoteApprovalMessage = check messageJson.cloneWithType();
                            check handleQuoteApproval(quoteApprovalMessage);
                            log:printInfo("Quote approval processed successfully", quoteId = quoteApprovalMessage.quoteId);
                        } else {
                            log:printWarn("Unknown event type received", eventType = eventType);
                        }
                    } else {
                        log:printError("eventType field is not a string or missing", messageJson = messageJson);
                    }
                } else {
                    log:printError("Message is not a JSON object", messageJson = messageJson);
                }
            } on fail error err {
                log:printError("Failed to process individual message",
                        'error = err,
                        topic = kafkaRecord.offset.partition.topic,
                        partition = kafkaRecord.offset.partition.partition,
                        offset = kafkaRecord.offset.offset
                );
            }
        }
    }

    remote function onError(kafka:Error kafkaError) returns error? {
        log:printError("Kafka consumer error occurred", 'error = kafkaError);
    }
}

function handleAddressChange(AddressChangeMessage addressMessage) returns error? {
    log:printInfo("Processing address change",
            clientId = addressMessage.clientId,
            street = addressMessage.newAddress.street,
            city = addressMessage.newAddress.city,
            state_code = addressMessage.newAddress.state,
            zip = addressMessage.newAddress.zip
    );

    // Update client address in database
    _ = check clientDB->execute(`
        UPDATE clients 
        SET street = ${addressMessage.newAddress.street},
            city = ${addressMessage.newAddress.city},
            state_code = ${addressMessage.newAddress.state},
            zip = ${addressMessage.newAddress.zip}
        WHERE client_id = ${addressMessage.clientId}
    `);

    log:printInfo("Address change written to database successfully", clientId = addressMessage.clientId);
    return;
}

function handleQuoteApproval(QuoteApprovalMessage quoteApprovalMessage) returns error? {
    log:printInfo("Processing quote approval",
            quoteId = quoteApprovalMessage.quoteId,
            newStatus = quoteApprovalMessage.newStatus,
            changedBy = quoteApprovalMessage.changedBy,
            timestamp = quoteApprovalMessage.timestamp
    );

    QuoteUpdateRequest quoteUpdateRequest = {
        status: quoteApprovalMessage.newStatus
    };

    log:printInfo("Sending quote approval to remote endpoint",
            quoteId = quoteApprovalMessage.quoteId
    );

    http:Response response = check quotesEndpoint->patch("/" + quoteApprovalMessage.quoteId, quoteUpdateRequest);

    if response.statusCode >= 200 && response.statusCode < 300 {
        log:printInfo("Quote status update sent successfully",
                quoteId = quoteApprovalMessage.quoteId,
                statusCode = response.statusCode
        );
    } else {
        log:printError("Failed to send quote status",
                quoteId = quoteApprovalMessage.quoteId,
                statusCode = response.statusCode
        );
        return error("Failed to send quote state update request");
    }

    return;
}
