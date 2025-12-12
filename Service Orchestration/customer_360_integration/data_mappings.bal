function transform(ClientInfo clientInfo, QuoteResponse quoteInfo) returns ClientQuoteSummary => let var full_name = clientInfo.firstName + " " + clientInfo.lastName in {
        'client: {clientId: clientInfo.clientId, name: full_name, age: clientInfo.age, state: clientInfo.state},
        newQuote: {quoteId: quoteInfo.id, product: quoteInfo.productName, coverage: quoteInfo.coverageAmount, premium: quoteInfo.estimatedPremium}
    };

function transform1(ClientInfo clientInfo, QuoteResponse quoteResponse) returns NewQuoteResponse => {
    age: clientInfo.age,
    state: clientInfo.state,
    product: quoteResponse.productName,
    coverage: quoteResponse.coverageAmount,
    premium: quoteResponse.estimatedPremium
,
    'client: clientInfo.firstName + " " + clientInfo.lastName
};
