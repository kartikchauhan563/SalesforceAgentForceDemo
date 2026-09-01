public with sharing class GitHubAction_DeploymentStatus {
    public class Request {
        @InvocableVariable(required=true label='Reference' description='Deployment reference such as SFD-000001.')
        public String referenceId;
    }

    public class Response {
        @InvocableVariable(label='Success')
        public Boolean success;
        @InvocableVariable(label='Request Id')
        public Id requestId;
        @InvocableVariable(label='Reference')
        public String referenceId;
        @InvocableVariable(label='Status')
        public String status;
        @InvocableVariable(label='Message')
        public String message;
    }

    @InvocableMethod(
        label='Get Authorized Org Deployment Status'
        description='Returns validation or deployment status for an SFD reference.'
    )
    public static List<Response> run(List<Request> requests) {
        Request req = requests == null || requests.isEmpty() || requests[0] == null
            ? new Request()
            : requests[0];
        SfOrgDeployService.SubmitResult result = SfOrgDeployService.status(req.referenceId);
        Response out = new Response();
        out.success = result.success;
        out.requestId = result.requestId;
        out.referenceId = result.referenceId;
        out.status = result.status;
        out.message = result.message;
        return new List<Response>{ out };
    }
}
