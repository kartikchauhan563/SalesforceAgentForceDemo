public with sharing class GitHubAction_DeployToAuthorizedOrg {
    public class Request {
        @InvocableVariable(label='Owner' description='GitHub owner. Optional when Repository is owner/repo.')
        public String owner;
        @InvocableVariable(label='Repository' description='Repository name or owner/repo.')
        public String repo;
        @InvocableVariable(label='Owner And Repo' description='Full GitHub owner/repo.')
        public String ownerRepo;
        @InvocableVariable(required=true label='Branch' description='Destination branch containing the copied metadata.')
        public String branch;
        @InvocableVariable(required=true label='Component Paths' description='JSON array, comma-separated, or newline-separated copied paths under force-app.')
        public String componentPaths;
        @InvocableVariable(required=true label='OAuth Connection Id' description='Connection id returned by Salesforce org OAuth authorization.')
        public String connectionId;
        @InvocableVariable(required=true label='Deployment Confirmed' description='True only after the user confirms deployment.')
        public Boolean deploymentConfirmed;
        @InvocableVariable(label='Production Confirmed' description='True only after the user explicitly confirms a production or unknown target.')
        public Boolean productionConfirmed;
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
        label='Deploy Copied Metadata To Authorized Org'
        description='After explicit confirmation, queues validation and deployment of selected branch metadata to an OAuth-authorized Salesforce org.'
    )
    public static List<Response> run(List<Request> requests) {
        Request req = first(requests);
        SfOrgDeployService.SubmitResult result = SfOrgDeployService.submit(
            req.owner,
            req.repo,
            req.ownerRepo,
            req.branch,
            req.componentPaths,
            req.connectionId,
            req.deploymentConfirmed,
            req.productionConfirmed
        );
        Response out = new Response();
        out.success = result.success;
        out.requestId = result.requestId;
        out.referenceId = result.referenceId;
        out.status = result.status;
        out.message = result.message;
        return new List<Response>{ out };
    }

    private static Request first(List<Request> requests) {
        return requests == null || requests.isEmpty() || requests[0] == null
            ? new Request()
            : requests[0];
    }
}
