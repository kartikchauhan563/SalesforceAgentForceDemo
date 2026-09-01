public without sharing class SfOrgDeployService {
    public class SubmitResult {
        public Boolean success;
        public Id requestId;
        public String referenceId;
        public String status;
        public String message;
    }

    public class ClaimResult {
        public String requestId;
        public String referenceId;
        public String repository;
        public String branch;
        public List<String> componentPaths;
        public String instanceUrl;
        public String accessToken;
        public Boolean isSandbox;
    }

    public class StatusPayload {
        public String requestId;
        public String workflowRunId;
        public String status;
        public String validationId;
        public String deploymentId;
        public String result;
        public String errorMessage;
    }

    private static final Set<String> CALLBACK_STATUSES = new Set<String>{
        'Validating', 'Deploying', 'Succeeded', 'Failed'
    };

    public static SubmitResult submit(
        String owner,
        String repo,
        String ownerRepo,
        String branch,
        String componentPaths,
        String connectionId,
        Boolean deploymentConfirmed,
        Boolean productionConfirmed
    ) {
        if (deploymentConfirmed != true) {
            return fail('Confirm the deployment before it is submitted.');
        }
        GitHubCloudConfig.RepoTarget target = GitHubCloudConfig.resolve(owner, repo, ownerRepo);
        if (!GitHubCloudConfig.isSafeGitHubName(target.owner) ||
            !GitHubCloudConfig.isSafeGitHubName(target.repo)) {
            return fail('Repository must be a safe owner/name GitHub identifier.');
        }
        if (!GitHubCloudConfig.isSafeBranchName(branch)) {
            return fail('A valid destination branch is required.');
        }
        List<String> paths;
        try {
            paths = normalizePaths(componentPaths);
        } catch (DeployException ex) {
            return fail(ex.getMessage());
        }
        List<Sf_Org_Connection__c> connections = [
            SELECT Connection_Key__c, Status__c, Is_Sandbox__c, Instance_Url__c
            FROM Sf_Org_Connection__c
            WHERE Connection_Key__c = :connectionId
            LIMIT 1
        ];
        if (connections.isEmpty() || connections[0].Status__c != 'Authorized') {
            return fail('Authorize the target Salesforce org before deploying.');
        }
        Boolean possibleProduction = connections[0].Is_Sandbox__c != true;
        if (possibleProduction && productionConfirmed != true) {
            return fail(
                'This target is production or its sandbox status is unknown. Explicitly confirm the production deployment.'
            );
        }

        Sf_Org_Deployment__c request = new Sf_Org_Deployment__c(
            Repository__c = target.owner + '/' + target.repo,
            Branch__c = branch.trim(),
            Component_Paths__c = JSON.serialize(paths),
            Connection_Key__c = connectionId.trim(),
            Status__c = 'Queued',
            Production_Confirmed__c = productionConfirmed == true,
            Requested_At__c = System.now()
        );
        insert request;
        request = [
            SELECT Id, Name, Status__c
            FROM Sf_Org_Deployment__c
            WHERE Id = :request.Id
        ];
        System.enqueueJob(new GitHubOAuthDeployQueueable(request.Id));

        SubmitResult out = new SubmitResult();
        out.success = true;
        out.requestId = request.Id;
        out.referenceId = request.Name;
        out.status = request.Status__c;
        out.message =
            'Deployment ' + request.Name + ' is queued for branch "' + branch.trim() +
            '" in ' + target.owner + '/' + target.repo + '. Ask for status using ' + request.Name + '.';
        return out;
    }

    public static ClaimResult claim(Id requestId) {
        List<Sf_Org_Deployment__c> rows = [
            SELECT Id, Name, Repository__c, Branch__c, Component_Paths__c, Connection_Key__c,
                Status__c, Session_Claimed_At__c, Production_Confirmed__c
            FROM Sf_Org_Deployment__c
            WHERE Id = :requestId
            LIMIT 1
            FOR UPDATE
        ];
        if (rows.isEmpty()) {
            throw new DeployException('Deployment request was not found.');
        }
        Sf_Org_Deployment__c request = rows[0];
        if (request.Session_Claimed_At__c != null) {
            throw new DeployException('The deployment session was already claimed.');
        }
        if (request.Status__c != 'Queued' && request.Status__c != 'Validating') {
            throw new DeployException('Deployment request is not claimable in status ' + request.Status__c + '.');
        }

        SfOrgConnectClient.Session session = SfOrgOAuthService.sessionFor(request.Connection_Key__c);
        List<Sf_Org_Connection__c> connections = [
            SELECT Is_Sandbox__c
            FROM Sf_Org_Connection__c
            WHERE Connection_Key__c = :request.Connection_Key__c
            LIMIT 1
        ];
        Boolean isSandbox = !connections.isEmpty() && connections[0].Is_Sandbox__c == true;
        if (!isSandbox && request.Production_Confirmed__c != true) {
            throw new DeployException('Production deployment was not explicitly confirmed.');
        }

        request.Session_Claimed_At__c = System.now();
        request.Status__c = 'Validating';
        update request;

        ClaimResult out = new ClaimResult();
        out.requestId = String.valueOf(request.Id);
        out.referenceId = request.Name;
        out.repository = request.Repository__c;
        out.branch = request.Branch__c;
        out.componentPaths = normalizePaths(request.Component_Paths__c);
        out.instanceUrl = session.instanceUrl;
        out.accessToken = session.sessionId;
        out.isSandbox = isSandbox;
        return out;
    }

    public static Sf_Org_Deployment__c applyStatus(StatusPayload payload) {
        if (payload == null || String.isBlank(payload.requestId)) {
            throw new DeployException('requestId is required.');
        }
        if (!CALLBACK_STATUSES.contains(payload.status)) {
            throw new DeployException('Unsupported deployment status.');
        }
        Sf_Org_Deployment__c request = [
            SELECT Id, Name, Status__c, Workflow_Run_Id__c, Validation_Id__c, Deployment_Id__c,
                Result__c, Error_Message__c, Completed_At__c
            FROM Sf_Org_Deployment__c
            WHERE Id = :payload.requestId
            LIMIT 1
        ];
        request.Status__c = payload.status;
        request.Workflow_Run_Id__c = clean(payload.workflowRunId, 80);
        request.Validation_Id__c = clean(payload.validationId, 80);
        request.Deployment_Id__c = clean(payload.deploymentId, 80);
        request.Result__c = clean(payload.result, 32768);
        request.Error_Message__c = clean(payload.errorMessage, 32768);
        if (payload.status == 'Succeeded' || payload.status == 'Failed') {
            request.Completed_At__c = System.now();
        }
        update request;
        return request;
    }

    public static SubmitResult status(String referenceId) {
        if (String.isBlank(referenceId)) {
            return fail('A deployment reference such as SFD-000001 is required.');
        }
        List<Sf_Org_Deployment__c> rows = [
            SELECT Id, Name, Repository__c, Branch__c, Component_Paths__c, Status__c,
                Validation_Id__c, Deployment_Id__c, Result__c, Error_Message__c
            FROM Sf_Org_Deployment__c
            WHERE Name = :referenceId.trim()
            LIMIT 1
        ];
        if (rows.isEmpty()) {
            return fail('No deployment was found for ' + referenceId.trim() + '.');
        }
        Sf_Org_Deployment__c request = rows[0];
        SubmitResult out = new SubmitResult();
        out.success = request.Status__c != 'Failed';
        out.requestId = request.Id;
        out.referenceId = request.Name;
        out.status = request.Status__c;
        out.message =
            request.Name + ' is ' + request.Status__c + ' for branch "' + request.Branch__c +
            '" in ' + request.Repository__c + '.' +
            (String.isBlank(request.Deployment_Id__c) ? '' : ' Deployment ID: ' + request.Deployment_Id__c + '.') +
            (String.isBlank(request.Error_Message__c) ? '' : ' Error: ' + request.Error_Message__c);
        return out;
    }

    @TestVisible
    private static List<String> normalizePaths(String raw) {
        if (String.isBlank(raw)) {
            throw new DeployException('At least one copied metadata path is required.');
        }
        List<String> values = new List<String>();
        String trimmed = raw.trim();
        if (trimmed.startsWith('[')) {
            for (Object item : (List<Object>) JSON.deserializeUntyped(trimmed)) {
                values.add(String.valueOf(item));
            }
        } else {
            values.addAll(trimmed.replace('\r', '\n').replace(',', '\n').split('\n'));
        }
        Set<String> unique = new Set<String>();
        List<String> safe = new List<String>();
        for (String value : values) {
            String path = value == null ? '' : value.trim().replace('\\', '/');
            while (path.startsWith('/')) {
                path = path.substring(1);
            }
            if (String.isBlank(path)) {
                continue;
            }
            if (!path.startsWith('force-app/') || path.contains('..') ||
                !Pattern.matches('^[A-Za-z0-9_./@-]+$', path)) {
                throw new DeployException('Unsafe or non-Salesforce metadata path: ' + path);
            }
            if (unique.add(path)) {
                safe.add(path);
            }
        }
        if (safe.isEmpty()) {
            throw new DeployException('At least one copied Salesforce metadata path is required.');
        }
        if (safe.size() > 100) {
            throw new DeployException('A deployment can contain at most 100 selected paths.');
        }
        return safe;
    }

    private static SubmitResult fail(String message) {
        SubmitResult out = new SubmitResult();
        out.success = false;
        out.message = message;
        out.status = 'Failed';
        return out;
    }

    private static String clean(String value, Integer maxLength) {
        if (String.isBlank(value)) {
            return null;
        }
        String sanitized = value.replaceAll('(?i)Bearer\\s+[A-Za-z0-9._-]+', 'Bearer [REDACTED]');
        return sanitized.length() > maxLength ? sanitized.substring(0, maxLength) : sanitized;
    }

    public class DeployException extends Exception {
    }
}
