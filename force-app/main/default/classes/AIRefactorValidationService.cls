public with sharing class AIRefactorValidationService {
    public static AIRefactorConfigService.Repo requireRepository(String repositoryInput) {
        String cleaned = AIRefactorSecurityService.sanitizeText(repositoryInput);
        if (String.isBlank(cleaned)) {
            AIRefactorConfigService.Config cfg = AIRefactorConfigService.loadConfig();
            cleaned = cfg.defaultRepository;
            if (String.isBlank(cleaned)) {
                List<AIRefactorConfigService.Repo> enabled = AIRefactorConfigService.enabledRepositories();
                if (enabled.size() == 1) {
                    return enabled[0];
                }
                throw new AIRefactorException('A configured repository is required.');
            }
        }
        if (cleaned.contains('://') || cleaned.contains('github.com')) {
            throw new AIRefactorException('Provide a configured repository name, not a GitHub URL.');
        }
        String lowered = cleaned.toLowerCase();
        for (AIRefactorConfigService.Repo repo : AIRefactorConfigService.enabledRepositories()) {
            if (matches(repo, lowered)) {
                return repo;
            }
        }
        throw new AIRefactorException(
            'Repository "' + cleaned + '" is not enabled. Choose one of the configured repositories.'
        );
    }

    public static String requireBranch(String branchInput, AIRefactorConfigService.Repo repo) {
        String cleaned = AIRefactorSecurityService.sanitizeText(branchInput);
        if (String.isBlank(cleaned)) {
            cleaned = repo.defaultBranch;
        }
        if (String.isBlank(cleaned)) {
            throw new AIRefactorException('A source branch is required.');
        }
        Pattern allowed = Pattern.compile('^[A-Za-z0-9._/-]+$');
        if (!allowed.matcher(cleaned).matches() || cleaned.contains('..') || cleaned.startsWith('/')) {
            throw new AIRefactorException('Source branch contains unsupported characters.');
        }
        return cleaned;
    }

    public static String requireTarget(String targetInput, AIRefactorConfigService.Repo repo, AIRefactorConfigService.Config cfg) {
        String cleaned = AIRefactorSecurityService.sanitizeText(targetInput);
        if (String.isBlank(cleaned)) {
            cleaned = 'DEV';
        }
        String target = cleaned.toUpperCase();
        if (!AIRefactorConstants.TARGETS.contains(target)) {
            throw new AIRefactorException('Target environment must be DEV, QA, UAT, or PROD.');
        }
        if (target == 'PROD' && cfg.productionDeploymentEnabled != true) {
            throw new AIRefactorException('Production deployment is not enabled for this organization.');
        }
        if (repo.allowedTargets != null && !repo.allowedTargets.isEmpty() && !repo.allowedTargets.contains(target)) {
            throw new AIRefactorException(
                'Target ' + target + ' is not allowed for repository ' + repo.displayName + '.'
            );
        }
        return target;
    }

    public static String requireComponentPath(String pathInput, AIRefactorConfigService.Config cfg) {
        String path = AIRefactorSecurityService.normalizePath(pathInput);
        if (String.isBlank(path) || 'AUTO'.equalsIgnoreCase(path)) {
            return 'AUTO';
        }
        if (AIRefactorSecurityService.isBlockedPath(path, cfg.blockedFilePaths)) {
            throw new AIRefactorException('Component path is blocked by security policy.');
        }
        if (!AIRefactorSecurityService.isAllowedComponentPath(path, cfg.allowedComponentPaths)) {
            throw new AIRefactorException(
                'Component path must be under an allowed Salesforce source directory.'
            );
        }
        return path;
    }

    public static String requireRequirement(String requirementInput, AIRefactorConfigService.Config cfg) {
        String requirement = AIRefactorSecurityService.sanitizeText(requirementInput);
        if (String.isBlank(requirement)) {
            throw new AIRefactorException('A refactoring requirement is required.');
        }
        if (requirement.length() > cfg.maximumRequestLength) {
            throw new AIRefactorException(
                'Requirement exceeds the maximum length of ' + cfg.maximumRequestLength + ' characters.'
            );
        }
        AIRefactorSecurityService.assertNoCredentials(requirement, 'Requirement');
        return requirement;
    }

    public static void enforceTransitions(
        Map<Id, AI_Refactor_Request__c> oldMap,
        List<AI_Refactor_Request__c> incoming
    ) {
        Map<String, Set<String>> allowed = AIRefactorConstants.allowedTransitions();
        for (AI_Refactor_Request__c record : incoming) {
            if (oldMap == null || !oldMap.containsKey(record.Id)) {
                if (record.Status__c != AIRefactorConstants.STATUS_DRAFT &&
                    record.Status__c != AIRefactorConstants.STATUS_SUBMITTED) {
                    record.addError('New requests must start in Draft or Submitted.');
                }
                continue;
            }
            String previous = oldMap.get(record.Id).Status__c;
            String nextStatus = record.Status__c;
            if (previous == nextStatus) {
                continue;
            }
            Set<String> nextAllowed = allowed.get(previous);
            if (nextAllowed == null || !nextAllowed.contains(nextStatus)) {
                record.addError('Status cannot change from ' + previous + ' to ' + nextStatus + '.');
            }
            if (previous == AIRefactorConstants.STATUS_COMPLETED &&
                nextStatus == AIRefactorConstants.STATUS_CANCELLED) {
                record.addError('Completed requests cannot be cancelled.');
            }
        }
    }

    public static Boolean canRetry(AI_Refactor_Request__c record) {
        return record != null &&
            (record.Status__c == AIRefactorConstants.STATUS_TRIGGER_FAILED ||
             record.Status__c == AIRefactorConstants.STATUS_CALLBACK_FAILED ||
             record.Status__c == AIRefactorConstants.STATUS_DEPLOY_FAILED);
    }

    public static Boolean canCancel(AI_Refactor_Request__c record) {
        if (record == null) {
            return false;
        }
        return record.Status__c != AIRefactorConstants.STATUS_COMPLETED &&
            record.Status__c != AIRefactorConstants.STATUS_CANCELLED &&
            record.Status__c != AIRefactorConstants.STATUS_DEPLOYING &&
            record.Status__c != AIRefactorConstants.STATUS_RUNNING_TESTS;
    }

    private static Boolean matches(AIRefactorConfigService.Repo repo, String lowered) {
        return lowered == safeLower(repo.displayName) ||
            lowered == safeLower(repo.repositoryName) ||
            lowered == safeLower(repo.ownerRepo);
    }

    private static String safeLower(String value) {
        return value == null ? '' : value.toLowerCase();
    }
}
