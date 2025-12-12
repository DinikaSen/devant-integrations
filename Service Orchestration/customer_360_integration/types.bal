public type ClientDbRecord record {|
    string client_id;
    string first_name;
    string last_name;
    string state_code;
    string date_of_birth;
|};

public type ClientInfo record {|
    string clientId;
    string firstName;
    string lastName;
    int age;
    string state;
|};

type AgentInfo record {|
    string agent_id;
    string name;
    string licenses;
    string trainings;
|};

type QuoteRequest record {|
    string productName;
    string state;
    int age;
    decimal coverageAmount;
|};

public type QuoteResponse record {|
    string id;
    string productName;
    int age;
    decimal coverageAmount;
    string state;
    decimal estimatedPremium;
    string status;
|};

public type Client360Response record {|
    string eligibility?;
    ClientQuoteSummary quoteSummary?;
    anydata...;
|};

// Error response record
public type ErrorResponse record {|
    string message;
|};

type Client record {|
    string clientId;
    string name;
    int age;
    string state;
|};

type NewQuote record {|
    string quoteId;
    string product;
    decimal coverage;
    decimal premium;
|};

type ClientQuoteSummary record {|
    Client 'client;
    NewQuote newQuote;
|};

type RuleEngineRequest record {|
    string state;
    string product;
    string[] licenses;
    string[] trainings;
|};

type RuleEngineResponse record {|
    boolean eligible;
    string[] reasons;
    string[] suggestions;
|};

type AgentEligibilityResponse record {|
    string agent_id;
    string product;
    boolean eligible;
    string[] reasons?;
    string[] suggestions?;
|};

type NewQuoteResponse record {|
    string 'client;
    int age;
    string state;
    string product;
    decimal coverage;
    decimal premium;
|};
