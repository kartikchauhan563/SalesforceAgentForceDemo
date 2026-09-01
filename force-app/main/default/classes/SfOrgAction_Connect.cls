public with sharing class SfOrgAction_Connect {
    public class Request {
        @InvocableVariable(label='Username' description='Salesforce username of the target org, such as user@example.com.')
        public String username;
        @InvocableVariable(label='Password' description='Salesforce password only, without the security token.')
        public String password;
        @InvocableVariable(label='Security Token' description='Optional security token, passed separately from the password.')
        public String securityToken;
        @InvocableVariable(label='Is Sandbox' description='true, yes, sandbox, or test for a sandbox. Leave empty for production.')
        public String isSandbox;
        @InvocableVariable(label='Login URL' description='Optional My Domain, such as https://mycompany.my.salesforce.com. Overrides production vs sandbox.')
        public String loginUrl;

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
        @InvocableVariable(label='Organization Id')
        public String organizationId;
        @InvocableVariable(label='Organization Name')
        public String organizationName;
        @InvocableVariable(label='User Name')
        public String userName;
        @InvocableVariable(label='Instance URL')
        public String instanceUrl;

        public Response() {
        }
    }

    @InvocableMethod(
        label='Connect to Salesforce Org'
        description='Logs into any Salesforce org with username and password and returns org identity. Never store or repeat the password.'
    )
    public static List<Response> run(List<Request> requests) {
        Request req = first(requests);
        return wrap(
            SfOrgConnectService.connect(
                req.username,
                req.password,
                req.securityToken,
                req.isSandbox,
                req.loginUrl
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
        out.organizationId = result.organizationId;
        out.organizationName = result.organizationName;
        out.userName = result.userName;
        out.instanceUrl = result.instanceUrl;
        return new List<Response>{ out };
    }
}
