public with sharing class SfOrgAction_GetRecords {
    public class Request {
        @InvocableVariable(label='Username' description='Salesforce username of the target org.')
        public String username;
        @InvocableVariable(label='Password' description='Salesforce password only, without the security token.')
        public String password;
        @InvocableVariable(label='Security Token' description='Optional security token, passed separately from the password.')
        public String securityToken;
        @InvocableVariable(label='Is Sandbox' description='true, yes, sandbox, or test for a sandbox. Leave empty for production.')
        public String isSandbox;
        @InvocableVariable(label='Login URL' description='Optional My Domain URL of the target org.')
        public String loginUrl;
        @InvocableVariable(label='Connection Id' description='OAuth connection id from Start Salesforce Org OAuth. Prefer this over username and password.')
        public String connectionId;
        @InvocableVariable(label='Object API Name' description='Object to query, such as Account, Contact, Opportunity, or a custom object API name.')
        public String objectApiName;
        @InvocableVariable(label='Fields' description='Optional comma-separated field API names. Defaults to standard fields.')
        public String fields;
        @InvocableVariable(label='Where Clause' description='Optional filter without the WHERE keyword, such as Name LIKE \'Acme%\'.')
        public String whereClause;
        @InvocableVariable(label='Record Limit' description='Maximum rows to return. Defaults to 10 and caps at 50.')
        public String recordLimit;

        public Request() {
        }
    }

    public class Response {
        @InvocableVariable(label='Success')
        public Boolean success;
        @InvocableVariable(label='Message')
        public String message;
        @InvocableVariable(label='Details JSON')
        public String detailsJson;
        @InvocableVariable(label='Record Count')
        public Integer recordCount;

        public Response() {
        }
    }

    @InvocableMethod(
        label='Get Salesforce Org Records'
        description='Reads records for one sObject using an OAuth connection id or username and password.'
    )
    public static List<Response> run(List<Request> requests) {
        Request req = first(requests);
        return wrap(
            SfOrgConnectService.getRecords(
                req.username,
                req.password,
                req.securityToken,
                req.isSandbox,
                req.loginUrl,
                req.objectApiName,
                req.fields,
                req.whereClause,
                req.recordLimit,
                req.connectionId
            )
        );
    }

    private static Request first(List<Request> requests) {
        return (requests == null || requests.isEmpty() || requests[0] == null) ? new Request() : requests[0];
    }

    private static List<Response> wrap(SfOrgConnectService.Result result) {
        Response out = new Response();
        out.success = result.success;
        out.message = result.message;
        out.detailsJson = result.detailsJson;
        out.recordCount = result.recordCount;
        return new List<Response>{ out };
    }
}
