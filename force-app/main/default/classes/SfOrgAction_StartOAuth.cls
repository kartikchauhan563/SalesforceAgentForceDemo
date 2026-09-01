public with sharing class SfOrgAction_StartOAuth {
    public class Request {
        @InvocableVariable(label='Is Sandbox' description='true, yes, sandbox, or test for a sandbox. Leave empty for production.')
        public String isSandbox;
        @InvocableVariable(label='Login URL' description='Optional My Domain, such as https://mycompany.my.salesforce.com.')
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
        @InvocableVariable(label='Connection Id')
        public String connectionId;
        @InvocableVariable(label='Authorize URL')
        public String authorizeUrl;

        public Response() {
        }
    }

    @InvocableMethod(
        label='Start Salesforce Org OAuth'
        description='Creates an authorize link. The user signs in to the target Salesforce org in the browser and clicks Allow. No password is collected in chat.'
    )
    public static List<Response> run(List<Request> requests) {
        Request req = (requests == null || requests.isEmpty() || requests[0] == null) ? new Request() : requests[0];
        SfOrgConnectService.Result result = SfOrgOAuthService.startAuthorization(req.isSandbox, req.loginUrl);
        Response out = new Response();
        out.success = result.success;
        out.message = result.message;
        out.detailsJson = result.detailsJson;
        out.connectionId = result.connectionId;
        out.authorizeUrl = result.authorizeUrl;
        return new List<Response>{ out };
    }
}
