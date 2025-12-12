// Record representing a single order from CSV
public type OrderRecord record {|
    string OrderNumber;
    string Status;
    string TrackingNumber;
|};

// Record for updating Salesforce Order
public type OrderUpdate record {|
    string Status;
    string Tracking_Number__c;
|};