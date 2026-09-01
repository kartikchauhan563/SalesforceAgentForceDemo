public without sharing class GitHubOAuthDeployQueueable implements Queueable, Database.AllowsCallouts {
    private final Id requestId;

    public GitHubOAuthDeployQueueable(Id requestId) {
        this.requestId = requestId;
    }

    public void execute(QueueableContext context) {
        List<Sf_Org_Deployment__c> rows = [
            SELECT Id, Name, Repository__c, Branch__c, Status__c, Error_Message__c, Completed_At__c
            FROM Sf_Org_Deployment__c
            WHERE Id = :requestId
            LIMIT 1
        ];
        if (rows.isEmpty() || rows[0].Status__c != 'Queued') {
            return;
        }
        Sf_Org_Deployment__c request = rows[0];
        GitHubWorkflowService.DispatchResult result = GitHubWorkflowService.dispatchOAuthDeploy(request);
        if (result.success != true) {
            request.Status__c = 'Failed';
            request.Error_Message__c = result.message;
            request.Completed_At__c = System.now();
            update request;
        }
    }
}
