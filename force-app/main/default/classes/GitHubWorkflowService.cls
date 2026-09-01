public with sharing class GitHubWorkflowService {
    public class DispatchResult {
        public Boolean success;
        public String message;
        public Integer statusCode;
    }

    public static DispatchResult dispatchRefactor(AI_Refactor_Request__c record) {
        return dispatch(record, false, false);
    }

    public static DispatchResult dispatchRefactor(AI_Refactor_Request__c record, Boolean commitToSourceBranch) {
        return dispatch(record, false, commitToSourceBranch);
    }

    public static DispatchResult dispatchDeploy(AI_Refactor_Request__c record) {
        return dispatch(record, true, false);
    }

    public static DispatchResult dispatchOAuthDeploy(Sf_Org_Deployment__c record) {
        List<String> parts = record.Repository__c == null
            ? new List<String>()
            : record.Repository__c.split('/');
        if (parts.size() != 2) {
            return fail('Repository must be stored as organization/name.');
        }
        GitHubCloudConfig.RepoTarget cfg = GitHubCloudConfig.defaults();
        return postDispatch(
            cfg.namedCredential,
            parts[0],
            parts[1],
            'salesforce-oauth-deploy.yml',
            cfg.baseBranch,
            new Map<String, Object>{
                'requestId' => String.valueOf(record.Id),
                'referenceId' => record.Name,
                'repository' => record.Repository__c,
                'branch' => record.Branch__c
            }
        );
    }

    public static DispatchResult dispatchCopyAndApply(
        AI_Refactor_Request__c record,
        String sourceRepoUrl,
        String sourceGitBranch
    ) {
        AIRefactorConfigService.Config cfg = AIRefactorConfigService.loadConfig();
        List<String> parts = record.Repository__c.split('/');
        if (parts.size() != 2) {
            return fail('Repository must be stored as organization/name.');
        }
        Map<String, Object> inputs = new Map<String, Object>{
            'sourceRepoUrl' => nvl(sourceRepoUrl),
            'sourceBranch' => nvl(sourceGitBranch),
            'destBranch' => nvl(record.Source_Branch__c),
            'requestId' => String.valueOf(record.Id),
            'referenceId' => nvl(record.Name),
            'repository' => nvl(record.Repository__c),
            'componentPath' => nvl(record.Component_Path__c),
            'requirement' => nvl(record.Requirement__c),
            'targetEnvironment' => nvl(record.Target_Environment__c)
        };
        return postDispatch(
            cfg.namedCredential,
            parts[0],
            parts[1],
            AIRefactorConstants.WORKFLOW_COPY_AND_APPLY,
            cfg.defaultBaseBranch,
            inputs
        );
    }

    private static DispatchResult dispatch(
        AI_Refactor_Request__c record,
        Boolean deploy,
        Boolean commitToSourceBranch
    ) {
        AIRefactorConfigService.Config cfg = AIRefactorConfigService.loadConfig();
        String workflow = deploy ? cfg.deploymentWorkflowFile : cfg.githubWorkflowFile;
        List<String> parts = record.Repository__c.split('/');
        if (parts.size() != 2) {
            return fail('Repository must be stored as organization/name.');
        }
        Map<String, Object> inputs = new Map<String, Object>{
            'requestId' => String.valueOf(record.Id),
            'referenceId' => record.Name,
            'repository' => record.Repository__c,
            'sourceBranch' => record.Source_Branch__c,
            'componentPath' => nvl(record.Component_Path__c),
            'requirement' => nvl(record.Requirement__c),
            'targetEnvironment' => record.Target_Environment__c
        };
        if (deploy) {
            inputs.put('commitSha', nvl(record.Output_Commit_SHA__c));
            inputs.put('validationId', nvl(record.Validation_Id__c));
        } else {
            inputs.put('skipSalesforceValidation', true);
            if (commitToSourceBranch == true) {
                inputs.put('commitToSourceBranch', true);
            }
        }
        return postDispatch(
            cfg.namedCredential,
            parts[0],
            parts[1],
            workflow,
            cfg.defaultBaseBranch,
            inputs
        );
    }

    private static DispatchResult postDispatch(
        String namedCredential,
        String owner,
        String repo,
        String workflow,
        String workflowRef,
        Map<String, Object> inputs
    ) {
        Map<String, Object> body = new Map<String, Object>{
            'ref' => workflowRef,
            'inputs' => inputs
        };
        String path = '/repos/' + owner + '/' + repo + '/actions/workflows/' + workflow + '/dispatches';
        try {
            GitHubCloudClient.Response response = GitHubCloudClient.post(
                namedCredential,
                path,
                JSON.serialize(body)
            );
            DispatchResult result = new DispatchResult();
            result.success = true;
            result.statusCode = response.statusCode;
            result.message = 'GitHub workflow ' + workflow + ' dispatched.';
            return result;
        } catch (GitHubCloudClient.CalloutException ex) {
            return fail(AIRefactorRequestService.sanitizeError(ex.getMessage()));
        }
    }

    private static DispatchResult fail(String message) {
        DispatchResult result = new DispatchResult();
        result.success = false;
        result.message = message;
        return result;
    }

    private static String nvl(String value) {
        return value == null ? '' : value;
    }
}
