public with sharing class GitHubAction_CopyBranchAssets {
    public class Request {
        @InvocableVariable(label='Owner' description='GitHub owner or org. Optional when Repository is owner/repo.')
        public String owner;
        @InvocableVariable(label='Repository' description='Repo name or owner/repo. Defaults to SalesforceAgentForceDemo.')
        public String repo;
        @InvocableVariable(label='Owner And Repo' description='Full GitHub identifier such as kartikchauhan563/SalesforceAgentForceDemo')
        public String ownerRepo;
        @InvocableVariable(label='New Branch' description='Destination branch that receives the copied assets')
        public String newBranch;
        @InvocableVariable(label='Source Branch' description='Branch whose files should be copied. Defaults to master.')
        public String sourceBranch;
    }

    public class Response {
        @InvocableVariable(label='Success')
        public Boolean success;
        @InvocableVariable(label='Message')
        public String message;
        @InvocableVariable(label='Details JSON')
        public String detailsJson;
        @InvocableVariable(label='Download ZIP URL' description='Click this URL to download the new branch as a zip file.')
        public String branchZipUrl;
        @InvocableVariable(label='Repository')
        public String repository;
        @InvocableVariable(label='Destination Branch')
        public String branch;
        @InvocableVariable(label='Copied Component Paths')
        public String componentPaths;
    }

    @InvocableMethod(
        label='GitHub Copy Branch Assets'
        description='Creates a new GitHub branch that points at the source branch tree so all assets are copied in the cloud with no local clone.'
    )
    public static List<Response> run(List<Request> requests) {
        Request req = first(requests);
        return wrap(GitHubCloudService.copyBranchAssets(req.owner, req.repo, req.ownerRepo, req.sourceBranch, req.newBranch));
    }

    private static Request first(List<Request> requests) {
        return (requests == null || requests.isEmpty() || requests[0] == null) ? new Request() : requests[0];
    }

    private static List<Response> wrap(GitHubCloudService.Result result) {
        Response out = new Response();
        out.success = result.success;
        out.message = result.message;
        out.detailsJson = result.detailsJson;
        out.branchZipUrl = result.branchZipUrl;
        out.repository = result.repository;
        out.branch = result.branch;
        out.componentPaths = result.componentPaths;
        return new List<Response>{ out };
    }
}