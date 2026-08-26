public with sharing class AIRefactorRequestService {
    public static final String REQUEST_FIELDS =
        'Id, Name, OwnerId, Repository__c, Source_Branch__c, Base_Commit_SHA__c, Component_Path__c, ' +
        'Requirement__c, Target_Environment__c, Status__c, GitHub_Workflow_Run_Id__c, AI_Branch__c, ' +
        'Output_Commit_SHA__c, Pull_Request_Number__c, Pull_Request_URL__c, PMD_Status__c, PMD_Result__c, ' +
        'Validation_Status__c, Validation_Id__c, Validation_Result__c, Test_Result__c, Deployment_Id__c, ' +
        'Deployment_Status__c, Deployment_Result__c, Prompt_Template__c, Prompt_Version__c, AI_Model__c, ' +
        'AI_Execution_Id__c, Changed_Files__c, Result_Summary__c, Error_Message__c, Requested_At__c, ' +
        'Started_At__c, Validation_Completed_At__c, PR_Created_At__c, Deployment_Started_At__c, ' +
        'Completed_At__c, Last_Callback_Hash__c, Retry_Count__c, Dispatch_In_Flight__c';

    public class SubmitCommand {
        public String repository;
        public String sourceBranch;
        public String componentPath;
        public String requirement;
        public String targetEnvironment;
    }

    public class SubmitResult {
        public Id requestId;
        public String referenceId;
        public String status;
        public String message;
        public String repository;
        public String sourceBranch;
        public String targetEnvironment;
    }

    public class StatusResult {
        public String referenceId;
        public String status;
        public String repository;
        public String sourceBranch;
        public String targetEnvironment;
        public String pullRequestUrl;
        public String validationStatus;
        public String deploymentStatus;
        public String deploymentId;
        public String resultSummary;
        public String errorMessage;
        public String testResult;
        public String pmdStatus;
        public Integer pullRequestNumber;
        public String aiBranch;
        public String branchZipUrl;
    }

    public static SubmitResult submit(SubmitCommand command) {
        return submit(command, true);
    }

    public static SubmitResult submit(SubmitCommand command, Boolean dispatchRefactor) {
        AIRefactorSecurityService.assertCreateable();
        AIRefactorConfigService.Config cfg = AIRefactorConfigService.loadConfig();
        AIRefactorConfigService.Repo repo = AIRefactorValidationService.requireRepository(command.repository);
        String branch = AIRefactorValidationService.requireBranch(command.sourceBranch, repo);
        String target = AIRefactorValidationService.requireTarget(command.targetEnvironment, repo, cfg);
        String path = AIRefactorValidationService.requireComponentPath(command.componentPath, cfg);
        String requirement = AIRefactorValidationService.requireRequirement(command.requirement, cfg);

        AI_Refactor_Request__c record = new AI_Refactor_Request__c();
        record.Repository__c = repo.ownerRepo;
        record.Source_Branch__c = branch;
        record.Component_Path__c = path;
        record.Requirement__c = requirement;
        record.Target_Environment__c = target;
        record.Status__c = AIRefactorConstants.STATUS_SUBMITTED;
        record.Requested_At__c = System.now();
        record.Prompt_Template__c = 'auto';
        record.Prompt_Version__c = AIRefactorConstants.PROMPT_VERSION;
        record.PMD_Status__c = AIRefactorConstants.RESULT_NOT_STARTED;
        record.Validation_Status__c = AIRefactorConstants.RESULT_NOT_STARTED;
        record.Deployment_Status__c = AIRefactorConstants.RESULT_NOT_STARTED;
        record.Dispatch_In_Flight__c = true;
        record.Retry_Count__c = 0;
        insert record;

        AI_Refactor_Request__c stored = [
            SELECT Id, Name, Status__c, Repository__c, Source_Branch__c, Target_Environment__c
            FROM AI_Refactor_Request__c
            WHERE Id = :record.Id
            LIMIT 1
        ];
        if (dispatchRefactor != false) {
            System.enqueueJob(new GitHubWorkflowQueueable(stored.Id, false));
        }

        SubmitResult result = new SubmitResult();
        result.requestId = stored.Id;
        result.referenceId = stored.Name;
        result.status = stored.Status__c;
        result.repository = stored.Repository__c;
        result.sourceBranch = stored.Source_Branch__c;
        result.targetEnvironment = stored.Target_Environment__c;
        result.message =
            'Your AI refactoring request has been submitted.\n\n' +
            'Reference: ' + stored.Name + '\n' +
            'Repository: ' + repo.displayName + '\n' +
            'Source Branch: ' + branch + '\n' +
            'Target Environment: ' + target + '\n' +
            'Status: ' + stored.Status__c;
        return result;
    }

    public static StatusResult getByReference(String referenceId) {
        AIRefactorSecurityService.assertReadable();
        AI_Refactor_Request__c record = findByReference(referenceId, false);
        return toStatus(record);
    }

    public static List<StatusResult> listMine() {
        AIRefactorSecurityService.assertReadable();
        List<StatusResult> results = new List<StatusResult>();
        for (AI_Refactor_Request__c record : [
            SELECT
                Id, Name, Status__c, Repository__c, Source_Branch__c, Target_Environment__c,
                Pull_Request_URL__c, Pull_Request_Number__c, Validation_Status__c,
                Deployment_Status__c, Deployment_Id__c, Result_Summary__c, Error_Message__c,
                Test_Result__c, PMD_Status__c, AI_Branch__c
            FROM AI_Refactor_Request__c
            ORDER BY CreatedDate DESC
            LIMIT 20
        ]) {
            results.add(toStatus(record));
        }
        return results;
    }

    public static StatusResult cancel(String referenceId) {
        AIRefactorSecurityService.assertUpdateable();
        AI_Refactor_Request__c record = findByReference(referenceId, true);
        if (!AIRefactorValidationService.canCancel(record)) {
            throw new AIRefactorException(
                'Request ' + record.Name + ' cannot be cancelled from status ' + record.Status__c + '.'
            );
        }
        record.Status__c = AIRefactorConstants.STATUS_CANCELLED;
        record.Completed_At__c = System.now();
        record.Dispatch_In_Flight__c = false;
        record.Result_Summary__c = 'Cancelled by ' + UserInfo.getName() + '.';
        update record;
        return toStatus(record);
    }

    public static StatusResult retry(String referenceId) {
        AIRefactorSecurityService.assertUpdateable();
        AI_Refactor_Request__c record = findByReference(referenceId, true);
        if (!AIRefactorValidationService.canRetry(record)) {
            throw new AIRefactorException(
                'Retry is only allowed after GitHub trigger, callback, or controlled deployment failure. ' +
                'Static analysis or validation failures require a new request.'
            );
        }
        Decimal retries = record.Retry_Count__c == null ? 0 : record.Retry_Count__c;
        record.Retry_Count__c = retries + 1;
        record.Error_Message__c = null;
        record.Dispatch_In_Flight__c = true;
        if (record.Status__c == AIRefactorConstants.STATUS_DEPLOY_FAILED) {
            record.Status__c = AIRefactorConstants.STATUS_APPROVED;
            update record;
            System.enqueueJob(new GitHubWorkflowQueueable(record.Id, true));
        } else {
            record.Status__c = AIRefactorConstants.STATUS_SUBMITTED;
            update record;
            System.enqueueJob(new GitHubWorkflowQueueable(record.Id, false));
        }
        return toStatus(record);
    }

    public static AI_Refactor_Request__c findByReference(String referenceId, Boolean forUpdate) {
        String cleaned = AIRefactorSecurityService.sanitizeText(referenceId);
        if (String.isBlank(cleaned)) {
            throw new AIRefactorException('A request reference such as AIR-000123 is required.');
        }
        String soql = 'SELECT ' + REQUEST_FIELDS + ' FROM AI_Refactor_Request__c WHERE Name = :cleaned LIMIT 1';
        if (forUpdate) {
            soql += ' FOR UPDATE';
        }
        List<AI_Refactor_Request__c> rows = Database.query(soql);
        if (rows.isEmpty()) {
            throw new AIRefactorException('No AI refactor request found for ' + cleaned + '.');
        }
        return rows[0];
    }

    public static StatusResult toStatus(AI_Refactor_Request__c record) {
        StatusResult result = new StatusResult();
        result.referenceId = record.Name;
        result.status = record.Status__c;
        result.repository = record.Repository__c;
        result.sourceBranch = record.Source_Branch__c;
        result.targetEnvironment = record.Target_Environment__c;
        result.pullRequestUrl = record.Pull_Request_URL__c;
        result.pullRequestNumber = record.Pull_Request_Number__c == null
            ? null
            : Integer.valueOf(record.Pull_Request_Number__c);
        result.validationStatus = record.Validation_Status__c;
        result.deploymentStatus = record.Deployment_Status__c;
        result.deploymentId = record.Deployment_Id__c;
        result.resultSummary = record.Result_Summary__c;
        result.errorMessage = sanitizeError(record.Error_Message__c);
        result.testResult = record.Test_Result__c;
        result.pmdStatus = record.PMD_Status__c;
        result.aiBranch = record.AI_Branch__c;
        result.branchZipUrl = GitHubCloudService.branchZipDownloadUrl(record.Repository__c, record.AI_Branch__c);
        return result;
    }

    public static String sanitizeError(String raw) {
        if (String.isBlank(raw)) {
            return raw;
        }
        String cleaned = raw;
        cleaned = cleaned.replaceAll('(?i)bearer [a-z0-9._\\-]+', '[redacted]');
        cleaned = cleaned.replaceAll('(?i)-----BEGIN[\\s\\S]+?-----END [A-Z ]+-----', '[redacted-key]');
        return cleaned.length() > 4000 ? cleaned.substring(0, 4000) : cleaned;
    }
}
