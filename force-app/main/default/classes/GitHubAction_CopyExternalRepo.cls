public with sharing class GitHubAction_CopyExternalRepo {
    public class Request {
        @InvocableVariable(label='Source Repository URL' description='GitHub URL to copy from, such as https://github.com/owner/repo')
        public String sourceRepoUrl;
        @InvocableVariable(label='Source Branch' description='Optional branch in the source repository. Defaults to the URL tree branch or the source default branch.')
        public String sourceBranch;
        @InvocableVariable(label='New Branch' description='Destination branch in our repository that receives the complete copy')
        public String newBranch;
        @InvocableVariable(label='Owner' description='Destination GitHub owner. Optional when Repository is owner/repo.')
        public String owner;
        @InvocableVariable(label='Repository' description='Destination repo name or owner/repo. Defaults to SalesforceAgentForceDemo.')
        public String repo;
        @InvocableVariable(label='Owner And Repo' description='Destination identifier such as kartikchauhan563/SalesforceAgentForceDemo')
        public String ownerRepo;
        @InvocableVariable(label='Requirement' description='Optional natural-language changes to apply with AI on the copied branch.')
        public String requirement;
        @InvocableVariable(label='Target Environment' description='Optional Salesforce target for AI validation. Defaults to DEV.')
        public String targetEnvironment;
        @InvocableVariable(label='Component Path' description='Optional path hint for AI. Defaults to AUTO.')
        public String componentPath;
    }

    public class Response {
        @InvocableVariable(label='Success')
        public Boolean success;
        @InvocableVariable(label='Message')
        public String message;
        @InvocableVariable(label='Details JSON')
        public String detailsJson;
        @InvocableVariable(label='Download ZIP URL' description='URL to download the destination branch as a zip file after the copy finishes.')
        public String branchZipUrl;
        @InvocableVariable(label='Request Id' description='Salesforce AI refactor request Id when copy-and-apply was started.')
        public String requestId;
        @InvocableVariable(label='Reference Id' description='AIR reference such as AIR-000123 when copy-and-apply was started.')
        public String referenceId;
    }

    @InvocableMethod(
        label='GitHub Copy External Repository'
        description='Copies a GitHub repository URL into our repository as a new branch. When Requirement is provided, one pipeline then applies those AI changes on that same branch.'
    )
    public static List<Response> run(List<Request> requests) {
        Request req = first(requests);
        return wrap(
            GitHubCloudService.copyExternalRepository(
                req.sourceRepoUrl,
                req.sourceBranch,
                req.newBranch,
                req.owner,
                req.repo,
                req.ownerRepo,
                req.requirement,
                req.targetEnvironment,
                req.componentPath
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
        out.requestId = result.requestId;
        out.referenceId = result.referenceId;
        return new List<Response>{ out };
    }
}
