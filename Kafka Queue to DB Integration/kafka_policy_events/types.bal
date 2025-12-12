type AddressChangeMessage record {|
    string eventType;
    string timestamp;
    string clientId;
    record {|
        string street;
        string city;
        string state;
        string zip;
    |} newAddress;
|};

type QuoteApprovalMessage record {|
    string eventType;
    string timestamp;
    string quoteId;
    string newStatus;
    string changedBy;
|};

type QuoteUpdateRequest record {|
    string status;
|};
