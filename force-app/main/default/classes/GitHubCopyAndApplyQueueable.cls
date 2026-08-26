public with sharing class GitHubCopyAndApplyQueueable implements Queueable, Database.AllowsCallouts {
    private final Id requestId;
    private final String sourceRepoUrl;
    private final String sourceGitBranch;
    private final Boolean sameRepo;

    public GitHubCopyAndApplyQueueable(
        Id requestId,
        String sourceRepoUrl,
        String sourceGitBranch,
        Boolean sameRepo
    ) {
        this.requestId = requestId;
        this.sourceRepoUrl = sourceRepoUrl;
        this.sourceGitBranch = sourceGitBranch;
        this.sameRepo = sameRepo == true;
    }

    public void execute(QueueableContext context) {
        List<AI_Refactor_Request__c> rows = Database.query(
            'SELECT ' + AIRefactorRequestService.REQUEST_FIELDS +
            ' FROM AI_Refactor_Request__c WHERE Id = :requestId LIMIT 1'
        );
        if (rows.isEmpty()) {
            return;
        }
        AI_Refactor_Request__c record = rows[0];
        if (record.Status__c == AIRefactorConstants.STATUS_CANCELLED) {
            record.Dispatch_In_Flight__c = false;
            update record;
            return;
        }

        GitHubWorkflowService.DispatchResult result;
        if (sameRepo) {
            GitHubCloudService.Result copied = GitHubCloudService.copyBranchAssets(
                null,
                null,
                record.Repository__c,
                sourceGitBranch,
                record.Source_Branch__c
            );
            if (copied == null || copied.success != true) {
                record.Status__c = AIRefactorConstants.STATUS_TRIGGER_FAILED;
                record.Dispatch_In_Flight__c = false;
                record.Error_Message__c = copied == null ? 'Same-repository copy failed.' : copied.message;
                update record;
                return;
            }
            result = GitHubWorkflowService.dispatchRefactor(record, true);
        } else {
            result = GitHubWorkflowService.dispatchCopyAndApply(record, sourceRepoUrl, sourceGitBranch);
        }

        if (result.success) {
            record.Status__c = AIRefactorConstants.STATUS_QUEUED;
            record.Dispatch_In_Flight__c = false;
            record.Error_Message__c = null;
        } else {
            record.Status__c = AIRefactorConstants.STATUS_TRIGGER_FAILED;
            record.Dispatch_In_Flight__c = false;
            record.Error_Message__c = result.message;
        }
        update record;
    }
}
