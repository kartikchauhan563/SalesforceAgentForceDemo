@isTest
private class GitHubCloudAgentTest {
    private static final String REF_BODY =
        '{"ref":"refs/heads/master","object":{"sha":"abc123def456"}}';
    private static final String CREATE_BODY =
        '{"ref":"refs/heads/demo-1","object":{"sha":"abc123def456"},"url":"https://api.github.com/repos/kartikchauhan563/SalesforceAgentForceDemo/git/refs/heads/demo-1"}';

    @isTest
    static void resolveDefaultsAndOwnerRepo() {
        GitHubCloudConfig.RepoTarget defaults = GitHubCloudConfig.defaults();
        System.assertEquals('kartikchauhan563', defaults.owner);
        System.assertEquals('SalesforceAgentForceDemo', defaults.repo);
        System.assertEquals('master', defaults.baseBranch);

        GitHubCloudConfig.RepoTarget parsed = GitHubCloudConfig.resolve(
            null,
            null,
            'https://github.com/acme/demo.git'
        );
        System.assertEquals('acme', parsed.owner);
        System.assertEquals('demo', parsed.repo);

        GitHubCloudConfig.RepoTarget fromRepo = GitHubCloudConfig.resolve(null, 'ownerx/repx', null);
        System.assertEquals('ownerx', fromRepo.owner);
        System.assertEquals('repx', fromRepo.repo);

        GitHubCloudConfig.ParsedGitHubUrl parsedUrl = GitHubCloudConfig.parseGitHubUrl(
            'https://github.com/acme/demo/tree/release-1'
        );
        System.assertEquals('acme', parsedUrl.owner);
        System.assertEquals('demo', parsedUrl.repo);
        System.assertEquals('release-1', parsedUrl.branch);
        System.assertEquals('https://github.com/acme/demo', parsedUrl.canonicalUrl);
        System.assertEquals(true, GitHubCloudConfig.isSafeBranchName('imported-demo'));
        System.assertEquals(false, GitHubCloudConfig.isSafeBranchName('../secret'));
    }

    @isTest
    static void createBranchSuccess() {
        Test.setMock(
            HttpCalloutMock.class,
            new GitHubCloudMock().add(200, REF_BODY).add(201, CREATE_BODY)
        );
        Test.startTest();
        GitHubAction_CreateBranch.Request req = new GitHubAction_CreateBranch.Request();
        req.newBranch = 'demo-1';
        req.sourceBranch = 'master';
        List<GitHubAction_CreateBranch.Response> res = GitHubAction_CreateBranch.run(
            new List<GitHubAction_CreateBranch.Request>{ req }
        );
        Test.stopTest();
        System.assertEquals(true, res[0].success);
        System.assert(res[0].message.contains('demo-1'));
        System.assert(res[0].message.contains('SalesforceAgentForceDemo'));
        System.assert(
            res[0].branchZipUrl.contains('/archive/refs/heads/demo-1.zip'),
            res[0].branchZipUrl
        );
        System.assert(res[0].message.contains(res[0].branchZipUrl));
    }

    @isTest
    static void createComponentInBranchCreatesBranchWritesFileAndReturnsZip() {
        String notFound = '{"message":"Not Found"}';
        String putJson =
            '{"content":{"html_url":"https://github.com/kartikchauhan563/SalesforceAgentForceDemo/blob/opportunity-flow/force-app/main/default/flows/Fetch_All_Opportunities.flow-meta.xml"}}';
        Test.setMock(
            HttpCalloutMock.class,
            new GitHubCloudMock()
                .add(404, notFound)
                .add(200, REF_BODY)
                .add(201, CREATE_BODY)
                .add(200, REF_BODY)
                .add(404, notFound)
                .add(200, putJson)
        );
        Test.startTest();
        GitHubAction_CreateComponent.Request req = new GitHubAction_CreateComponent.Request();
        req.newBranch = 'opportunity-flow';
        req.sourceBranch = 'master';
        req.filePath = 'force-app/main/default/flows/Fetch_All_Opportunities.flow-meta.xml';
        req.fileContent = '<?xml version="1.0" encoding="UTF-8"?><Flow></Flow>';
        List<GitHubAction_CreateComponent.Response> res = GitHubAction_CreateComponent.run(
            new List<GitHubAction_CreateComponent.Request>{ req }
        );
        Test.stopTest();
        System.assertEquals(true, res[0].success, res[0].message);
        System.assert(res[0].message.contains('Created branch "opportunity-flow"'), res[0].message);
        System.assertEquals(
            'https://github.com/kartikchauhan563/SalesforceAgentForceDemo/archive/refs/heads/opportunity-flow.zip',
            res[0].branchZipUrl
        );
        System.assert(res[0].message.contains(res[0].branchZipUrl), res[0].message);
    }

    @isTest
    static void createComponentInBranchValidatesRequiredInput() {
        Test.startTest();
        GitHubCloudService.Result noBranch = GitHubCloudService.createComponentInBranch(
            null, null, null, 'master', null, 'a/b.cls', 'x', null
        );
        GitHubCloudService.Result noPath = GitHubCloudService.createComponentInBranch(
            null, null, null, 'master', 'demo-1', null, 'x', null
        );
        GitHubCloudService.Result noContent = GitHubCloudService.createComponentInBranch(
            null, null, null, 'master', 'demo-1', 'a/b.cls', null, null
        );
        Test.stopTest();
        System.assertEquals(false, noBranch.success);
        System.assertEquals(false, noPath.success);
        System.assertEquals(false, noContent.success);
    }

    @isTest
    static void branchZipDownloadUrlUsesGitHubArchive() {
        System.assertEquals(
            'https://github.com/kartikchauhan563/SalesforceAgentForceDemo/archive/refs/heads/ai-refactor/AIR-000123.zip',
            GitHubCloudService.branchZipDownloadUrl(
                'kartikchauhan563/SalesforceAgentForceDemo',
                'ai-refactor/AIR-000123'
            )
        );
        System.assertEquals(null, GitHubCloudService.branchZipDownloadUrl(null, 'demo-1'));
        System.assertEquals(null, GitHubCloudService.branchZipDownloadUrl('kartikchauhan563/SalesforceAgentForceDemo', null));
    }

    @isTest
    static void zipMarkdownLinkIsClickableMarkdown() {
        String zipUrl = 'https://github.com/acme/demo/archive/refs/heads/demo-1.zip';
        System.assertEquals(
            '[Download demo-1 as ZIP](' + zipUrl + ')',
            GitHubCloudService.zipMarkdownLink('demo-1', zipUrl)
        );
        System.assertEquals(
            '[Download branch as ZIP](' + zipUrl + ')',
            GitHubCloudService.zipMarkdownLink(null, zipUrl)
        );
        System.assertEquals('', GitHubCloudService.zipMarkdownLink('demo-1', null));
    }

    @isTest
    static void copyBranchAssetsSuccess() {
        Test.setMock(
            HttpCalloutMock.class,
            new GitHubCloudMock().add(200, REF_BODY).add(201, CREATE_BODY)
        );
        Test.startTest();
        GitHubAction_CopyBranchAssets.Request req = new GitHubAction_CopyBranchAssets.Request();
        req.ownerRepo = 'kartikchauhan563/SalesforceAgentForceDemo';
        req.sourceBranch = 'master';
        req.newBranch = 'asset-copy';
        List<GitHubAction_CopyBranchAssets.Response> res = GitHubAction_CopyBranchAssets.run(
            new List<GitHubAction_CopyBranchAssets.Request>{ req }
        );
        Test.stopTest();
        System.assertEquals(true, res[0].success);
        System.assert(res[0].message.contains('asset-copy'));
        System.assert(
            res[0].branchZipUrl.contains('/archive/refs/heads/asset-copy.zip'),
            res[0].branchZipUrl
        );
    }

    @isTest
    static void copyExternalRepositoryRequiresUrlAndBranch() {
        Test.startTest();
        GitHubCloudService.Result noUrl = GitHubCloudService.copyExternalRepository(
            null, null, 'imported-demo', null, null, null
        );
        GitHubCloudService.Result noBranch = GitHubCloudService.copyExternalRepository(
            'https://github.com/acme/demo', null, null, null, null, null
        );
        Test.stopTest();
        System.assertEquals(false, noUrl.success);
        System.assert(noUrl.message.contains('GitHub repository URL'));
        System.assertEquals(false, noBranch.success);
        System.assert(noBranch.message.contains('new branch name'));
    }

    @isTest
    static void copyExternalRepositorySameRepoUsesRefCopy() {
        Test.setMock(
            HttpCalloutMock.class,
            new GitHubCloudMock().add(200, REF_BODY).add(201, CREATE_BODY)
        );
        Test.startTest();
        GitHubAction_CopyExternalRepo.Request req = new GitHubAction_CopyExternalRepo.Request();
        req.sourceRepoUrl = 'https://github.com/kartikchauhan563/SalesforceAgentForceDemo';
        req.sourceBranch = 'master';
        req.newBranch = 'imported-same';
        List<GitHubAction_CopyExternalRepo.Response> res = GitHubAction_CopyExternalRepo.run(
            new List<GitHubAction_CopyExternalRepo.Request>{ req }
        );
        Test.stopTest();
        System.assertEquals(true, res[0].success);
        System.assert(res[0].message.contains('imported-same'));
        System.assert(res[0].branchZipUrl.contains('/archive/refs/heads/imported-same.zip'));
    }

    @isTest
    static void copyExternalRepositoryDispatchesWorkflow() {
        String repoJson =
            '{"default_branch":"master","html_url":"https://github.com/kartikchauhan563/SalesforceAgentForceDemo"}';
        Test.setMock(
            HttpCalloutMock.class,
            new GitHubCloudMock().add(200, repoJson).add(204, '')
        );
        Test.startTest();
        GitHubAction_CopyExternalRepo.Request req = new GitHubAction_CopyExternalRepo.Request();
        req.sourceRepoUrl = 'https://github.com/acme/loan-app';
        req.newBranch = 'imported-loan-app';
        List<GitHubAction_CopyExternalRepo.Response> res = GitHubAction_CopyExternalRepo.run(
            new List<GitHubAction_CopyExternalRepo.Request>{ req }
        );
        Test.stopTest();
        System.assertEquals(true, res[0].success, res[0].message);
        System.assert(res[0].message.contains('https://github.com/acme/loan-app'));
        System.assert(res[0].message.contains('imported-loan-app'));
        System.assert(res[0].message.contains('GitHub Actions'));
    }

    @isTest
    static void copyExternalRepositoryWithRequirementQueuesCopyAndApply() {
        AIRefactorConfigService.Config cfg = AIRefactorConfigService.defaults();
        cfg.githubOrganization = 'kartikchauhan563';
        cfg.defaultRepository = 'SalesforceAgentForceDemo';
        cfg.defaultBaseBranch = 'master';
        cfg.namedCredential = 'GitHub_API';
        AIRefactorConfigService.testConfig = cfg;
        AIRefactorConfigService.Repo repo = new AIRefactorConfigService.Repo();
        repo.displayName = 'SalesforceAgentForceDemo';
        repo.organization = 'kartikchauhan563';
        repo.repositoryName = 'SalesforceAgentForceDemo';
        repo.defaultBranch = 'master';
        repo.enabled = true;
        repo.allowedTargets = new Set<String>{ 'DEV', 'QA', 'UAT' };
        AIRefactorConfigService.testRepos = new List<AIRefactorConfigService.Repo>{ repo };

        Test.setMock(HttpCalloutMock.class, new GitHubCloudMock().add(204, ''));
        Test.startTest();
        GitHubAction_CopyAndApplyRepo.Request req = new GitHubAction_CopyAndApplyRepo.Request();
        req.sourceRepoUrl = 'https://github.com/acme/loan-app';
        req.newBranch = 'imported-loan-app-ai';
        req.requirement = 'Rename the agent to Salesforce Best Agent.';
        req.targetEnvironment = 'DEV';
        List<GitHubAction_CopyAndApplyRepo.Response> res = GitHubAction_CopyAndApplyRepo.run(
            new List<GitHubAction_CopyAndApplyRepo.Request>{ req }
        );
        Test.stopTest();
        System.assertEquals(true, res[0].success, res[0].message);
        System.assertNotEquals(null, res[0].referenceId);
        System.assert(res[0].message.contains('one pipeline'));
        AI_Refactor_Request__c stored = [
            SELECT Status__c, Source_Branch__c, Requirement__c
            FROM AI_Refactor_Request__c
            WHERE Name = :res[0].referenceId
        ];
        System.assertEquals('imported-loan-app-ai', stored.Source_Branch__c);
        System.assertEquals(AIRefactorConstants.STATUS_QUEUED, stored.Status__c);
        System.assert(stored.Requirement__c.contains('Salesforce Best Agent'));
    }

    @isTest
    static void sameRepoCopyWithRequirementCopiesBeforeRefactor() {
        AIRefactorConfigService.Config cfg = AIRefactorConfigService.defaults();
        cfg.githubOrganization = 'kartikchauhan563';
        cfg.defaultRepository = 'SalesforceAgentForceDemo';
        cfg.defaultBaseBranch = 'master';
        cfg.namedCredential = 'GitHub_API';
        AIRefactorConfigService.testConfig = cfg;
        AIRefactorConfigService.Repo repo = new AIRefactorConfigService.Repo();
        repo.displayName = 'SalesforceAgentForceDemo';
        repo.organization = 'kartikchauhan563';
        repo.repositoryName = 'SalesforceAgentForceDemo';
        repo.defaultBranch = 'master';
        repo.enabled = true;
        repo.allowedTargets = new Set<String>{ 'DEV' };
        AIRefactorConfigService.testRepos = new List<AIRefactorConfigService.Repo>{ repo };

        Test.setMock(
            HttpCalloutMock.class,
            new GitHubCloudMock().add(200, REF_BODY).add(201, CREATE_BODY).add(204, '')
        );
        Test.startTest();
        GitHubAction_CopyExternalRepo.Request req = new GitHubAction_CopyExternalRepo.Request();
        req.sourceRepoUrl = 'https://github.com/kartikchauhan563/SalesforceAgentForceDemo';
        req.sourceBranch = 'master';
        req.newBranch = 'same-repo-ai';
        req.requirement = 'Update the copied branch documentation.';
        List<GitHubAction_CopyExternalRepo.Response> res = GitHubAction_CopyExternalRepo.run(
            new List<GitHubAction_CopyExternalRepo.Request>{ req }
        );
        Test.stopTest();

        System.assertEquals(true, res[0].success, res[0].message);
        AI_Refactor_Request__c stored = [
            SELECT Status__c, Source_Branch__c
            FROM AI_Refactor_Request__c
            WHERE Name = :res[0].referenceId
        ];
        System.assertEquals('same-repo-ai', stored.Source_Branch__c);
        System.assertEquals(AIRefactorConstants.STATUS_QUEUED, stored.Status__c);
    }

    @isTest
    static void copyAndApplyQueueableStopsForCancelledRequest() {
        AIRefactorConfigService.Config cfg = AIRefactorConfigService.defaults();
        cfg.githubOrganization = 'kartikchauhan563';
        cfg.defaultRepository = 'SalesforceAgentForceDemo';
        AIRefactorConfigService.testConfig = cfg;
        AIRefactorConfigService.Repo repo = new AIRefactorConfigService.Repo();
        repo.displayName = 'SalesforceAgentForceDemo';
        repo.organization = 'kartikchauhan563';
        repo.repositoryName = 'SalesforceAgentForceDemo';
        repo.defaultBranch = 'master';
        repo.enabled = true;
        repo.allowedTargets = new Set<String>{ 'DEV' };
        AIRefactorConfigService.testRepos = new List<AIRefactorConfigService.Repo>{ repo };

        AIRefactorRequestService.SubmitCommand command = new AIRefactorRequestService.SubmitCommand();
        command.repository = repo.ownerRepo;
        command.sourceBranch = 'cancelled-copy';
        command.requirement = 'This request will be cancelled before dispatch.';
        command.targetEnvironment = 'DEV';
        AIRefactorRequestService.SubmitResult submitted = AIRefactorRequestService.submit(command, false);
        AI_Refactor_Request__c request = [
            SELECT Status__c
            FROM AI_Refactor_Request__c
            WHERE Id = :submitted.requestId
        ];
        request.Status__c = AIRefactorConstants.STATUS_CANCELLED;
        update request;

        Test.startTest();
        System.enqueueJob(
            new GitHubCopyAndApplyQueueable(
                submitted.requestId,
                'https://github.com/acme/example',
                'main',
                false
            )
        );
        Test.stopTest();

        request = [
            SELECT Status__c, Dispatch_In_Flight__c
            FROM AI_Refactor_Request__c
            WHERE Id = :submitted.requestId
        ];
        System.assertEquals(AIRefactorConstants.STATUS_CANCELLED, request.Status__c);
        System.assertEquals(false, request.Dispatch_In_Flight__c);
    }

    @isTest
    static void confirmCopiedBranchReportsFiles() {
        String tree = '{"tree":[{"path":"sfdx-project.json","type":"blob"},{"path":"force-app","type":"tree"}]}';
        Test.setMock(
            HttpCalloutMock.class,
            new GitHubCloudMock().add(200, REF_BODY).add(200, tree)
        );
        Test.startTest();
        GitHubAction_ConfirmCopiedBranch.Request req = new GitHubAction_ConfirmCopiedBranch.Request();
        req.branch = 'imported-loan-app';
        List<GitHubAction_ConfirmCopiedBranch.Response> res = GitHubAction_ConfirmCopiedBranch.run(
            new List<GitHubAction_ConfirmCopiedBranch.Request>{ req }
        );
        Test.stopTest();
        System.assertEquals(true, res[0].success);
        System.assert(res[0].message.contains('Copy confirmed'));
        System.assert(res[0].message.contains('imported-loan-app'));
        System.assert(res[0].message.contains('copied branch') || res[0].message.contains('AIR'));
    }

    @isTest
    static void copyBranchAssetsRequiresDestination() {
        Test.startTest();
        GitHubCloudService.Result res = GitHubCloudService.copyBranchAssets(null, null, null, 'master', null);
        Test.stopTest();
        System.assertEquals(false, res.success);
    }

    @isTest
    static void listBranchesAndDescribeAndFiles() {
        String branches = '[{"name":"master"},{"name":"demo-1"}]';
        String repo = '{"full_name":"kartikchauhan563/SalesforceAgentForceDemo","default_branch":"master","html_url":"https://github.com/kartikchauhan563/SalesforceAgentForceDemo"}';
        String tree = '{"tree":[{"path":"sfdx-project.json","type":"blob"},{"path":"force-app","type":"tree"}]}';
        Test.setMock(
            HttpCalloutMock.class,
            new GitHubCloudMock().add(200, branches).add(200, repo).add(200, REF_BODY).add(200, tree)
        );

        Test.startTest();
        GitHubAction_ListBranches.Request branchReq = new GitHubAction_ListBranches.Request();
        List<GitHubAction_ListBranches.Response> branchRes = GitHubAction_ListBranches.run(
            new List<GitHubAction_ListBranches.Request>{ branchReq }
        );
        GitHubAction_DescribeRepo.Request repoReq = new GitHubAction_DescribeRepo.Request();
        List<GitHubAction_DescribeRepo.Response> repoRes = GitHubAction_DescribeRepo.run(
            new List<GitHubAction_DescribeRepo.Request>{ repoReq }
        );
        GitHubAction_ListFiles.Request fileReq = new GitHubAction_ListFiles.Request();
        fileReq.branch = 'master';
        List<GitHubAction_ListFiles.Response> fileRes = GitHubAction_ListFiles.run(
            new List<GitHubAction_ListFiles.Request>{ fileReq }
        );
        Test.stopTest();

        System.assertEquals(true, branchRes[0].success);
        System.assert(branchRes[0].message.contains('master'));
        System.assertEquals(true, repoRes[0].success);
        System.assertEquals(true, fileRes[0].success);
        System.assert(fileRes[0].message.contains('1 files'));
    }

    @isTest
    static void createBranchGitHubError() {
        Test.setMock(
            HttpCalloutMock.class,
            new GitHubCloudMock().add(404, '{"message":"Not Found"}')
        );
        Test.startTest();
        GitHubAction_CreateBranch.Request req = new GitHubAction_CreateBranch.Request();
        req.newBranch = 'missing-source';
        req.sourceBranch = 'does-not-exist';
        List<GitHubAction_CreateBranch.Response> res = GitHubAction_CreateBranch.run(
            new List<GitHubAction_CreateBranch.Request>{ req }
        );
        Test.stopTest();
        System.assertEquals(false, res[0].success);
        System.assert(res[0].message.contains('404'));
    }

    @isTest
    static void copyFallsBackToDefaultBranchWhenSourceMissing() {
        String repoJson = '{"default_branch":"master","html_url":"https://github.com/kartikchauhan563/SalesforceAgentForceDemo"}';
        Test.setMock(
            HttpCalloutMock.class,
            new GitHubCloudMock()
                .add(404, '{"message":"Not Found"}')
                .add(200, repoJson)
                .add(200, REF_BODY)
                .add(201, CREATE_BODY)
        );
        Test.startTest();
        GitHubAction_CopyBranchAssets.Request req = new GitHubAction_CopyBranchAssets.Request();
        req.sourceBranch = 'main';
        req.newBranch = 'Testing';
        List<GitHubAction_CopyBranchAssets.Response> res = GitHubAction_CopyBranchAssets.run(
            new List<GitHubAction_CopyBranchAssets.Request>{ req }
        );
        Test.stopTest();
        System.assertEquals(true, res[0].success);
        System.assert(res[0].message.contains('does not exist'), 'Should explain the fallback');
        System.assert(res[0].message.contains('master'), 'Should report the default branch used');
        System.assert(res[0].message.contains('Testing'), 'Should report the new branch');
    }

    @isTest
    static void copyFolderOntoExistingBranch() {
        String tree = '{"tree":[' +
            '{"path":"force-app/main/default/classes/A.cls","type":"blob","mode":"100644","sha":"blob1"},' +
            '{"path":"force-app/main/default/classes/B.cls","type":"blob","mode":"100644","sha":"blob2"},' +
            '{"path":"force-app/main/default/flows/F.flow-meta.xml","type":"blob","mode":"100644","sha":"blob3"}' +
            ']}';
        Test.setMock(
            HttpCalloutMock.class,
            new GitHubCloudMock()
                .add(200, REF_BODY)
                .add(200, tree)
                .add(200, REF_BODY)
                .add(200, '{"tree":{"sha":"basetree"}}')
                .add(201, '{"sha":"newtree"}')
                .add(201, '{"sha":"newcommit"}')
                .add(200, '{"ref":"refs/heads/Testing"}')
        );
        Test.startTest();
        GitHubAction_CopyFolder.Request req = new GitHubAction_CopyFolder.Request();
        req.sourceBranch = 'master';
        req.folderPath = 'force-app/main/default/classes';
        req.destinationBranch = 'Testing';
        List<GitHubAction_CopyFolder.Response> res = GitHubAction_CopyFolder.run(
            new List<GitHubAction_CopyFolder.Request>{ req }
        );
        Test.stopTest();
        System.assertEquals(true, res[0].success);
        System.assert(res[0].message.contains('2 file(s)'), 'Only the classes folder should be copied');
        System.assert(res[0].message.contains('force-app/main/default/classes'));
        System.assert(res[0].message.contains('already existed'), 'Should report the additive outcome');
    }

    @isTest
    static void copyFolderToNewBranchContainsOnlyThatFolder() {
        String tree = '{"tree":[' +
            '{"path":"force-app/main/default/classes/A.cls","type":"blob","mode":"100644","sha":"blob1"},' +
            '{"path":"sfdx-project.json","type":"blob","mode":"100644","sha":"blob9"}' +
            ']}';
        GitHubCloudMock mock = new GitHubCloudMock()
            .add(200, REF_BODY)
            .add(200, tree)
            .add(404, '{"message":"Not Found"}')
            .add(201, '{"sha":"newtree"}')
            .add(201, '{"sha":"newcommit"}')
            .add(201, '{"ref":"refs/heads/OnlyClasses"}');
        Test.setMock(HttpCalloutMock.class, mock);

        Test.startTest();
        GitHubAction_CopyFolder.Request req = new GitHubAction_CopyFolder.Request();
        req.sourceBranch = 'master';
        req.folderPath = 'force-app/main/default/classes';
        req.destinationBranch = 'OnlyClasses';
        List<GitHubAction_CopyFolder.Response> res = GitHubAction_CopyFolder.run(
            new List<GitHubAction_CopyFolder.Request>{ req }
        );
        Test.stopTest();

        System.assertEquals(true, res[0].success);
        System.assert(res[0].message.contains('1 file(s)'), 'Only the folder blob should be copied');
        System.assert(
            res[0].message.contains('containing only that folder'),
            'New branch should be reported as folder-only'
        );
        Map<String, Object> details = (Map<String, Object>) JSON.deserializeUntyped(res[0].detailsJson);
        System.assertEquals(true, details.get('folderOnlyBranch'));
    }

    @isTest
    static void copyFolderRequiresFolderPath() {
        Test.startTest();
        GitHubCloudService.Result res = GitHubCloudService.copyFolder(
            null, null, null, 'master', null, 'Testing', null
        );
        Test.stopTest();
        System.assertEquals(false, res.success);
        System.assert(res.message.contains('folder path is required'));
    }

    @isTest
    static void copyFolderFailsWhenFolderHasNoFiles() {
        Test.setMock(
            HttpCalloutMock.class,
            new GitHubCloudMock().add(200, REF_BODY).add(200, '{"tree":[]}')
        );
        Test.startTest();
        GitHubCloudService.Result res = GitHubCloudService.copyFolder(
            null, null, null, 'master', 'does/not/exist', 'Testing', null
        );
        Test.stopTest();
        System.assertEquals(false, res.success);
        System.assert(res.message.contains('No files found'));
    }

    @isTest
    static void getFileReturnsDecodedContent() {
        String fileJson = '{"path":"notes.txt","sha":"filesha","content":"aGVsbG8gd29ybGQ=\\n"}';
        Test.setMock(HttpCalloutMock.class, new GitHubCloudMock().add(200, REF_BODY).add(200, fileJson));
        Test.startTest();
        GitHubAction_GetFile.Request req = new GitHubAction_GetFile.Request();
        req.branch = 'master';
        req.filePath = 'notes.txt';
        List<GitHubAction_GetFile.Response> res = GitHubAction_GetFile.run(
            new List<GitHubAction_GetFile.Request>{ req }
        );
        Test.stopTest();
        System.assertEquals(true, res[0].success);
        System.assertEquals('hello world', res[0].content);
    }

    @isTest
    static void updateExistingFileSendsSha() {
        String fileJson = '{"path":"notes.txt","sha":"filesha","content":"b2xk"}';
        String putJson = '{"content":{"html_url":"https://github.com/kartikchauhan563/SalesforceAgentForceDemo/blob/demo-1/notes.txt"}}';
        Test.setMock(
            HttpCalloutMock.class,
            new GitHubCloudMock().add(200, REF_BODY).add(200, fileJson).add(200, putJson)
        );
        Test.startTest();
        GitHubAction_UpsertFile.Request req = new GitHubAction_UpsertFile.Request();
        req.branch = 'demo-1';
        req.filePath = 'notes.txt';
        req.fileContent = 'brand new content';
        List<GitHubAction_UpsertFile.Response> res = GitHubAction_UpsertFile.run(
            new List<GitHubAction_UpsertFile.Request>{ req }
        );
        Test.stopTest();
        System.assertEquals(true, res[0].success);
        System.assert(res[0].message.contains('Updated'), 'Existing file should report an update');
    }

    @isTest
    static void createNewFileWhenMissing() {
        String putJson = '{"content":{"html_url":"https://github.com/kartikchauhan563/SalesforceAgentForceDemo/blob/demo-1/new.txt"}}';
        Test.setMock(
            HttpCalloutMock.class,
            new GitHubCloudMock()
                .add(200, REF_BODY)
                .add(404, '{"message":"Not Found"}')
                .add(201, putJson)
        );
        Test.startTest();
        GitHubCloudService.Result res = GitHubCloudService.upsertFile(
            null, null, null, 'demo-1', 'new.txt', 'first version', null
        );
        Test.stopTest();
        System.assertEquals(true, res.success);
        System.assert(res.message.contains('Created'), 'Missing file should report a create');
    }

    @isTest
    static void upsertFileRefusesMissingBranchInsteadOfFallingBack() {
        Test.setMock(HttpCalloutMock.class, new GitHubCloudMock().add(404, '{"message":"Not Found"}'));
        Test.startTest();
        GitHubCloudService.Result res = GitHubCloudService.upsertFile(
            null, null, null, 'no-such-branch', 'notes.txt', 'content', null
        );
        Test.stopTest();
        System.assertEquals(false, res.success, 'A write must not fall back to another branch');
        System.assert(res.message.contains('does not exist'));
        System.assert(res.message.contains('nothing was written'));
    }

    @isTest
    static void upsertFileValidatesInputs() {
        Test.startTest();
        GitHubCloudService.Result noPath = GitHubCloudService.upsertFile(
            null, null, null, 'demo-1', null, 'x', null
        );
        GitHubCloudService.Result noContent = GitHubCloudService.upsertFile(
            null, null, null, 'demo-1', 'notes.txt', null, null
        );
        Test.stopTest();
        System.assertEquals(false, noPath.success);
        System.assertEquals(false, noContent.success);
        System.assert(noContent.message.contains('content is required'));
    }

    @isTest
    static void analyzeDependenciesFindsForwardAndReverseReferences() {
        String tree = '{"tree":[' +
            '{"path":"force-app/main/default/flows/Update_Application_AI_Output_Flow.flow-meta.xml","type":"blob"},' +
            '{"path":"force-app/main/default/classes/AgentOrchestrator.cls","type":"blob"},' +
            '{"path":"force-app/main/default/flows/Other_Flow.flow-meta.xml","type":"blob"},' +
            '{"path":"force-app/main/default/objects/Loan_Application__c/Loan_Application__c.object-meta.xml","type":"blob"},' +
            '{"path":"force-app/main/default/triggers/LoanApplicationTrigger.trigger","type":"blob"}' +
            ']}';
        String targetFile =
            '{"path":"force-app/main/default/flows/Update_Application_AI_Output_Flow.flow-meta.xml",' +
            '"sha":"flowsha","content":' +
            '"QWdlbnRPcmNoZXN0cmF0b3IgT3RoZXJfRmxvdyBMb2FuX0FwcGxpY2F0aW9uX19j"}';
        String searchResults = '{"items":[' +
            '{"path":"force-app/main/default/triggers/LoanApplicationTrigger.trigger"},' +
            '{"path":"force-app/main/default/classes/AgentOrchestrator.cls"}' +
            ']}';
        Test.setMock(
            HttpCalloutMock.class,
            new GitHubCloudMock()
                .add(200, REF_BODY)
                .add(200, tree)
                .add(200, targetFile)
                .add(200, searchResults)
        );

        Test.startTest();
        GitHubAction_GetDependencies.Request req = new GitHubAction_GetDependencies.Request();
        req.branch = 'master';
        req.fileOrFeature = 'Update_Application_AI_Output_Flow';
        List<GitHubAction_GetDependencies.Response> responses =
            GitHubAction_GetDependencies.run(
                new List<GitHubAction_GetDependencies.Request>{ req }
            );
        Test.stopTest();

        System.assertEquals(true, responses[0].success);
        System.assert(responses[0].message.contains('AgentOrchestrator.cls'));
        System.assert(responses[0].message.contains('Other_Flow.flow-meta.xml'));
        System.assert(responses[0].message.contains('LoanApplicationTrigger.trigger'));
        Map<String, Object> details =
            (Map<String, Object>) JSON.deserializeUntyped(responses[0].detailsJson);
        System.assertEquals(
            3,
            ((List<Object>) details.get('dependsOn')).size(),
            'Flow content should map to class, flow, and object dependencies'
        );
        System.assertEquals(2, ((List<Object>) details.get('usedBy')).size());
    }

    @isTest
    static void analyzeDependenciesRequiresAFileOrFeature() {
        Test.startTest();
        GitHubCloudService.Result result =
            GitHubCloudService.analyzeDependencies(null, null, null, null, null);
        Test.stopTest();
        System.assertEquals(false, result.success);
        System.assert(result.message.contains('file path, metadata name, or feature name'));
    }

    @isTest
    static void emptyInvocableRequestStillRuns() {
        Test.setMock(
            HttpCalloutMock.class,
            new GitHubCloudMock().add(200, '[{"name":"master"}]')
        );
        Test.startTest();
        List<GitHubAction_ListBranches.Response> res = GitHubAction_ListBranches.run(null);
        Test.stopTest();
        System.assertEquals(true, res[0].success);
    }
}