public with sharing class GitHubAction_CopyAndApplyRepo {
    public class Request {
        @InvocableVariable(label='Source Repository URL' description='GitHub URL to copy from, such as https://github.com/owner/repo')
        public String sourceRepoUrl;
        @InvocableVariable(label='Source Branch' description='Optional branch in the source repository.')
        public String sourceBranch;
        @InvocableVariable(label='New Branch' description='Destination branch that receives the copy and AI changes')
        public String newBranch;
        @InvocableVariable(label='Requirement' description='Natural-language changes to apply with AI on the copied branch')
        public String requirement;
        @InvocableVariable(label='Target Environment' description='Salesforce validation target. Defaults to DEV.')
        public String targetEnvironment;
        @InvocableVariable(label='Component Path' description='Optional path hint. Defaults to AUTO.')
        public String componentPath;
        @InvocableVariable(label='Owner' description='Destination GitHub owner.')
        public String owner;
        @InvocableVariable(label='Repository' description='Destination repository name or owner/repo.')
        public String repo;
        @InvocableVariable(label='Owner And Repo' description='Destination identifier such as owner/repo.')
        public String ownerRepo;
    }

    public class Response {
        @InvocableVariable(label='Success')
        public Boolean success;
        @InvocableVariable(label='Message')
        public String message;
        @InvocableVariable(label='Details JSON')
        public String detailsJson;
        @InvocableVariable(label='Download ZIP URL')
        public String branchZipUrl;
        @InvocableVariable(label='Request Id')
        public String requestId;
        @InvocableVariable(label='Reference Id')
        public String referenceId;
    }

    @InvocableMethod(
        label='GitHub Copy And Apply Repository'
        description='Runs one pipeline that copies a GitHub repository to a new branch and applies required AI changes on that same branch.'
    )
    public static List<Response> run(List<Request> requests) {
        Request req = (requests == null || requests.isEmpty() || requests[0] == null)
            ? new Request()
            : requests[0];
        GitHubCloudService.Result result = GitHubCloudService.copyExternalRepository(
            req.sourceRepoUrl,
            req.sourceBranch,
            req.newBranch,
            req.owner,
            req.repo,
            req.ownerRepo,
            req.requirement,
            req.targetEnvironment,
            req.componentPath
        );
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
