public with sharing class GitHubAction_CreateComponent {
    public class Request {
        @InvocableVariable(label='Owner' description='GitHub owner or org. Optional when Repository is owner/repo.')
        public String owner;
        @InvocableVariable(label='Repository' description='Repo name or owner/repo. Defaults to SalesforceAgentForceDemo.')
        public String repo;
        @InvocableVariable(label='Owner And Repo' description='Full GitHub identifier such as kartikchauhan563/SalesforceAgentForceDemo')
        public String ownerRepo;
        @InvocableVariable(required=true label='New Branch' description='Branch that will receive the new component. Created when it does not exist.')
        public String newBranch;
        @InvocableVariable(label='Source Branch' description='Branch to create the new branch from. Defaults to master.')
        public String sourceBranch;
        @InvocableVariable(required=true label='File Path' description='Full repository path, for example force-app/main/default/flows/Fetch_All_Opportunities.flow-meta.xml')
        public String filePath;
        @InvocableVariable(required=true label='File Content' description='Complete file text, such as the full Flow metadata XML or Apex source.')
        public String fileContent;
        @InvocableVariable(label='Commit Message' description='Optional commit message.')
        public String commitMessage;
    }

    public class Response {
        @InvocableVariable(label='Success')
        public Boolean success;
        @InvocableVariable(label='Message')
        public String message;
        @InvocableVariable(label='Details JSON')
        public String detailsJson;
        @InvocableVariable(label='Download ZIP URL' description='Click this URL to download the branch as a zip file.')
        public String branchZipUrl;
        @InvocableVariable(label='Repository')
        public String repository;
        @InvocableVariable(label='Destination Branch')
        public String branch;
        @InvocableVariable(label='Copied Component Paths')
        public String componentPaths;
    }

    @InvocableMethod(
        label='GitHub Create Component In Branch'
        description='Creates a GitHub branch when needed, commits generated Salesforce metadata or code to it, and returns the branch download ZIP URL in the same call.'
    )
    public static List<Response> run(List<Request> requests) {
        Request req = first(requests);
        return wrap(
            GitHubCloudService.createComponentInBranch(
                req.owner,
                req.repo,
                req.ownerRepo,
                req.sourceBranch,
                req.newBranch,
                req.filePath,
                req.fileContent,
                req.commitMessage
            )
        );
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
