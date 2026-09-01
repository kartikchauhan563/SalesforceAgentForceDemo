public with sharing class SfOrgAction_CheckOAuth {
    public class Request {
        @InvocableVariable(label='Connection Id' description='Connection id returned by Start Salesforce Org OAuth.')
        public String connectionId;

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
        label='Check Salesforce Org OAuth'
        description='Checks whether the user has finished authorizing the target Salesforce org in the browser.'
    )
    public static List<Response> run(List<Request> requests) {
        Request req = (requests == null || requests.isEmpty() || requests[0] == null) ? new Request() : requests[0];
        SfOrgConnectService.Result result = SfOrgOAuthService.checkAuthorization(req.connectionId);
        Response out = new Response();
        out.success = result.success;
        out.message = result.message;
        out.detailsJson = result.detailsJson;
        out.connectionId = result.connectionId;
        out.organizationId = result.organizationId;
        out.organizationName = result.organizationName;
        out.userName = result.userName;
        out.instanceUrl = result.instanceUrl;
        return new List<Response>{ out };
    }
}
