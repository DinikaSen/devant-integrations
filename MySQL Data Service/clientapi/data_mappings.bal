// Function to create success response
public isolated function createSuccessResponse(anydata data, string? message = ()) returns ApiResponse {
    return {
        message: message,
        data: data
    };
}

// Function to create error response
public isolated function createErrorResponse(string errorMsg, string? message = ()) returns ErrorResponse {
    return {
        'error: errorMsg,
        message: message
    };
}

