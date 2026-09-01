public with sharing class SfOrgAction_Query {
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
        @InvocableVariable(label='SOQL' description='Read-only SELECT statement, for example SELECT Id, Name FROM Account LIMIT 10.')
        public String soql;

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
        label='Query Salesforce Org'
        description='Runs a read-only SOQL query against a Salesforce org using an OAuth connection id or username and password.'
    )
    public static List<Response> run(List<Request> requests) {
        Request req = first(requests);
        return wrap(
            SfOrgConnectService.query(
                req.username,
                req.password,
                req.securityToken,
                req.isSandbox,
                req.loginUrl,
                req.soql,
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
