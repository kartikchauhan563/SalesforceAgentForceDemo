@isTest
private class SfOrgDeployTest {
    @testSetup
    static void setupConfig() {
        Sf_Org_OAuth_Secret__c cfg = new Sf_Org_OAuth_Secret__c(
            SetupOwnerId = UserInfo.getOrganizationId(),
            Consumer_Key__c = 'CLIENTKEY',
            Aes_Key__c = EncodingUtil.base64Encode(Crypto.generateAesKey(256))
        );
        insert cfg;
    }

    @isTest
    static void submitConfirmedSandboxDeployment() {
        insert connection('sandbox-connection', true);
        Test.setMock(HttpCalloutMock.class, new GitHubCloudMock().add(204, ''));

        Test.startTest();
        SfOrgDeployService.SubmitResult result = SfOrgDeployService.submit(
            null,
            null,
            'kartikchauhan563/SalesforceAgentForceDemo',
            'feature/field',
            '["force-app/main/default/objects/Account/fields/Test__c.field-meta.xml"]',
            'sandbox-connection',
            true,
            false
        );
        Test.stopTest();

        System.assertEquals(true, result.success, result.message);
        System.assertNotEquals(null, result.referenceId);
        Sf_Org_Deployment__c request = [
            SELECT Status__c, Repository__c, Branch__c, Component_Paths__c
            FROM Sf_Org_Deployment__c
            WHERE Id = :result.requestId
        ];
        System.assertEquals('Queued', request.Status__c);
        System.assertEquals('feature/field', request.Branch__c);
        System.assert(request.Component_Paths__c.contains('Test__c.field-meta.xml'));
    }

    @isTest
    static void submitRequiresConfirmationAndProductionGate() {
        insert connection('production-connection', false);
        SfOrgDeployService.SubmitResult unconfirmed = SfOrgDeployService.submit(
            null, null, null, 'feature-x', 'force-app/main/default/classes',
            'production-connection', false, false
        );
        System.assertEquals(false, unconfirmed.success);
        System.assert(unconfirmed.message.contains('Confirm'));

        SfOrgDeployService.SubmitResult production = SfOrgDeployService.submit(
            null, null, null, 'feature-x', 'force-app/main/default/classes',
            'production-connection', true, false
        );
        System.assertEquals(false, production.success);
        System.assert(production.message.contains('production'));
        System.assertEquals(0, [SELECT count() FROM Sf_Org_Deployment__c]);
    }

    @isTest
    static void rejectsUnsafePathAndUnauthorizedConnection() {
        SfOrgDeployService.SubmitResult unsafe = SfOrgDeployService.submit(
            null, null, null, 'feature-x', 'force-app/../secret',
            'missing', true, true
        );
        System.assertEquals(false, unsafe.success);
        System.assert(unsafe.message.contains('Unsafe'));

        SfOrgDeployService.SubmitResult missing = SfOrgDeployService.submit(
            null, null, null, 'feature-x', 'force-app/main/default/classes',
            'missing', true, true
        );
        System.assertEquals(false, missing.success);
        System.assert(missing.message.contains('Authorize'));
    }

    @isTest
    static void claimIsSingleUseAndReturnsDecryptedSession() {
        insert connection('claim-connection', true);
        Sf_Org_Deployment__c request = deployment('claim-connection', true);
        insert request;

        SfOrgDeployService.ClaimResult claim = SfOrgDeployService.claim(request.Id);
        System.assertEquals('https://target.example.my.salesforce.com', claim.instanceUrl);
        System.assertEquals('ACCESS_TOKEN', claim.accessToken);
        System.assertEquals(true, claim.isSandbox);
        System.assertEquals(1, claim.componentPaths.size());

        try {
            SfOrgDeployService.claim(request.Id);
            System.assert(false, 'A second claim must fail.');
        } catch (SfOrgDeployService.DeployException ex) {
            System.assert(ex.getMessage().contains('already claimed'));
        }
    }

    @isTest
    static void callbackAndStatusActionAreIdempotent() {
        insert connection('status-connection', true);
        Sf_Org_Deployment__c request = deployment('status-connection', true);
        insert request;

        SfOrgDeployService.StatusPayload payload = new SfOrgDeployService.StatusPayload();
        payload.requestId = request.Id;
        payload.workflowRunId = '12345';
        payload.status = 'Succeeded';
        payload.validationId = '0Af-validation';
        payload.deploymentId = '0Af-deployment';
        payload.result = 'Deployment succeeded';
        SfOrgDeployService.applyStatus(payload);
        SfOrgDeployService.applyStatus(payload);

        request = [SELECT Name FROM Sf_Org_Deployment__c WHERE Id = :request.Id];
        GitHubAction_DeploymentStatus.Request actionRequest = new GitHubAction_DeploymentStatus.Request();
        actionRequest.referenceId = request.Name;
        List<GitHubAction_DeploymentStatus.Response> result = GitHubAction_DeploymentStatus.run(
            new List<GitHubAction_DeploymentStatus.Request>{ actionRequest }
        );
        System.assertEquals(true, result[0].success);
        System.assertEquals('Succeeded', result[0].status);
        System.assert(result[0].message.contains('0Af-deployment'));
    }

    @isTest
    static void restClaimAndStatusWorkForAuthenticatedUser() {
        insert connection('rest-connection', true);
        Sf_Org_Deployment__c request = deployment('rest-connection', true);
        insert request;

        RestRequest claimRequest = new RestRequest();
        claimRequest.requestURI = '/services/apexrest/oauth-deploy/v1/claim';
        claimRequest.httpMethod = 'GET';
        claimRequest.params.put('requestId', request.Id);
        RestContext.request = claimRequest;
        RestContext.response = new RestResponse();
        SfOrgDeployRest.claimSession();
        System.assertEquals(200, RestContext.response.statusCode);
        System.assert(RestContext.response.responseBody.toString().contains('ACCESS_TOKEN'));

        RestRequest statusRequest = new RestRequest();
        statusRequest.requestURI = '/services/apexrest/oauth-deploy/v1/status';
        statusRequest.httpMethod = 'POST';
        statusRequest.requestBody = Blob.valueOf(JSON.serialize(new Map<String, Object>{
            'requestId' => request.Id,
            'status' => 'Deploying',
            'workflowRunId' => '987'
        }));
        RestContext.request = statusRequest;
        RestContext.response = new RestResponse();
        SfOrgDeployRest.updateStatus();
        System.assertEquals(200, RestContext.response.statusCode);

        RestContext.request = claimRequest;
        RestContext.response = new RestResponse();
        SfOrgDeployRest.claimSession();
        System.assertEquals(409, RestContext.response.statusCode);

        statusRequest.requestBody = Blob.valueOf('{"requestId":"' + request.Id + '","status":"Invalid"}');
        RestContext.request = statusRequest;
        RestContext.response = new RestResponse();
        SfOrgDeployRest.updateStatus();
        System.assertEquals(400, RestContext.response.statusCode);
    }

    @isTest
    static void actionWrapsSubmitResult() {
        insert connection('action-connection', true);
        Test.setMock(HttpCalloutMock.class, new GitHubCloudMock().add(204, ''));
        GitHubAction_DeployToAuthorizedOrg.Request request = new GitHubAction_DeployToAuthorizedOrg.Request();
        request.ownerRepo = 'kartikchauhan563/SalesforceAgentForceDemo';
        request.branch = 'field-copy';
        request.componentPaths = 'force-app/main/default/objects/Account/fields/Test__c.field-meta.xml';
        request.connectionId = 'action-connection';
        request.deploymentConfirmed = true;
        Test.startTest();
        List<GitHubAction_DeployToAuthorizedOrg.Response> result =
            GitHubAction_DeployToAuthorizedOrg.run(
                new List<GitHubAction_DeployToAuthorizedOrg.Request>{ request }
            );
        Test.stopTest();
        System.assertEquals(true, result[0].success, result[0].message);
        System.assert(result[0].referenceId.startsWith('SFD-'));
    }

    @isTest
    static void queueableRecordsDispatchFailureAndSkipsCompletedRequest() {
        insert connection('queue-connection', true);
        Sf_Org_Deployment__c failedDispatch = deployment('queue-connection', true);
        insert failedDispatch;
        Test.setMock(HttpCalloutMock.class, new GitHubCloudMock().add(500, '{"message":"workflow unavailable"}'));
        Test.startTest();
        new GitHubOAuthDeployQueueable(failedDispatch.Id).execute(null);
        new GitHubOAuthDeployQueueable(null).execute(null);
        Test.stopTest();
        failedDispatch = [
            SELECT Status__c, Error_Message__c
            FROM Sf_Org_Deployment__c
            WHERE Id = :failedDispatch.Id
        ];
        System.assertEquals('Failed', failedDispatch.Status__c);
        System.assertNotEquals(null, failedDispatch.Error_Message__c);

        failedDispatch.Status__c = 'Succeeded';
        update failedDispatch;
        new GitHubOAuthDeployQueueable(failedDispatch.Id).execute(null);
        System.assertEquals(
            'Succeeded',
            [SELECT Status__c FROM Sf_Org_Deployment__c WHERE Id = :failedDispatch.Id].Status__c
        );
    }

    private static Sf_Org_Connection__c connection(String key, Boolean isSandbox) {
        return new Sf_Org_Connection__c(
            Connection_Key__c = key,
            Status__c = 'Authorized',
            Login_Host__c = 'login.salesforce.com',
            Instance_Url__c = 'https://target.example.my.salesforce.com',
            Access_Token_Enc__c = SfOrgOAuthService.encryptValue('ACCESS_TOKEN'),
            Refresh_Token_Enc__c = SfOrgOAuthService.encryptValue('REFRESH_TOKEN'),
            Token_Issued_At__c = System.now(),
            Is_Sandbox__c = isSandbox
        );
    }

    private static Sf_Org_Deployment__c deployment(String key, Boolean productionConfirmed) {
        return new Sf_Org_Deployment__c(
            Repository__c = 'kartikchauhan563/SalesforceAgentForceDemo',
            Branch__c = 'field-copy',
            Component_Paths__c = '["force-app/main/default/objects/Account/fields/Test__c.field-meta.xml"]',
            Connection_Key__c = key,
            Status__c = 'Queued',
            Production_Confirmed__c = productionConfirmed,
            Requested_At__c = System.now()
        );
    }
}
