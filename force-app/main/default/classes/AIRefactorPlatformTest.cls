@isTest
private class AIRefactorPlatformTest {
    private static void seedConfig() {
        AIRefactorConfigService.Config cfg = AIRefactorConfigService.defaults();
        cfg.githubOrganization = 'acme';
        cfg.defaultRepository = 'salesforce-core';
        cfg.namedCredential = 'GitHub_API';
        cfg.productionDeploymentEnabled = false;
        AIRefactorConfigService.testConfig = cfg;

        AIRefactorConfigService.Repo repo = new AIRefactorConfigService.Repo();
        repo.displayName = 'salesforce-core';
        repo.organization = 'acme';
        repo.repositoryName = 'salesforce-core';
        repo.defaultBranch = 'develop';
        repo.enabled = true;
        repo.allowedTargets = new Set<String>{ 'DEV', 'QA', 'UAT' };
        AIRefactorConfigService.testRepos = new List<AIRefactorConfigService.Repo>{ repo };
    }

    private static AIRefactorAgentAction.Request sampleRequest() {
        AIRefactorAgentAction.Request req = new AIRefactorAgentAction.Request();
        req.repository = 'salesforce-core';
        req.sourceBranch = 'develop';
        req.componentPath = 'force-app/main/default/classes/AccountTriggerHandler.cls';
        req.requirement = 'Remove SOQL from loops, improve bulkification, and fix PMD issues.';
        req.targetEnvironment = 'QA';
        return req;
    }

    @isTest
    static void submitSuccessDispatchesGitHub() {
        seedConfig();
        Test.setMock(HttpCalloutMock.class, new GitHubCloudMock().add(204, ''));
        Test.startTest();
        List<AIRefactorAgentAction.Response> res = AIRefactorAgentAction.submit(
            new List<AIRefactorAgentAction.Request>{ sampleRequest() }
        );
        Test.stopTest();
        System.assertNotEquals(null, res[0].requestId);
        System.assert(res[0].referenceId.startsWith('AIR-'));
        System.assertEquals(AIRefactorConstants.STATUS_SUBMITTED, res[0].status);
        AI_Refactor_Request__c stored = [
            SELECT Status__c, Repository__c, Target_Environment__c, Error_Message__c
            FROM AI_Refactor_Request__c
            WHERE Id = :res[0].requestId
        ];
        System.assertEquals('acme/salesforce-core', stored.Repository__c);
        System.assertEquals('QA', stored.Target_Environment__c);
        System.assertEquals(AIRefactorConstants.STATUS_QUEUED, stored.Status__c);
        System.assertEquals(null, stored.Error_Message__c);
    }

    @isTest
    static void submitRequirementOnlyUsesDefaultsAndAutomaticDiscovery() {
        seedConfig();
        Test.setMock(HttpCalloutMock.class, new GitHubCloudMock().add(204, ''));
        AIRefactorAgentAction.Request req = new AIRefactorAgentAction.Request();
        req.requirement = 'Prevent duplicate loan decisions and add regression tests.';
        Test.startTest();
        AIRefactorAgentAction.Response response = AIRefactorAgentAction.submit(
            new List<AIRefactorAgentAction.Request>{ req }
        )[0];
        Test.stopTest();

        System.assertNotEquals(null, response.requestId);
        AI_Refactor_Request__c stored = [
            SELECT Repository__c, Source_Branch__c, Component_Path__c, Target_Environment__c, Status__c
            FROM AI_Refactor_Request__c
            WHERE Id = :response.requestId
        ];
        System.assertEquals('acme/salesforce-core', stored.Repository__c);
        System.assertEquals('develop', stored.Source_Branch__c);
        System.assertEquals('AUTO', stored.Component_Path__c);
        System.assertEquals('DEV', stored.Target_Environment__c);
        System.assertEquals(AIRefactorConstants.STATUS_QUEUED, stored.Status__c);
    }

    @isTest
    static void submitRejectsInvalidRepository() {
        seedConfig();
        AIRefactorAgentAction.Request req = sampleRequest();
        req.repository = 'https://github.com/evil/repo';
        Test.startTest();
        List<AIRefactorAgentAction.Response> res = AIRefactorAgentAction.submit(
            new List<AIRefactorAgentAction.Request>{ req }
        );
        Test.stopTest();
        System.assertEquals('Rejected', res[0].status);
        System.assert(res[0].message.contains('not a GitHub URL') || res[0].message.contains('not enabled'));
        System.assertEquals(0, [SELECT COUNT() FROM AI_Refactor_Request__c]);
    }

    @isTest
    static void submitRejectsUnknownRepository() {
        seedConfig();
        AIRefactorAgentAction.Request req = sampleRequest();
        req.repository = 'unknown-repo';
        List<AIRefactorAgentAction.Response> res = AIRefactorAgentAction.submit(
            new List<AIRefactorAgentAction.Request>{ req }
        );
        System.assertEquals('Rejected', res[0].status);
        System.assert(res[0].message.contains('not enabled'));
    }

    @isTest
    static void submitRejectsInvalidTarget() {
        seedConfig();
        AIRefactorAgentAction.Request req = sampleRequest();
        req.targetEnvironment = 'STAGE';
        List<AIRefactorAgentAction.Response> res = AIRefactorAgentAction.submit(
            new List<AIRefactorAgentAction.Request>{ req }
        );
        System.assertEquals('Rejected', res[0].status);
        System.assert(res[0].message.contains('DEV, QA, UAT, or PROD'));
    }

    @isTest
    static void submitRejectsProdWhenDisabled() {
        seedConfig();
        AIRefactorAgentAction.Request req = sampleRequest();
        req.targetEnvironment = 'PROD';
        List<AIRefactorAgentAction.Response> res = AIRefactorAgentAction.submit(
            new List<AIRefactorAgentAction.Request>{ req }
        );
        System.assertEquals('Rejected', res[0].status);
        System.assert(res[0].message.contains('Production') || res[0].message.contains('not allowed'));
    }

    @isTest
    static void submitRejectsBlockedPath() {
        seedConfig();
        AIRefactorAgentAction.Request req = sampleRequest();
        req.componentPath = '.github/workflows/ai-refactor.yml';
        List<AIRefactorAgentAction.Response> res = AIRefactorAgentAction.submit(
            new List<AIRefactorAgentAction.Request>{ req }
        );
        System.assertEquals('Rejected', res[0].status);
        System.assert(res[0].message.contains('blocked') || res[0].message.contains('allowed'));
    }

    @isTest
    static void submitRejectsCredentialRequirement() {
        seedConfig();
        AIRefactorAgentAction.Request req = sampleRequest();
        req.requirement = 'Use this password: hunter2 to deploy';
        List<AIRefactorAgentAction.Response> res = AIRefactorAgentAction.submit(
            new List<AIRefactorAgentAction.Request>{ req }
        );
        System.assertEquals('Rejected', res[0].status);
        System.assert(res[0].message.contains('credentials'));
    }

    @isTest
    static void githubFailureIsRecorded() {
        seedConfig();
        Test.setMock(
            HttpCalloutMock.class,
            new GitHubCloudMock().add(401, '{"message":"Bad credentials"}')
        );
        Test.startTest();
        List<AIRefactorAgentAction.Response> res = AIRefactorAgentAction.submit(
            new List<AIRefactorAgentAction.Request>{ sampleRequest() }
        );
        Test.stopTest();
        AI_Refactor_Request__c stored = [
            SELECT Status__c, Error_Message__c
            FROM AI_Refactor_Request__c
            WHERE Id = :res[0].requestId
        ];
        System.assertEquals(AIRefactorConstants.STATUS_TRIGGER_FAILED, stored.Status__c);
        System.assertNotEquals(null, stored.Error_Message__c);
    }

    @isTest
    static void callbackWalkAndDuplicate() {
        seedConfig();
        Test.setMock(HttpCalloutMock.class, new GitHubCloudMock().add(204, ''));
        Test.startTest();
        Id requestId = AIRefactorAgentAction.submit(
            new List<AIRefactorAgentAction.Request>{ sampleRequest() }
        )[0].requestId;
        Test.stopTest();
        AI_Refactor_Request__c stored = [SELECT Name FROM AI_Refactor_Request__c WHERE Id = :requestId];

        AIRefactorCallbackService.Payload preparing = basePayload(requestId, stored.Name, 'run-1');
        preparing.status = AIRefactorConstants.STATUS_PREPARING;
        preparing.baseCommit = 'abc123';
        AIRefactorCallbackService.Result first = AIRefactorCallbackService.apply(preparing);
        System.assertEquals(true, first.success);
        System.assertEquals(false, first.duplicate);

        AIRefactorCallbackService.Result dup = AIRefactorCallbackService.apply(preparing);
        System.assertEquals(true, dup.duplicate);

        AIRefactorCallbackService.Payload wrongRun = basePayload(requestId, stored.Name, 'run-2');
        wrongRun.status = AIRefactorConstants.STATUS_AI;
        Boolean rejected = false;
        try {
            AIRefactorCallbackService.apply(wrongRun);
        } catch (AIRefactorException ex) {
            rejected = true;
            System.assert(ex.getMessage().contains('Workflow run'));
        }
        System.assertEquals(true, rejected);
    }

    @isTest
    static void deploymentWorkflowCanTakeOverRunCorrelation() {
        seedConfig();
        Test.setMock(HttpCalloutMock.class, new GitHubCloudMock().add(204, ''));
        Test.startTest();
        AIRefactorAgentAction.Response submitted = AIRefactorAgentAction.submit(
            new List<AIRefactorAgentAction.Request>{ sampleRequest() }
        )[0];
        Test.stopTest();
        AI_Refactor_Request__c stored = [
            SELECT Name FROM AI_Refactor_Request__c WHERE Id = :submitted.requestId
        ];
        walkTo(submitted.requestId, stored.Name, 'refactor-run', new List<String>{
            AIRefactorConstants.STATUS_PREPARING,
            AIRefactorConstants.STATUS_AI,
            AIRefactorConstants.STATUS_STATIC,
            AIRefactorConstants.STATUS_SF_VALIDATION,
            AIRefactorConstants.STATUS_PR_CREATED,
            AIRefactorConstants.STATUS_AWAITING
        });
        AI_Refactor_Request__c requestRecord = [
            SELECT Status__c, Output_Commit_SHA__c
            FROM AI_Refactor_Request__c
            WHERE Id = :submitted.requestId
        ];
        requestRecord.Output_Commit_SHA__c = 'abc123deploy';
        update requestRecord;

        AIRefactorCallbackService.Payload approved = basePayload(
            submitted.requestId,
            stored.Name,
            'refactor-run'
        );
        approved.status = AIRefactorConstants.STATUS_APPROVED;
        AIRefactorCallbackService.apply(approved);

        AIRefactorCallbackService.Payload deploying = basePayload(
            submitted.requestId,
            stored.Name,
            'deploy-run'
        );
        deploying.status = AIRefactorConstants.STATUS_DEPLOYING;
        deploying.outputCommit = 'abc123deploy';
        AIRefactorCallbackService.Result result = AIRefactorCallbackService.apply(deploying);
        System.assertEquals(true, result.success);
        AI_Refactor_Request__c correlated = [
            SELECT Status__c, GitHub_Workflow_Run_Id__c
            FROM AI_Refactor_Request__c
            WHERE Id = :submitted.requestId
        ];
        System.assertEquals(AIRefactorConstants.STATUS_DEPLOYING, correlated.Status__c);
        System.assertEquals('deploy-run', correlated.GitHub_Workflow_Run_Id__c);
    }

    @isTest
    static void restCallbackDeploymentOutcomes() {
        seedConfig();
        Test.setMock(HttpCalloutMock.class, new GitHubCloudMock().add(204, ''));
        Test.startTest();
        AIRefactorAgentAction.Response submitted = AIRefactorAgentAction.submit(
            new List<AIRefactorAgentAction.Request>{ sampleRequest() }
        )[0];
        Test.stopTest();
        AI_Refactor_Request__c stored = [SELECT Name FROM AI_Refactor_Request__c WHERE Id = :submitted.requestId];

        walkTo(submitted.requestId, stored.Name, 'run-9', new List<String>{
            AIRefactorConstants.STATUS_PREPARING,
            AIRefactorConstants.STATUS_AI,
            AIRefactorConstants.STATUS_STATIC,
            AIRefactorConstants.STATUS_SF_VALIDATION,
            AIRefactorConstants.STATUS_PR_CREATED,
            AIRefactorConstants.STATUS_AWAITING,
            AIRefactorConstants.STATUS_APPROVED,
            AIRefactorConstants.STATUS_DEPLOYING,
            AIRefactorConstants.STATUS_RUNNING_TESTS
        });

        RestRequest req = new RestRequest();
        RestResponse res = new RestResponse();
        req.httpMethod = 'POST';
        req.requestURI = '/services/apexrest/ai-refactor/v1/status';
        req.requestBody = Blob.valueOf(JSON.serialize(new Map<String, Object>{
            'requestId' => submitted.requestId,
            'referenceId' => stored.Name,
            'workflowRunId' => 'run-9',
            'status' => AIRefactorConstants.STATUS_COMPLETED,
            'deploymentStatus' => AIRefactorConstants.RESULT_SUCCEEDED,
            'deploymentId' => '0Af000000000001',
            'testSummary' => '24 passed, 0 failed'
        }));
        RestContext.request = req;
        RestContext.response = res;
        AIRefactorCallbackRest.doPost();
        System.assertEquals(200, res.statusCode);
        AI_Refactor_Request__c completed = [
            SELECT Status__c, Deployment_Status__c, Deployment_Id__c
            FROM AI_Refactor_Request__c
            WHERE Id = :submitted.requestId
        ];
        System.assertEquals(AIRefactorConstants.STATUS_COMPLETED, completed.Status__c);
        System.assertEquals(AIRefactorConstants.RESULT_SUCCEEDED, completed.Deployment_Status__c);
        System.assertEquals('0Af000000000001', completed.Deployment_Id__c);

        AIRefactorStatusAction.Request statusReq = new AIRefactorStatusAction.Request();
        statusReq.referenceId = stored.Name;
        String message = AIRefactorStatusAction.getStatus(
            new List<AIRefactorStatusAction.Request>{ statusReq }
        )[0].message;
        System.assert(message.contains('completed successfully'));
    }

    @isTest
    static void deploymentFailureDoesNotComplete() {
        seedConfig();
        Test.setMock(HttpCalloutMock.class, new GitHubCloudMock().add(204, ''));
        Test.startTest();
        AIRefactorAgentAction.Response submitted = AIRefactorAgentAction.submit(
            new List<AIRefactorAgentAction.Request>{ sampleRequest() }
        )[0];
        Test.stopTest();
        AI_Refactor_Request__c stored = [SELECT Name FROM AI_Refactor_Request__c WHERE Id = :submitted.requestId];
        walkTo(submitted.requestId, stored.Name, 'run-8', new List<String>{
            AIRefactorConstants.STATUS_PREPARING,
            AIRefactorConstants.STATUS_AI,
            AIRefactorConstants.STATUS_STATIC,
            AIRefactorConstants.STATUS_SF_VALIDATION,
            AIRefactorConstants.STATUS_PR_CREATED,
            AIRefactorConstants.STATUS_AWAITING,
            AIRefactorConstants.STATUS_APPROVED,
            AIRefactorConstants.STATUS_DEPLOYING
        });
        AIRefactorCallbackService.Payload fail = basePayload(submitted.requestId, stored.Name, 'run-8');
        fail.status = AIRefactorConstants.STATUS_DEPLOY_FAILED;
        fail.deploymentStatus = AIRefactorConstants.RESULT_FAILED;
        fail.deploymentId = '0AfFail';
        fail.errorSummary = 'Apex test failure in AccountServiceTest.testBulkUpdate';
        AIRefactorCallbackService.apply(fail);
        AI_Refactor_Request__c record = [
            SELECT Status__c, Deployment_Status__c
            FROM AI_Refactor_Request__c
            WHERE Id = :submitted.requestId
        ];
        System.assertEquals(AIRefactorConstants.STATUS_DEPLOY_FAILED, record.Status__c);
        System.assertNotEquals(AIRefactorConstants.STATUS_COMPLETED, record.Status__c);
        System.assertEquals(AIRefactorConstants.RESULT_FAILED, record.Deployment_Status__c);
    }

    @isTest
    static void invalidStatusTransitionIsBlocked() {
        seedConfig();
        Test.setMock(HttpCalloutMock.class, new GitHubCloudMock().add(204, ''));
        Test.startTest();
        Id requestId = AIRefactorAgentAction.submit(
            new List<AIRefactorAgentAction.Request>{ sampleRequest() }
        )[0].requestId;
        Test.stopTest();
        AI_Refactor_Request__c record = [
            SELECT Status__c FROM AI_Refactor_Request__c WHERE Id = :requestId
        ];
        record.Status__c = AIRefactorConstants.STATUS_COMPLETED;
        Boolean blocked = false;
        try {
            update record;
        } catch (DmlException ex) {
            blocked = true;
            System.assert(ex.getMessage().contains('cannot change'));
        }
        System.assertEquals(true, blocked);
    }

    @isTest
    static void retryAfterTriggerFailure() {
        seedConfig();
        AI_Refactor_Request__c record = new AI_Refactor_Request__c();
        record.Repository__c = 'acme/salesforce-core';
        record.Source_Branch__c = 'develop';
        record.Component_Path__c = 'force-app/main/default/classes/AccountTriggerHandler.cls';
        record.Requirement__c = 'Bulkify queries.';
        record.Target_Environment__c = 'QA';
        record.Status__c = AIRefactorConstants.STATUS_SUBMITTED;
        insert record;
        record.Status__c = AIRefactorConstants.STATUS_TRIGGER_FAILED;
        record.Error_Message__c = 'GitHub dispatch failed';
        update record;
        record = [SELECT Name FROM AI_Refactor_Request__c WHERE Id = :record.Id];

        Test.setMock(HttpCalloutMock.class, new GitHubCloudMock().add(204, ''));
        AIRefactorRetryAction.Request retryReq = new AIRefactorRetryAction.Request();
        retryReq.referenceId = record.Name;
        Test.startTest();
        AIRefactorRetryAction.Response retryRes = AIRefactorRetryAction.retry(
            new List<AIRefactorRetryAction.Request>{ retryReq }
        )[0];
        Test.stopTest();
        System.assert(retryRes.message.contains('retry'));
        System.assertEquals(
            AIRefactorConstants.STATUS_QUEUED,
            [SELECT Status__c FROM AI_Refactor_Request__c WHERE Id = :record.Id].Status__c
        );

        AIRefactorCallbackService.Payload step = basePayload(record.Id, record.Name, 'run-static');
        step.status = AIRefactorConstants.STATUS_PREPARING;
        AIRefactorCallbackService.apply(step);
        step = basePayload(record.Id, record.Name, 'run-static');
        step.status = AIRefactorConstants.STATUS_AI;
        AIRefactorCallbackService.apply(step);
        step = basePayload(record.Id, record.Name, 'run-static');
        step.status = AIRefactorConstants.STATUS_STATIC;
        AIRefactorCallbackService.apply(step);
        step = basePayload(record.Id, record.Name, 'run-static');
        step.status = AIRefactorConstants.STATUS_STATIC_FAILED;
        step.errorSummary = 'Critical PMD violations remain.';
        AIRefactorCallbackService.apply(step);
        Boolean retryBlocked = false;
        try {
            AIRefactorRequestService.retry(record.Name);
        } catch (AIRefactorException ex) {
            retryBlocked = true;
            System.assert(ex.getMessage().contains('new request'));
        }
        System.assertEquals(true, retryBlocked);
    }

    @isTest
    static void cancelBlocksCompletedAndAllowsEarly() {
        seedConfig();
        Test.setMock(HttpCalloutMock.class, new GitHubCloudMock().add(204, ''));
        Test.startTest();
        AIRefactorAgentAction.Response submitted = AIRefactorAgentAction.submit(
            new List<AIRefactorAgentAction.Request>{ sampleRequest() }
        )[0];
        Test.stopTest();
        AI_Refactor_Request__c stored = [SELECT Name FROM AI_Refactor_Request__c WHERE Id = :submitted.requestId];
        AIRefactorCancelAction.Request cancelReq = new AIRefactorCancelAction.Request();
        cancelReq.referenceId = stored.Name;
        AIRefactorCancelAction.Response cancelRes = AIRefactorCancelAction.cancel(
            new List<AIRefactorCancelAction.Request>{ cancelReq }
        )[0];
        System.assertEquals(AIRefactorConstants.STATUS_CANCELLED, cancelRes.status);

        Boolean blocked = false;
        try {
            AIRefactorRequestService.cancel(stored.Name);
        } catch (AIRefactorException ex) {
            blocked = true;
        }
        System.assertEquals(true, blocked);
    }

    @isTest
    static void listAndStatusUnknown() {
        seedConfig();
        AIRefactorListAction.Response listed = AIRefactorListAction.listMine(
            new List<AIRefactorListAction.Request>{ new AIRefactorListAction.Request() }
        )[0];
        System.assert(listed.message.contains('no AI refactor'));
        AIRefactorStatusAction.Request statusReq = new AIRefactorStatusAction.Request();
        statusReq.referenceId = 'AIR-999999';
        String message = AIRefactorStatusAction.getStatus(
            new List<AIRefactorStatusAction.Request>{ statusReq }
        )[0].message;
        System.assert(message.contains('No AI refactor request'));
    }

    @isTest
    static void listIncludesSubmittedRequestAndStatusFormatsProgress() {
        seedConfig();
        AI_Refactor_Request__c record = new AI_Refactor_Request__c(
            Repository__c = 'acme/salesforce-core',
            Source_Branch__c = 'develop',
            Component_Path__c = 'AUTO',
            Requirement__c = 'Improve loan decision handling.',
            Target_Environment__c = 'DEV',
            Status__c = AIRefactorConstants.STATUS_SUBMITTED
        );
        insert record;

        AIRefactorListAction.Response listed = AIRefactorListAction.listMine(
            new List<AIRefactorListAction.Request>{ new AIRefactorListAction.Request() }
        )[0];
        System.assert(listed.message.contains('Submitted'));
        System.assert(listed.detailsJson.contains('acme/salesforce-core'));

        AIRefactorRequestService.StatusResult progress = new AIRefactorRequestService.StatusResult();
        progress.referenceId = record.Name;
        progress.status = AIRefactorConstants.STATUS_AI;
        progress.targetEnvironment = 'DEV';
        System.assert(AIRefactorStatusAction.formatMessage(progress).contains('currently AI Refactoring'));

        AIRefactorRequestService.StatusResult awaiting = new AIRefactorRequestService.StatusResult();
        awaiting.referenceId = record.Name;
        awaiting.status = AIRefactorConstants.STATUS_AWAITING;
        awaiting.targetEnvironment = 'DEV';
        awaiting.validationStatus = AIRefactorConstants.RESULT_SUCCEEDED;
        awaiting.testResult = '17 passed';
        awaiting.pullRequestUrl = 'https://github.com/acme/salesforce-core/pull/1';
        awaiting.aiBranch = 'ai-refactor/AIR-000001';
        awaiting.branchZipUrl = GitHubCloudService.branchZipDownloadUrl(
            'acme/salesforce-core',
            'ai-refactor/AIR-000001'
        );
        String awaitingMessage = AIRefactorStatusAction.formatMessage(awaiting);
        System.assert(awaitingMessage.contains('awaiting Pull Request approval'));
        System.assert(
            awaitingMessage.contains(
                'https://github.com/acme/salesforce-core/archive/refs/heads/ai-refactor/AIR-000001.zip'
            ),
            awaitingMessage
        );
    }

    @isTest
    static void callbackRestRejectsBadPayloadAndRetryHandlesMissingInput() {
        seedConfig();
        RestRequest req = new RestRequest();
        RestResponse res = new RestResponse();
        req.httpMethod = 'POST';
        req.requestURI = '/services/apexrest/ai-refactor/v1/status';
        req.requestBody = Blob.valueOf('{}');
        RestContext.request = req;
        RestContext.response = res;
        AIRefactorCallbackRest.doPost();
        System.assertEquals(400, res.statusCode);

        req.requestBody = Blob.valueOf('{not-json');
        res = new RestResponse();
        RestContext.response = res;
        AIRefactorCallbackRest.doPost();
        System.assertEquals(500, res.statusCode);

        AIRefactorRetryAction.Response retry = AIRefactorRetryAction.retry(null)[0];
        System.assert(retry.message.contains('required'));
    }

    @isTest
    static void configurationMetadataAndDefaultsLoad() {
        AIRefactorConfigService.testConfig = null;
        AIRefactorConfigService.testRepos = null;
        AIRefactorConfigService.Config cfg = AIRefactorConfigService.loadConfig();
        System.assertNotEquals(null, cfg.maximumFilesPerRequest);
        System.assertNotEquals(null, cfg.allowedComponentPaths);
        System.assert(!AIRefactorConfigService.allRepositories().isEmpty());
        System.assert(!AIRefactorConfigService.enabledRepositories().isEmpty());
    }

    @isTest
    static void pathAndTransitionHelpers() {
        seedConfig();
        System.assertEquals(
            true,
            AIRefactorSecurityService.isBlockedPath('.github/workflows/x.yml', AIRefactorConfigService.loadConfig().blockedFilePaths)
        );
        System.assertEquals(
            true,
            AIRefactorSecurityService.isAllowedComponentPath(
                'force-app/main/default/classes/Foo.cls',
                AIRefactorConfigService.loadConfig().allowedComponentPaths
            )
        );
        System.assertEquals(
            false,
            AIRefactorValidationService.canCancel(new AI_Refactor_Request__c(Status__c = AIRefactorConstants.STATUS_COMPLETED))
        );
        System.assertEquals(
            true,
            AIRefactorValidationService.canRetry(new AI_Refactor_Request__c(Status__c = AIRefactorConstants.STATUS_TRIGGER_FAILED))
        );
        System.assertEquals(
            'AI refactor deployment completed',
            AIRefactorNotificationService.titleFor(AIRefactorConstants.STATUS_COMPLETED)
        );
    }

    @isTest
    static void staticAnalysisCanReachPrCreatedWhenValidationIsSkipped() {
        seedConfig();
        Test.setMock(HttpCalloutMock.class, new GitHubCloudMock().add(204, ''));
        Test.startTest();
        AIRefactorAgentAction.Response submitted = AIRefactorAgentAction.submit(
            new List<AIRefactorAgentAction.Request>{ sampleRequest() }
        )[0];
        Test.stopTest();
        AI_Refactor_Request__c stored = [
            SELECT Name FROM AI_Refactor_Request__c WHERE Id = :submitted.requestId
        ];
        walkTo(submitted.requestId, stored.Name, 'run-skip', new List<String>{
            AIRefactorConstants.STATUS_PREPARING,
            AIRefactorConstants.STATUS_AI,
            AIRefactorConstants.STATUS_STATIC
        });

        AIRefactorCallbackService.Payload committed = basePayload(
            submitted.requestId,
            stored.Name,
            'run-skip'
        );
        committed.status = AIRefactorConstants.STATUS_PR_CREATED;
        committed.branch = 'agent-orglicense-e2e';
        committed.pullRequestUrl = 'https://github.com/acme/salesforce-core/tree/agent-orglicense-e2e';
        committed.outputCommit = 'abc123skip';
        committed.validationStatus = AIRefactorConstants.RESULT_SKIPPED;
        committed.testSummary = 'Skipped';
        committed.summary = 'AI changes were committed onto the copied branch.';
        AIRefactorCallbackService.Result result = AIRefactorCallbackService.apply(committed);
        System.assertEquals(true, result.success);

        AIRefactorCallbackService.Payload awaiting = basePayload(
            submitted.requestId,
            stored.Name,
            'run-skip'
        );
        awaiting.status = AIRefactorConstants.STATUS_AWAITING;
        AIRefactorCallbackService.apply(awaiting);

        AI_Refactor_Request__c record = [
            SELECT Status__c, Validation_Status__c, AI_Branch__c, Output_Commit_SHA__c
            FROM AI_Refactor_Request__c
            WHERE Id = :submitted.requestId
        ];
        System.assertEquals(AIRefactorConstants.STATUS_AWAITING, record.Status__c);
        System.assertEquals(AIRefactorConstants.RESULT_SKIPPED, record.Validation_Status__c);
        System.assertEquals('agent-orglicense-e2e', record.AI_Branch__c);
        System.assertEquals('abc123skip', record.Output_Commit_SHA__c);
    }

    private static AIRefactorCallbackService.Payload basePayload(Id requestId, String referenceId, String runId) {
        AIRefactorCallbackService.Payload payload = new AIRefactorCallbackService.Payload();
        payload.requestId = requestId;
        payload.referenceId = referenceId;
        payload.workflowRunId = runId;
        return payload;
    }

    private static void walkTo(Id requestId, String referenceId, String runId, List<String> statuses) {
        for (String status : statuses) {
            AIRefactorCallbackService.Payload payload = basePayload(requestId, referenceId, runId);
            payload.status = status;
            if (status == AIRefactorConstants.STATUS_PR_CREATED) {
                payload.pullRequestNumber = 425;
                payload.pullRequestUrl = 'https://github.com/acme/salesforce-core/pull/425';
                payload.branch = 'ai-refactor/' + referenceId;
                payload.validationStatus = AIRefactorConstants.RESULT_SUCCEEDED;
                payload.pmdStatus = AIRefactorConstants.RESULT_SUCCEEDED;
                payload.testSummary = '24 passed, 0 failed';
                payload.summary = 'Refactored bulk query handling.';
            }
            AIRefactorCallbackService.apply(payload);
        }
    }
}
