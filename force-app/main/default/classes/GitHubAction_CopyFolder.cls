public with sharing class GitHubAction_CopyFolder {
    public class Request {
        @InvocableVariable(label='Owner' description='GitHub owner or org. Optional when Repository is owner/repo.')
        public String owner;
        @InvocableVariable(label='Repository' description='Repo name or owner/repo. Defaults to SalesforceAgentForceDemo.')
        public String repo;
        @InvocableVariable(label='Owner And Repo' description='Full GitHub identifier such as kartikchauhan563/SalesforceAgentForceDemo')
        public String ownerRepo;
        @InvocableVariable(label='Source Branch' description='Branch to copy the folder from. Defaults to master.')
        public String sourceBranch;
        @InvocableVariable(label='Folder Path' description='Folder to copy, such as force-app/main/default/classes')
        public String folderPath;
        @InvocableVariable(label='Destination Branch' description='Branch that receives the folder. Created if missing.')
        public String destinationBranch;
        @InvocableVariable(label='Commit Message' description='Optional commit message for the copy')
        public String commitMessage;
    }

    public class Response {
        @InvocableVariable(label='Success')
        public Boolean success;
        @InvocableVariable(label='Message')
        public String message;
        @InvocableVariable(label='Details JSON')
        public String detailsJson;
        @InvocableVariable(label='Repository')
        public String repository;
        @InvocableVariable(label='Destination Branch')
        public String branch;
        @InvocableVariable(label='Copied Component Paths')
        public String componentPaths;
    }

    @InvocableMethod(
        label='GitHub Copy Folder'
        description='Copies only the files under one folder from a source branch onto a destination branch as a new commit, entirely in the cloud.'
    )
    public static List<Response> run(List<Request> requests) {
        Request req = first(requests);
        return wrap(
            GitHubCloudService.copyFolder(
                req.owner,
                req.repo,
                req.ownerRepo,
                req.sourceBranch,
                req.folderPath,
                req.destinationBranch,
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
        out.repository = result.repository;
        out.branch = result.branch;
        out.componentPaths = result.componentPaths;
        return new List<Response>{ out };
    }
}