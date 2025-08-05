// Lambda function for CloudMap service discovery example
exports.handler = async (event) => {
    const response = {
        statusCode: 200,
        headers: {
            'Content-Type': 'application/json',
            'Access-Control-Allow-Origin': '*',
            'Access-Control-Allow-Headers': 'Content-Type',
            'Access-Control-Allow-Methods': 'GET, POST, OPTIONS'
        },
        body: JSON.stringify({
            message: 'Hello from Lambda!',
            service: process.env.SERVICE_NAME || 'api-service',
            timestamp: new Date().toISOString(),
            event: {
                httpMethod: event.httpMethod,
                path: event.rawPath,
                headers: event.headers
            }
        })
    };

    return response;
};
