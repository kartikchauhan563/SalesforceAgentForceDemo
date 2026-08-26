GitHubAction_CopyAndApplyRepo.Request req = new GitHubAction_CopyAndApplyRepo.Request();
req.sourceRepoUrl = 'https://github.com/AnandPWC/Agent-Orglicense.git';
req.newBranch = 'agent-orglicense-one-pipeline-0826-1955';
req.requirement = 'Rename Org License Service Agent to Salesforce Best Agent and extend it to fetch Account, Opportunity, and Contact information together with org license information. Determine the files yourself.';
req.targetEnvironment = 'DEV';
req.componentPath = 'AUTO';

List<GitHubAction_CopyAndApplyRepo.Response> responses =
    GitHubAction_CopyAndApplyRepo.run(new List<GitHubAction_CopyAndApplyRepo.Request>{ req });

System.debug('E2E_SUCCESS=' + responses[0].success);
System.debug('E2E_REFERENCE=' + responses[0].referenceId);
System.debug('E2E_REQUEST=' + responses[0].requestId);
System.debug('E2E_MESSAGE=' + responses[0].message);
