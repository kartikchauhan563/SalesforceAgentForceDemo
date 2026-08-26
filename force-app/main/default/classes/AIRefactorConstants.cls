public with sharing class AIRefactorConstants {
    public static final String OBJECT_API = 'AI_Refactor_Request__c';
    public static final String NAMED_CREDENTIAL_DEFAULT = 'GitHub_API';
    public static final String WORKFLOW_REFACTOR = 'ai-refactor.yml';
    public static final String WORKFLOW_COPY_AND_APPLY = 'copy-and-apply.yml';
    public static final String WORKFLOW_DEPLOY = 'salesforce-deploy.yml';
    public static final String PROMPT_VERSION = '2.0.0';
    public static final String NOTIFICATION_DEVELOPER_NAME = 'AI_Refactor_Alert';

    public static final String STATUS_DRAFT = 'Draft';
    public static final String STATUS_SUBMITTED = 'Submitted';
    public static final String STATUS_QUEUED = 'GitHub Workflow Queued';
    public static final String STATUS_PREPARING = 'Preparing Workspace';
    public static final String STATUS_AI = 'AI Refactoring';
    public static final String STATUS_STATIC = 'Static Analysis';
    public static final String STATUS_SF_VALIDATION = 'Salesforce Validation';
    public static final String STATUS_PR_CREATED = 'PR Created';
    public static final String STATUS_AWAITING = 'Awaiting Approval';
    public static final String STATUS_APPROVED = 'Approved';
    public static final String STATUS_DEPLOYING = 'Deploying';
    public static final String STATUS_RUNNING_TESTS = 'Running Tests';
    public static final String STATUS_COMPLETED = 'Completed';
    public static final String STATUS_TRIGGER_FAILED = 'GitHub Trigger Failed';
    public static final String STATUS_REFACTOR_FAILED = 'Refactor Failed';
    public static final String STATUS_WORKSPACE_FAILED = 'Workspace Validation Failed';
    public static final String STATUS_STATIC_FAILED = 'Static Analysis Failed';
    public static final String STATUS_SF_VALIDATION_FAILED = 'Salesforce Validation Failed';
    public static final String STATUS_PR_FAILED = 'PR Creation Failed';
    public static final String STATUS_DEPLOY_FAILED = 'Deployment Failed';
    public static final String STATUS_CALLBACK_FAILED = 'Callback Failed';
    public static final String STATUS_CANCELLED = 'Cancelled';

    public static final String RESULT_NOT_STARTED = 'Not Started';
    public static final String RESULT_IN_PROGRESS = 'In Progress';
    public static final String RESULT_SUCCEEDED = 'Succeeded';
    public static final String RESULT_FAILED = 'Failed';
    public static final String RESULT_SKIPPED = 'Skipped';

    public static final Set<String> TARGETS = new Set<String>{ 'DEV', 'QA', 'UAT', 'PROD' };
    public static final Set<String> TERMINAL = new Set<String>{
        STATUS_COMPLETED,
        STATUS_CANCELLED,
        STATUS_REFACTOR_FAILED,
        STATUS_WORKSPACE_FAILED,
        STATUS_STATIC_FAILED,
        STATUS_SF_VALIDATION_FAILED,
        STATUS_PR_FAILED,
        STATUS_DEPLOY_FAILED,
        STATUS_CALLBACK_FAILED
    };

    public static Map<String, Set<String>> allowedTransitions() {
        return new Map<String, Set<String>>{
            STATUS_DRAFT => new Set<String>{ STATUS_SUBMITTED, STATUS_CANCELLED },
            STATUS_SUBMITTED => new Set<String>{ STATUS_QUEUED, STATUS_TRIGGER_FAILED, STATUS_CANCELLED },
            STATUS_QUEUED => new Set<String>{
                STATUS_PREPARING,
                STATUS_TRIGGER_FAILED,
                STATUS_CANCELLED
            },
            STATUS_PREPARING => new Set<String>{
                STATUS_AI,
                STATUS_WORKSPACE_FAILED,
                STATUS_REFACTOR_FAILED,
                STATUS_CANCELLED
            },
            STATUS_AI => new Set<String>{
                STATUS_STATIC,
                STATUS_REFACTOR_FAILED,
                STATUS_WORKSPACE_FAILED,
                STATUS_CANCELLED
            },
            STATUS_STATIC => new Set<String>{
                STATUS_SF_VALIDATION,
                STATUS_STATIC_FAILED,
                STATUS_CANCELLED
            },
            STATUS_SF_VALIDATION => new Set<String>{
                STATUS_PR_CREATED,
                STATUS_SF_VALIDATION_FAILED,
                STATUS_PR_FAILED,
                STATUS_CANCELLED
            },
            STATUS_PR_CREATED => new Set<String>{ STATUS_AWAITING, STATUS_PR_FAILED },
            STATUS_AWAITING => new Set<String>{ STATUS_APPROVED, STATUS_CANCELLED },
            STATUS_APPROVED => new Set<String>{ STATUS_DEPLOYING, STATUS_CANCELLED, STATUS_TRIGGER_FAILED },
            STATUS_DEPLOYING => new Set<String>{ STATUS_RUNNING_TESTS, STATUS_DEPLOY_FAILED },
            STATUS_RUNNING_TESTS => new Set<String>{ STATUS_COMPLETED, STATUS_DEPLOY_FAILED },
            STATUS_TRIGGER_FAILED => new Set<String>{ STATUS_SUBMITTED, STATUS_CANCELLED },
            STATUS_REFACTOR_FAILED => new Set<String>{ STATUS_CANCELLED },
            STATUS_WORKSPACE_FAILED => new Set<String>{ STATUS_CANCELLED },
            STATUS_STATIC_FAILED => new Set<String>{ STATUS_CANCELLED },
            STATUS_SF_VALIDATION_FAILED => new Set<String>{ STATUS_CANCELLED },
            STATUS_PR_FAILED => new Set<String>{ STATUS_CANCELLED },
            STATUS_DEPLOY_FAILED => new Set<String>{ STATUS_APPROVED, STATUS_CANCELLED },
            STATUS_CALLBACK_FAILED => new Set<String>{ STATUS_SUBMITTED, STATUS_CANCELLED },
            STATUS_COMPLETED => new Set<String>(),
            STATUS_CANCELLED => new Set<String>()
        };
    }

    public static Set<String> notifyStatuses() {
        return new Set<String>{
            STATUS_PR_CREATED,
            STATUS_AWAITING,
            STATUS_SF_VALIDATION_FAILED,
            STATUS_STATIC_FAILED,
            STATUS_COMPLETED,
            STATUS_DEPLOY_FAILED
        };
    }
}
