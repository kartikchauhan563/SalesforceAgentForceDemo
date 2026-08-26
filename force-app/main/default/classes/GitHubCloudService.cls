public with sharing class GitHubCloudService {
    private static final Integer MAX_CONTENT_CHARS = 20000;
    private static final String COPY_EXTERNAL_WORKFLOW = 'copy-external-repo.yml';

    public class Result {
        public Boolean success;
        public String message;
        public String detailsJson;
        public String content;
        public String branchZipUrl;
        public String requestId;
        public String referenceId;
    }

    public static String branchZipDownloadUrl(String ownerRepo, String branch) {
        if (String.isBlank(ownerRepo) || String.isBlank(branch) || !ownerRepo.contains('/')) {
            return null;
        }
        List<String> parts = ownerRepo.split('/');
        if (parts.size() < 2 || String.isBlank(parts[0]) || String.isBlank(parts[1])) {
            return null;
        }
        return branchZipDownloadUrl(parts[0], parts[1], branch);
    }

    public static String branchZipDownloadUrl(String owner, String repo, String branch) {
        if (String.isBlank(owner) || String.isBlank(repo) || String.isBlank(branch)) {
            return null;
        }
        return 'https://github.com/' + owner.trim() + '/' + repo.trim() +
            '/archive/refs/heads/' + encodeBranch(branch.trim()) + '.zip';
    }

    // Markdown so conversation channels render a clickable link instead of bare text.
    public static String zipMarkdownLink(String branch, String zipUrl) {
        if (String.isBlank(zipUrl)) {
            return '';
        }
        String label = String.isBlank(branch) ? 'Download branch as ZIP' : 'Download ' + branch + ' as ZIP';
        return '[' + label + '](' + zipUrl + ')';
    }

    public static Result getFile(String owner, String repo, String ownerRepo, String branch, String filePath) {
        GitHubCloudConfig.RepoTarget target = GitHubCloudConfig.resolve(owner, repo, ownerRepo);
        String path = normalizeFolder(filePath);
        if (String.isBlank(path)) {
            return fail('A file path is required, for example force-app/main/default/classes/EMICalculator.cls.');
        }
        try {
            ResolvedSource source = resolveSource(target, GitHubCloudConfig.firstNonBlank(branch, target.baseBranch));
            Map<String, Object> file = getFileMetadata(target, path, source.branch);
            if (file == null) {
                return fail('File "' + path + '" was not found on branch "' + source.branch + '".');
            }
            String decoded = decodeContent(file);
            if (decoded == null) {
                return fail(
                    'File "' + path + '" on branch "' + source.branch +
                    '" could not be read as text. It may be binary or too large.'
                );
            }
            Boolean truncated = decoded.length() > MAX_CONTENT_CHARS;
            String shown = truncated ? decoded.substring(0, MAX_CONTENT_CHARS) : decoded;
            Result result = ok(
                source.note + 'File "' + path + '" on branch "' + source.branch + '" in ' +
                target.owner + '/' + target.repo + ' has ' + decoded.length() + ' characters.' +
                (truncated ? ' Showing the first ' + MAX_CONTENT_CHARS + ' characters.' : ''),
                new Map<String, Object>{
                    'owner' => target.owner,
                    'repo' => target.repo,
                    'branch' => source.branch,
                    'path' => path,
                    'sha' => String.valueOf(file.get('sha')),
                    'truncated' => truncated,
                    'content' => shown
                }
            );
            result.content = shown;
            return result;
        } catch (GitHubCloudClient.CalloutException ex) {
            return fail(ex.getMessage());
        }
    }

    // Creates the file when it is missing and updates it when it already exists.
    public static Result upsertFile(
        String owner,
        String repo,
        String ownerRepo,
        String branch,
        String filePath,
        String fileContent,
        String commitMessage
    ) {
        GitHubCloudConfig.RepoTarget target = GitHubCloudConfig.resolve(owner, repo, ownerRepo);
        String path = normalizeFolder(filePath);
        if (String.isBlank(path)) {
            return fail('A file path is required, for example force-app/main/default/classes/EMICalculator.cls.');
        }
        if (fileContent == null) {
            return fail('File content is required. Provide the full text the file should contain.');
        }
        String targetBranch = GitHubCloudConfig.firstNonBlank(branch, target.baseBranch);
        try {
            // A write must never be redirected to another branch, so the branch has to exist as named.
            try {
                getBranchSha(target, targetBranch);
            } catch (GitHubCloudClient.CalloutException ex) {
                if (!isNotFound(ex)) {
                    throw ex;
                }
                return fail(
                    'Branch "' + targetBranch + '" does not exist in ' + target.owner + '/' + target.repo +
                    ', so nothing was written. Create the branch first, then retry the file change.'
                );
            }

            Map<String, Object> existing = getFileMetadata(target, path, targetBranch);

            Map<String, Object> payload = new Map<String, Object>{
                'message' => GitHubCloudConfig.firstNonBlank(
                    commitMessage,
                    (existing == null ? 'Create ' : 'Update ') + path + ' via Agentforce'
                ),
                'content' => EncodingUtil.base64Encode(Blob.valueOf(fileContent)),
                'branch' => targetBranch
            };
            if (existing != null) {
                payload.put('sha', String.valueOf(existing.get('sha')));
            }

            GitHubCloudClient.Response res = GitHubCloudClient.put(
                target.namedCredential,
                '/repos/' + target.owner + '/' + target.repo + '/contents/' + path,
                JSON.serialize(payload)
            );
            Map<String, Object> body = (Map<String, Object>) JSON.deserializeUntyped(res.body);
            Map<String, Object> contentNode = body == null ? null : (Map<String, Object>) body.get('content');
            String htmlUrl = contentNode == null ? null : String.valueOf(contentNode.get('html_url'));

            String zipUrl = branchZipDownloadUrl(target.owner, target.repo, targetBranch);
            Result written = ok(
                (existing == null ? 'Created' : 'Updated') + ' file "' + path + '" on branch "' +
                targetBranch + '" in ' + target.owner + '/' + target.repo + '. ' +
                (htmlUrl == null ? '' : htmlUrl) + ' ' + zipMarkdownLink(targetBranch, zipUrl),
                new Map<String, Object>{
                    'owner' => target.owner,
                    'repo' => target.repo,
                    'branch' => targetBranch,
                    'path' => path,
                    'created' => existing == null,
                    'htmlUrl' => htmlUrl,
                    'zipUrl' => zipUrl
                }
            );
            written.branchZipUrl = zipUrl;
            return written;
        } catch (GitHubCloudClient.CalloutException ex) {
            return fail(ex.getMessage());
        }
    }

    // Single synchronous call so a conversation can return a branch and a download link in one turn.
    public static Result createComponentInBranch(
        String owner,
        String repo,
        String ownerRepo,
        String sourceBranch,
        String newBranch,
        String filePath,
        String fileContent,
        String commitMessage
    ) {
        GitHubCloudConfig.RepoTarget target = GitHubCloudConfig.resolve(owner, repo, ownerRepo);
        String toBranch = GitHubCloudConfig.firstNonBlank(newBranch, null);
        String path = normalizeFolder(filePath);
        if (String.isBlank(toBranch)) {
            return fail('A new branch name is required, for example opportunity-flow.');
        }
        if (String.isBlank(path)) {
            return fail(
                'A file path is required, for example ' +
                'force-app/main/default/flows/Fetch_All_Opportunities.flow-meta.xml.'
            );
        }
        if (String.isBlank(fileContent)) {
            return fail('File content is required. Provide the complete metadata or code the file should contain.');
        }
        String fromBranch = GitHubCloudConfig.firstNonBlank(sourceBranch, target.baseBranch);
        try {
            Boolean branchCreated = false;
            String resolvedNote = '';
            try {
                getBranchSha(target, toBranch);
            } catch (GitHubCloudClient.CalloutException ex) {
                if (!isNotFound(ex)) {
                    throw ex;
                }
                ResolvedSource source = resolveSource(target, fromBranch);
                createRef(target, toBranch, source.sha);
                branchCreated = true;
                resolvedNote = source.note;
            }

            Result written = upsertFile(
                target.owner,
                target.repo,
                null,
                toBranch,
                path,
                fileContent,
                GitHubCloudConfig.firstNonBlank(commitMessage, 'Add ' + path + ' via Agentforce')
            );
            if (written.success != true) {
                return written;
            }

            String zipUrl = branchZipDownloadUrl(target.owner, target.repo, toBranch);
            Result result = ok(
                resolvedNote +
                (branchCreated
                    ? 'Created branch "' + toBranch + '" from "' + fromBranch + '"'
                    : 'Used existing branch "' + toBranch + '"') +
                ' in ' + target.owner + '/' + target.repo + ' and committed "' + path + '". Browse: ' +
                branchUrl(target, toBranch) + '. ' + zipMarkdownLink(toBranch, zipUrl),
                new Map<String, Object>{
                    'owner' => target.owner,
                    'repo' => target.repo,
                    'branch' => toBranch,
                    'sourceBranch' => fromBranch,
                    'branchCreated' => branchCreated,
                    'path' => path,
                    'htmlUrl' => branchUrl(target, toBranch),
                    'zipUrl' => zipUrl
                }
            );
            result.branchZipUrl = zipUrl;
            return result;
        } catch (GitHubCloudClient.CalloutException ex) {
            return fail(ex.getMessage());
        }
    }

    private static Map<String, Object> getFileMetadata(
        GitHubCloudConfig.RepoTarget target,
        String path,
        String branch
    ) {
        try {
            GitHubCloudClient.Response res = GitHubCloudClient.get(
                target.namedCredential,
                '/repos/' + target.owner + '/' + target.repo + '/contents/' + path +
                '?ref=' + encodeBranch(branch)
            );
            Object parsed = JSON.deserializeUntyped(res.body);
            if (parsed instanceof Map<String, Object>) {
                return (Map<String, Object>) parsed;
            }
            // A list means the path is a directory, not a file.
            throw new GitHubCloudClient.CalloutException(
                'Path "' + path + '" is a folder, not a file. Provide a full file path.'
            );
        } catch (GitHubCloudClient.CalloutException ex) {
            if (isNotFound(ex)) {
                return null;
            }
            throw ex;
        }
    }

    private static String decodeContent(Map<String, Object> file) {
        Object encoded = file.get('content');
        if (encoded == null) {
            return null;
        }
        try {
            String cleaned = String.valueOf(encoded).replace('\n', '').replace('\r', '');
            return EncodingUtil.base64Decode(cleaned).toString();
        } catch (Exception ignore) {
            return null;
        }
    }

    public static Result analyzeDependencies(
        String owner,
        String repo,
        String ownerRepo,
        String branch,
        String fileOrFeature
    ) {
        GitHubCloudConfig.RepoTarget target = GitHubCloudConfig.resolve(owner, repo, ownerRepo);
        String query = String.isBlank(fileOrFeature) ? null : fileOrFeature.trim();
        if (String.isBlank(query)) {
            return fail(
                'A file path, metadata name, or feature name is required, for example ' +
                '"Update_Application_AI_Output_Flow" or "force-app/main/default/classes/AgentOrchestrator.cls".'
            );
        }

        try {
            ResolvedSource source = resolveSource(
                target,
                GitHubCloudConfig.firstNonBlank(branch, target.baseBranch)
            );
            List<String> repositoryPaths = getRepositoryFilePaths(target, source.sha);
            String componentName = dependencySearchTerm(query);
            List<String> targetFiles = findTargetFiles(repositoryPaths, query, componentName);
            List<Object> dependsOn = new List<Object>();
            List<Object> usedBy = new List<Object>();
            Set<String> dependsOnPaths = new Set<String>();
            Set<String> usedByPaths = new Set<String>();

            for (String targetPath : targetFiles) {
                if (dependsOn.size() >= 100) {
                    break;
                }
                Map<String, Object> file = getFileMetadata(target, targetPath, source.branch);
                String content = file == null ? null : decodeContent(file);
                if (String.isBlank(content)) {
                    continue;
                }
                addForwardDependencies(
                    repositoryPaths,
                    targetFiles,
                    content,
                    dependsOn,
                    dependsOnPaths
                );
            }

            String reverseSearchWarning;
            try {
                addReverseDependencies(
                    target,
                    componentName,
                    targetFiles,
                    usedBy,
                    usedByPaths
                );
            } catch (GitHubCloudClient.CalloutException searchError) {
                reverseSearchWarning =
                    'Reverse-reference search was unavailable: ' + searchError.getMessage();
            }

            Map<String, Integer> countsByType = new Map<String, Integer>();
            countDependencyTypes(dependsOn, countsByType);
            countDependencyTypes(usedBy, countsByType);
            Integer total = dependsOn.size() + usedBy.size();
            List<String> summaryLines = dependencySummaryLines(dependsOn, usedBy, 30);

            String message =
                source.note + 'Dependency analysis for "' + query + '" on branch "' + source.branch +
                '" found ' + dependsOn.size() + ' referenced component(s) and ' + usedBy.size() +
                ' reverse reference(s). Reverse references come from GitHub code search on the repository\'s ' +
                'indexed default branch.';
            if (targetFiles.isEmpty()) {
                message +=
                    ' No exact source file matched, so reverse references were searched using "' +
                    componentName + '".';
            } else {
                message += ' Matched target file(s): ' + String.join(targetFiles, ', ') + '.';
            }
            if (!summaryLines.isEmpty()) {
                message += '\n' + String.join(summaryLines, '\n');
            }
            if (total > summaryLines.size()) {
                message += '\nFull structured results are available in Details JSON.';
            }
            if (String.isNotBlank(reverseSearchWarning)) {
                message += '\n' + reverseSearchWarning;
            }

            return ok(
                message,
                new Map<String, Object>{
                    'owner' => target.owner,
                    'repo' => target.repo,
                    'branch' => source.branch,
                    'query' => query,
                    'searchTerm' => componentName,
                    'targetFiles' => targetFiles,
                    'dependsOn' => dependsOn,
                    'usedBy' => usedBy,
                    'countsByType' => countsByType,
                    'reverseSearchWarning' => reverseSearchWarning,
                    'method' =>
                        'Forward dependencies are inferred from references in matched file content. ' +
                        'Reverse references use GitHub code search on the indexed default branch.'
                }
            );
        } catch (GitHubCloudClient.CalloutException ex) {
            return fail(ex.getMessage());
        }
    }

    private static List<String> getRepositoryFilePaths(
        GitHubCloudConfig.RepoTarget target,
        String treeSha
    ) {
        GitHubCloudClient.Response res = GitHubCloudClient.get(
            target.namedCredential,
            '/repos/' + target.owner + '/' + target.repo + '/git/trees/' + treeSha + '?recursive=1'
        );
        Map<String, Object> tree = (Map<String, Object>) JSON.deserializeUntyped(res.body);
        List<Object> entries = (List<Object>) tree.get('tree');
        List<String> paths = new List<String>();
        if (entries == null) {
            return paths;
        }
        for (Object entry : entries) {
            Map<String, Object> item = (Map<String, Object>) entry;
            if ('blob'.equals(item.get('type'))) {
                paths.add(String.valueOf(item.get('path')));
            }
        }
        return paths;
    }

    private static List<String> findTargetFiles(
        List<String> repositoryPaths,
        String query,
        String componentName
    ) {
        List<String> exact = new List<String>();
        List<String> partial = new List<String>();
        String normalizedQuery = normalizeDependencyName(query);
        String normalizedComponent = normalizeDependencyName(componentName);
        for (String path : repositoryPaths) {
            String normalizedPath = normalizeDependencyName(path);
            String normalizedPathComponent = normalizeDependencyName(componentNameFromPath(path));
            if (
                normalizedPath == normalizedQuery ||
                normalizedPathComponent == normalizedQuery ||
                normalizedPathComponent == normalizedComponent
            ) {
                exact.add(path);
            } else if (
                normalizedPath.contains(normalizedQuery) ||
                normalizedPathComponent.contains(normalizedComponent)
            ) {
                partial.add(path);
            }
        }
        exact.addAll(partial);
        while (exact.size() > 10) {
            exact.remove(exact.size() - 1);
        }
        return exact;
    }

    private static void addForwardDependencies(
        List<String> repositoryPaths,
        List<String> targetFiles,
        String targetContent,
        List<Object> dependencies,
        Set<String> seenPaths
    ) {
        Set<String> contentTokens =
            new Set<String>(targetContent.split('[^A-Za-z0-9_]+'));
        for (String candidatePath : repositoryPaths) {
            if (dependencies.size() >= 100 || targetFiles.contains(candidatePath)) {
                continue;
            }
            String candidateName = componentNameFromPath(candidatePath);
            if (
                candidateName.length() < 3 ||
                !isDependencyMetadata(candidatePath) ||
                !contentTokens.contains(candidateName) ||
                seenPaths.contains(candidatePath)
            ) {
                continue;
            }
            seenPaths.add(candidatePath);
            dependencies.add(dependencyEntry(candidatePath, candidateName, 'dependsOn'));
        }
    }

    private static void addReverseDependencies(
        GitHubCloudConfig.RepoTarget target,
        String componentName,
        List<String> targetFiles,
        List<Object> dependencies,
        Set<String> seenPaths
    ) {
        if (String.isBlank(componentName)) {
            return;
        }
        String searchQuery =
            '"' + componentName.replace('"', '') + '" repo:' + target.owner + '/' + target.repo;
        GitHubCloudClient.Response res = GitHubCloudClient.get(
            target.namedCredential,
            '/search/code?q=' + encodeQuery(searchQuery) + '&per_page=100'
        );
        Map<String, Object> searchResult = (Map<String, Object>) JSON.deserializeUntyped(res.body);
        List<Object> items = (List<Object>) searchResult.get('items');
        if (items == null) {
            return;
        }
        for (Object itemObject : items) {
            if (dependencies.size() >= 100) {
                break;
            }
            Map<String, Object> item = (Map<String, Object>) itemObject;
            String path = String.valueOf(item.get('path'));
            if (targetFiles.contains(path) || seenPaths.contains(path)) {
                continue;
            }
            seenPaths.add(path);
            dependencies.add(dependencyEntry(path, componentNameFromPath(path), 'usedBy'));
        }
    }

    private static Map<String, Object> dependencyEntry(
        String path,
        String componentName,
        String direction
    ) {
        return new Map<String, Object>{
            'name' => componentName,
            'type' => metadataTypeFromPath(path),
            'path' => path,
            'direction' => direction
        };
    }

    private static void countDependencyTypes(
        List<Object> dependencies,
        Map<String, Integer> countsByType
    ) {
        for (Object dependencyObject : dependencies) {
            Map<String, Object> dependency = (Map<String, Object>) dependencyObject;
            String metadataType = String.valueOf(dependency.get('type'));
            Integer existing = countsByType.containsKey(metadataType)
                ? countsByType.get(metadataType)
                : 0;
            countsByType.put(metadataType, existing + 1);
        }
    }

    private static List<String> dependencySummaryLines(
        List<Object> dependsOn,
        List<Object> usedBy,
        Integer limitSize
    ) {
        List<String> lines = new List<String>();
        appendDependencyLines(lines, dependsOn, 'Depends on', limitSize);
        appendDependencyLines(lines, usedBy, 'Used by', limitSize);
        return lines;
    }

    private static void appendDependencyLines(
        List<String> lines,
        List<Object> dependencies,
        String prefix,
        Integer limitSize
    ) {
        for (Object dependencyObject : dependencies) {
            if (lines.size() >= limitSize) {
                return;
            }
            Map<String, Object> dependency = (Map<String, Object>) dependencyObject;
            lines.add(
                '- ' + prefix + ' [' + String.valueOf(dependency.get('type')) + ']: ' +
                String.valueOf(dependency.get('path'))
            );
        }
    }

    private static Boolean isDependencyMetadata(String path) {
        String lower = path.toLowerCase();
        if (lower.endsWith('.cls-meta.xml') || lower.endsWith('.trigger-meta.xml')) {
            return false;
        }
        return lower.contains('/classes/') ||
            lower.contains('/flows/') ||
            lower.contains('/triggers/') ||
            lower.contains('/objects/') ||
            lower.contains('/lwc/') ||
            lower.contains('/aura/') ||
            lower.contains('/permissionsets/') ||
            lower.contains('/custommetadata/') ||
            lower.contains('/labels/');
    }

    private static String metadataTypeFromPath(String path) {
        String lower = path.toLowerCase();
        if (lower.contains('/classes/')) {
            return lower.endsWith('.cls-meta.xml') ? 'Apex Class Metadata' : 'Apex Class';
        }
        if (lower.contains('/triggers/')) {
            return lower.endsWith('.trigger-meta.xml') ? 'Apex Trigger Metadata' : 'Apex Trigger';
        }
        if (lower.contains('/flows/')) {
            return 'Flow';
        }
        if (lower.contains('/objects/')) {
            return lower.contains('/fields/') ? 'Custom Field' : 'Custom Object';
        }
        if (lower.contains('/lwc/')) {
            return 'Lightning Web Component';
        }
        if (lower.contains('/aura/')) {
            return 'Aura Component';
        }
        if (lower.contains('/permissionsets/')) {
            return 'Permission Set';
        }
        if (lower.contains('/custommetadata/')) {
            return 'Custom Metadata Record';
        }
        return 'Other Metadata';
    }

    private static String dependencySearchTerm(String query) {
        String cleaned = query.replace('\\', '/');
        Integer slashIndex = cleaned.lastIndexOf('/');
        if (slashIndex >= 0) {
            cleaned = cleaned.substring(slashIndex + 1);
        }
        List<String> suffixes = new List<String>{
            '.flow-meta.xml',
            '.trigger-meta.xml',
            '.cls-meta.xml',
            '.object-meta.xml',
            '.field-meta.xml',
            '.permissionset-meta.xml',
            '.js-meta.xml',
            '.md-meta.xml',
            '.trigger',
            '.cls',
            '.xml',
            '.js',
            '.html',
            '.css'
        };
        String lower = cleaned.toLowerCase();
        for (String suffix : suffixes) {
            if (lower.endsWith(suffix)) {
                return cleaned.substring(0, cleaned.length() - suffix.length());
            }
        }
        return cleaned;
    }

    private static String componentNameFromPath(String path) {
        return dependencySearchTerm(path);
    }

    private static String normalizeDependencyName(String value) {
        if (String.isBlank(value)) {
            return '';
        }
        return value.toLowerCase().replaceAll('[^a-z0-9]', '');
    }

    private static String encodeQuery(String value) {
        return EncodingUtil.urlEncode(value, 'UTF-8').replace('+', '%20');
    }

    public static Result createBranch(String owner, String repo, String ownerRepo, String newBranch, String sourceBranch) {
        GitHubCloudConfig.RepoTarget target = GitHubCloudConfig.resolve(owner, repo, ownerRepo);
        String fromBranch = GitHubCloudConfig.firstNonBlank(sourceBranch, target.baseBranch);
        String toBranch = GitHubCloudConfig.firstNonBlank(newBranch, null);
        if (String.isBlank(toBranch)) {
            return fail('A new branch name is required.');
        }
        try {
            ResolvedSource source = resolveSource(target, fromBranch);
            Map<String, Object> created = createRef(target, toBranch, source.sha);
            String zipUrl = branchZipDownloadUrl(target.owner, target.repo, toBranch);
            Result createdResult = ok(
                source.note + 'Created branch "' + toBranch + '" in ' + target.owner + '/' + target.repo +
                ' from "' + source.branch + '". Browse: ' + branchUrl(target, toBranch) +
                '. ' + zipMarkdownLink(toBranch, zipUrl),
                new Map<String, Object>{
                    'owner' => target.owner,
                    'repo' => target.repo,
                    'branch' => toBranch,
                    'sourceBranch' => source.branch,
                    'requestedSourceBranch' => fromBranch,
                    'sha' => source.sha,
                    'htmlUrl' => branchUrl(target, toBranch),
                    'zipUrl' => zipUrl,
                    'githubRef' => created
                }
            );
            createdResult.branchZipUrl = zipUrl;
            return createdResult;
        } catch (GitHubCloudClient.CalloutException ex) {
            return fail(ex.getMessage());
        }
    }

    // Copies every file from an external GitHub URL into our repository as a new branch.
    // Copy-only cross-repo work dispatches copy-external-repo.yml.
    // Copy plus a natural-language change dispatches copy-and-apply.yml after creating an AIR request.
    public static Result copyExternalRepository(
        String sourceRepoUrl,
        String sourceBranch,
        String newBranch,
        String destOwner,
        String destRepo,
        String destOwnerRepo
    ) {
        return copyExternalRepository(
            sourceRepoUrl,
            sourceBranch,
            newBranch,
            destOwner,
            destRepo,
            destOwnerRepo,
            null,
            null,
            null
        );
    }

    public static Result copyExternalRepository(
        String sourceRepoUrl,
        String sourceBranch,
        String newBranch,
        String destOwner,
        String destRepo,
        String destOwnerRepo,
        String requirement,
        String targetEnvironment,
        String componentPath
    ) {
        GitHubCloudConfig.ParsedGitHubUrl source = GitHubCloudConfig.parseGitHubUrl(sourceRepoUrl);
        if (String.isBlank(source.owner) || String.isBlank(source.repo) || String.isBlank(source.canonicalUrl)) {
            return fail('Give me a GitHub repository URL such as https://github.com/owner/repo.');
        }
        if (!GitHubCloudConfig.isSafeGitHubName(source.owner) || !GitHubCloudConfig.isSafeGitHubName(source.repo)) {
            return fail('The GitHub URL must use a normal owner and repository name. Extra path characters are not allowed.');
        }

        String toBranch = GitHubCloudConfig.firstNonBlank(newBranch, null);
        if (String.isBlank(toBranch)) {
            return fail('Give me the new branch name that should receive the copied code in our repository.');
        }
        if (!GitHubCloudConfig.isSafeBranchName(toBranch)) {
            return fail('The new branch name can contain letters, numbers, hyphen, underscore, dot, and slash only.');
        }

        String fromBranch = GitHubCloudConfig.firstNonBlank(sourceBranch, source.branch);
        if (String.isNotBlank(fromBranch) && !GitHubCloudConfig.isSafeBranchName(fromBranch)) {
            return fail('The source branch name can contain letters, numbers, hyphen, underscore, dot, and slash only.');
        }

        GitHubCloudConfig.RepoTarget dest = GitHubCloudConfig.resolve(destOwner, destRepo, destOwnerRepo);
        String changeRequest = GitHubCloudConfig.firstNonBlank(requirement, null);
        if (String.isNotBlank(changeRequest)) {
            return queueCopyAndApply(
                source,
                fromBranch,
                dest,
                toBranch,
                changeRequest,
                targetEnvironment,
                componentPath
            );
        }
        if (source.owner == dest.owner && source.repo == dest.repo) {
            return copyBranchAssets(dest.owner, dest.repo, dest.owner + '/' + dest.repo, fromBranch, toBranch);
        }

        try {
            String workflowRef = dest.baseBranch;
            try {
                workflowRef = getDefaultBranch(dest);
            } catch (GitHubCloudClient.CalloutException ignoreDefault) {
                workflowRef = dest.baseBranch;
            }

            Map<String, Object> inputs = new Map<String, Object>{
                'sourceRepoUrl' => source.canonicalUrl,
                'sourceBranch' => String.isBlank(fromBranch) ? '' : fromBranch,
                'destBranch' => toBranch
            };
            GitHubCloudClient.post(
                dest.namedCredential,
                '/repos/' + dest.owner + '/' + dest.repo + '/actions/workflows/' + COPY_EXTERNAL_WORKFLOW + '/dispatches',
                JSON.serialize(new Map<String, Object>{ 'ref' => workflowRef, 'inputs' => inputs })
            );

            String zipUrl = branchZipDownloadUrl(dest.owner, dest.repo, toBranch);
            Result queued = ok(
                'Started a full copy of ' + source.canonicalUrl +
                (String.isBlank(fromBranch) ? '' : ' (branch "' + fromBranch + '")') +
                ' into new branch "' + toBranch + '" in ' + dest.owner + '/' + dest.repo +
                '. GitHub Actions copies every file; this usually finishes within a couple of minutes. ' +
                'Ask me to confirm the copy, then tell me if you want to update anything on that branch. Browse: ' +
                branchUrl(dest, toBranch) + '. ' + zipMarkdownLink(toBranch, zipUrl),
                new Map<String, Object>{
                    'sourceUrl' => source.canonicalUrl,
                    'sourceOwner' => source.owner,
                    'sourceRepo' => source.repo,
                    'sourceBranch' => fromBranch,
                    'owner' => dest.owner,
                    'repo' => dest.repo,
                    'newBranch' => toBranch,
                    'workflow' => COPY_EXTERNAL_WORKFLOW,
                    'htmlUrl' => branchUrl(dest, toBranch),
                    'zipUrl' => zipUrl
                }
            );
            queued.branchZipUrl = zipUrl;
            return queued;
        } catch (GitHubCloudClient.CalloutException ex) {
            String extra = '';
            if (ex.getMessage() != null && ex.getMessage().contains('(404)')) {
                extra = ' Confirm that ' + COPY_EXTERNAL_WORKFLOW +
                    ' exists on the default branch of ' + dest.owner + '/' + dest.repo +
                    ' and that the GitHub token can dispatch workflows.';
            }
            return fail(ex.getMessage() + extra);
        }
    }

    public static Result confirmCopiedBranch(String owner, String repo, String ownerRepo, String branch) {
        String toBranch = GitHubCloudConfig.firstNonBlank(branch, null);
        if (String.isBlank(toBranch)) {
            return fail('Give me the branch name to confirm.');
        }
        Result listed = listFiles(owner, repo, ownerRepo, toBranch);
        if (!listed.success) {
            return fail(
                'Branch "' + toBranch + '" is not ready yet. The full-repository copy may still be running. ' +
                listed.message
            );
        }
        listed.message = 'Copy confirmed on branch "' + toBranch + '". ' + listed.message +
            ' If a copy-and-apply request is already running, wait for that AIR reference. ' +
            'Otherwise tell me the change you want on this branch.';
        return listed;
    }

    private static Result queueCopyAndApply(
        GitHubCloudConfig.ParsedGitHubUrl source,
        String fromBranch,
        GitHubCloudConfig.RepoTarget dest,
        String toBranch,
        String requirement,
        String targetEnvironment,
        String componentPath
    ) {
        try {
            AIRefactorRequestService.SubmitCommand command = new AIRefactorRequestService.SubmitCommand();
            command.repository = dest.owner + '/' + dest.repo;
            command.sourceBranch = toBranch;
            command.componentPath = componentPath;
            command.requirement = requirement;
            command.targetEnvironment = targetEnvironment;
            AIRefactorRequestService.SubmitResult submitted = AIRefactorRequestService.submit(command, false);

            Boolean sameRepo = source.owner == dest.owner && source.repo == dest.repo;
            System.enqueueJob(
                new GitHubCopyAndApplyQueueable(
                    submitted.requestId,
                    source.canonicalUrl,
                    fromBranch,
                    sameRepo
                )
            );

            String zipUrl = branchZipDownloadUrl(dest.owner, dest.repo, toBranch);
            Result queued = ok(
                'Started one pipeline to copy ' + source.canonicalUrl +
                (String.isBlank(fromBranch) ? '' : ' (branch "' + fromBranch + '")') +
                ' into "' + toBranch + '" in ' + dest.owner + '/' + dest.repo +
                ', then apply your requested changes on that same branch with AI. ' +
                'Reference: ' + submitted.referenceId + '. Target: ' + submitted.targetEnvironment +
                '. Browse: ' + branchUrl(dest, toBranch) + '. ' + zipMarkdownLink(toBranch, zipUrl),
                new Map<String, Object>{
                    'sourceUrl' => source.canonicalUrl,
                    'sourceOwner' => source.owner,
                    'sourceRepo' => source.repo,
                    'sourceBranch' => fromBranch,
                    'owner' => dest.owner,
                    'repo' => dest.repo,
                    'newBranch' => toBranch,
                    'workflow' => AIRefactorConstants.WORKFLOW_COPY_AND_APPLY,
                    'requestId' => submitted.requestId,
                    'referenceId' => submitted.referenceId,
                    'htmlUrl' => branchUrl(dest, toBranch),
                    'zipUrl' => zipUrl
                }
            );
            queued.branchZipUrl = zipUrl;
            queued.requestId = String.valueOf(submitted.requestId);
            queued.referenceId = submitted.referenceId;
            return queued;
        } catch (AIRefactorException ex) {
            return fail(ex.getMessage());
        } catch (Exception ex) {
            return fail(ex.getMessage());
        }
    }

    public static Result copyBranchAssets(String owner, String repo, String ownerRepo, String sourceBranch, String newBranch) {
        GitHubCloudConfig.RepoTarget target = GitHubCloudConfig.resolve(owner, repo, ownerRepo);
        String fromBranch = GitHubCloudConfig.firstNonBlank(sourceBranch, target.baseBranch);
        String toBranch = GitHubCloudConfig.firstNonBlank(newBranch, null);
        if (String.isBlank(toBranch)) {
            return fail('A destination branch name is required to copy assets.');
        }
        if (fromBranch == toBranch) {
            return fail('Source and destination branch names must be different.');
        }
        try {
            ResolvedSource source = resolveSource(target, fromBranch);
            if (source.branch == toBranch) {
                return fail('Source and destination branch names must be different.');
            }
            Map<String, Object> created = createRef(target, toBranch, source.sha);
            String zipUrl = branchZipDownloadUrl(target.owner, target.repo, toBranch);
            Result copied = ok(
                source.note + 'Copied all assets from "' + source.branch + '" to new branch "' + toBranch +
                '" in ' + target.owner + '/' + target.repo + ' (cloud GitHub refs, no local clone). Browse: ' +
                branchUrl(target, toBranch) + '. ' + zipMarkdownLink(toBranch, zipUrl),
                new Map<String, Object>{
                    'owner' => target.owner,
                    'repo' => target.repo,
                    'sourceBranch' => source.branch,
                    'requestedSourceBranch' => fromBranch,
                    'newBranch' => toBranch,
                    'sha' => source.sha,
                    'htmlUrl' => branchUrl(target, toBranch),
                    'zipUrl' => zipUrl,
                    'githubRef' => created
                }
            );
            copied.branchZipUrl = zipUrl;
            return copied;
        } catch (GitHubCloudClient.CalloutException ex) {
            return fail(ex.getMessage());
        }
    }

    public static Result listBranches(String owner, String repo, String ownerRepo) {
        GitHubCloudConfig.RepoTarget target = GitHubCloudConfig.resolve(owner, repo, ownerRepo);
        try {
            GitHubCloudClient.Response res = GitHubCloudClient.get(
                target.namedCredential,
                '/repos/' + target.owner + '/' + target.repo + '/branches?per_page=100'
            );
            List<Object> rows = (List<Object>) JSON.deserializeUntyped(res.body);
            List<String> names = new List<String>();
            for (Object row : rows) {
                Map<String, Object> branch = (Map<String, Object>) row;
                names.add(String.valueOf(branch.get('name')));
            }
            return ok(
                'Branches in ' + target.owner + '/' + target.repo + ': ' + String.join(names, ', '),
                new Map<String, Object>{
                    'owner' => target.owner,
                    'repo' => target.repo,
                    'branches' => names,
                    'count' => names.size()
                }
            );
        } catch (GitHubCloudClient.CalloutException ex) {
            return fail(ex.getMessage());
        }
    }

    public static Result listFiles(String owner, String repo, String ownerRepo, String branch) {
        GitHubCloudConfig.RepoTarget target = GitHubCloudConfig.resolve(owner, repo, ownerRepo);
        String refBranch = GitHubCloudConfig.firstNonBlank(branch, target.baseBranch);
        try {
            ResolvedSource source = resolveSource(target, refBranch);
            refBranch = source.branch;
            GitHubCloudClient.Response res = GitHubCloudClient.get(
                target.namedCredential,
                '/repos/' + target.owner + '/' + target.repo + '/git/trees/' + source.sha + '?recursive=1'
            );
            Map<String, Object> tree = (Map<String, Object>) JSON.deserializeUntyped(res.body);
            List<Object> entries = (List<Object>) tree.get('tree');
            List<String> paths = new List<String>();
            Integer blobCount = 0;
            if (entries != null) {
                for (Object entry : entries) {
                    Map<String, Object> item = (Map<String, Object>) entry;
                    if ('blob'.equals(item.get('type'))) {
                        blobCount++;
                        if (paths.size() < 200) {
                            paths.add(String.valueOf(item.get('path')));
                        }
                    }
                }
            }
            String extra = blobCount > paths.size() ? ' Showing first ' + paths.size() + ' files.' : '';
            return ok(
                'Branch "' + refBranch + '" in ' + target.owner + '/' + target.repo + ' has ' +
                blobCount + ' files.' + extra + ' ' + branchUrl(target, refBranch),
                new Map<String, Object>{
                    'owner' => target.owner,
                    'repo' => target.repo,
                    'branch' => refBranch,
                    'fileCount' => blobCount,
                    'files' => paths,
                    'htmlUrl' => branchUrl(target, refBranch)
                }
            );
        } catch (GitHubCloudClient.CalloutException ex) {
            return fail(ex.getMessage());
        }
    }

    public static Result describeRepo(String owner, String repo, String ownerRepo) {
        GitHubCloudConfig.RepoTarget target = GitHubCloudConfig.resolve(owner, repo, ownerRepo);
        try {
            GitHubCloudClient.Response res = GitHubCloudClient.get(
                target.namedCredential,
                '/repos/' + target.owner + '/' + target.repo
            );
            Map<String, Object> repoJson = (Map<String, Object>) JSON.deserializeUntyped(res.body);
            String htmlUrl = String.valueOf(repoJson.get('html_url'));
            String defaultBranch = String.valueOf(repoJson.get('default_branch'));
            return ok(
                'Repository ' + target.owner + '/' + target.repo + ' default branch is "' +
                defaultBranch + '". ' + htmlUrl,
                repoJson
            );
        } catch (GitHubCloudClient.CalloutException ex) {
            return fail(ex.getMessage());
        }
    }

    // Copies only the files under one folder from a source branch onto a destination branch.
    // Unlike copyBranchAssets this cannot be a ref pointer, so it builds a new tree and commit.
    public static Result copyFolder(
        String owner,
        String repo,
        String ownerRepo,
        String sourceBranch,
        String folderPath,
        String destinationBranch,
        String commitMessage
    ) {
        GitHubCloudConfig.RepoTarget target = GitHubCloudConfig.resolve(owner, repo, ownerRepo);
        String fromBranch = GitHubCloudConfig.firstNonBlank(sourceBranch, target.baseBranch);
        String toBranch = GitHubCloudConfig.firstNonBlank(destinationBranch, null);
        String folder = normalizeFolder(folderPath);

        if (String.isBlank(folder)) {
            return fail('A folder path is required, for example force-app/main/default/classes.');
        }
        if (String.isBlank(toBranch)) {
            return fail('A destination branch name is required.');
        }

        try {
            ResolvedSource source = resolveSource(target, fromBranch);
            if (source.branch == toBranch) {
                return fail('Source and destination branch names must be different.');
            }

            List<Object> entries = collectFolderEntries(target, source.sha, folder);
            if (entries.isEmpty()) {
                return fail(
                    'No files found under "' + folder + '" on branch "' + source.branch +
                    '". Check the folder path and try again.'
                );
            }

            Boolean destinationExists = true;
            String destHeadSha;
            try {
                destHeadSha = getBranchSha(target, toBranch);
            } catch (GitHubCloudClient.CalloutException ex) {
                if (!isNotFound(ex)) {
                    throw ex;
                }
                destinationExists = false;
            }

            String message = GitHubCloudConfig.firstNonBlank(
                commitMessage,
                'Copy ' + folder + ' from ' + source.branch + ' into ' + toBranch
            );
            String commitSha;
            String outcomeNote;

            if (destinationExists) {
                // Layer the folder on top of whatever the branch already has.
                String baseTreeSha = getCommitTreeSha(target, destHeadSha);
                String newTreeSha = createTree(target, baseTreeSha, entries);
                commitSha = createCommit(target, message, newTreeSha, destHeadSha);
                updateRef(target, toBranch, commitSha);
                outcomeNote = ' Branch "' + toBranch + '" already existed, so the folder was added on top of it and' +
                    ' its other files were left unchanged.';
            } else {
                // New branch holds only the selected folder, so build a root commit with no base tree and no parent.
                String newTreeSha = createTree(target, null, entries);
                commitSha = createCommit(target, message, newTreeSha, null);
                createRef(target, toBranch, commitSha);
                outcomeNote = ' Branch "' + toBranch + '" was created containing only that folder.';
            }

            return ok(
                source.note + 'Copied ' + entries.size() + ' file(s) from folder "' + folder + '" on "' +
                source.branch + '" into branch "' + toBranch + '" in ' + target.owner + '/' + target.repo +
                '.' + outcomeNote + ' ' + branchUrl(target, toBranch) + '/' + folder,
                new Map<String, Object>{
                    'owner' => target.owner,
                    'repo' => target.repo,
                    'sourceBranch' => source.branch,
                    'requestedSourceBranch' => fromBranch,
                    'destinationBranch' => toBranch,
                    'folder' => folder,
                    'fileCount' => entries.size(),
                    'branchCreated' => !destinationExists,
                    'folderOnlyBranch' => !destinationExists,
                    'commitSha' => commitSha,
                    'htmlUrl' => branchUrl(target, toBranch) + '/' + folder
                }
            );
        } catch (GitHubCloudClient.CalloutException ex) {
            return fail(ex.getMessage());
        }
    }

    private static List<Object> collectFolderEntries(
        GitHubCloudConfig.RepoTarget target,
        String sourceSha,
        String folder
    ) {
        GitHubCloudClient.Response res = GitHubCloudClient.get(
            target.namedCredential,
            '/repos/' + target.owner + '/' + target.repo + '/git/trees/' + sourceSha + '?recursive=1'
        );
        Map<String, Object> tree = (Map<String, Object>) JSON.deserializeUntyped(res.body);
        List<Object> treeEntries = (List<Object>) tree.get('tree');
        List<Object> picked = new List<Object>();
        if (treeEntries == null) {
            return picked;
        }
        String prefix = folder + '/';
        for (Object entry : treeEntries) {
            Map<String, Object> item = (Map<String, Object>) entry;
            if (!'blob'.equals(item.get('type'))) {
                continue;
            }
            String path = String.valueOf(item.get('path'));
            if (path != folder && !path.startsWith(prefix)) {
                continue;
            }
            picked.add(
                new Map<String, Object>{
                    'path' => path,
                    'mode' => String.valueOf(item.get('mode')),
                    'type' => 'blob',
                    'sha' => String.valueOf(item.get('sha'))
                }
            );
        }
        return picked;
    }

    private static String getCommitTreeSha(GitHubCloudConfig.RepoTarget target, String commitSha) {
        GitHubCloudClient.Response res = GitHubCloudClient.get(
            target.namedCredential,
            '/repos/' + target.owner + '/' + target.repo + '/git/commits/' + commitSha
        );
        Map<String, Object> commitJson = (Map<String, Object>) JSON.deserializeUntyped(res.body);
        Map<String, Object> treeNode = (Map<String, Object>) commitJson.get('tree');
        if (treeNode == null || treeNode.get('sha') == null) {
            throw new GitHubCloudClient.CalloutException('GitHub did not return a tree for commit ' + commitSha);
        }
        return String.valueOf(treeNode.get('sha'));
    }

    // A null baseTreeSha builds a standalone tree, so the result contains only the supplied entries.
    private static String createTree(GitHubCloudConfig.RepoTarget target, String baseTreeSha, List<Object> entries) {
        Map<String, Object> payload = new Map<String, Object>{ 'tree' => entries };
        if (String.isNotBlank(baseTreeSha)) {
            payload.put('base_tree', baseTreeSha);
        }
        GitHubCloudClient.Response res = GitHubCloudClient.post(
            target.namedCredential,
            '/repos/' + target.owner + '/' + target.repo + '/git/trees',
            JSON.serialize(payload)
        );
        Map<String, Object> tree = (Map<String, Object>) JSON.deserializeUntyped(res.body);
        return String.valueOf(tree.get('sha'));
    }

    private static String createCommit(
        GitHubCloudConfig.RepoTarget target,
        String message,
        String treeSha,
        String parentSha
    ) {
        // A null parentSha creates a root commit, which is what a folder-only branch needs.
        List<String> parents = String.isBlank(parentSha) ? new List<String>() : new List<String>{ parentSha };
        Map<String, Object> payload = new Map<String, Object>{
            'message' => message,
            'tree' => treeSha,
            'parents' => parents
        };
        GitHubCloudClient.Response res = GitHubCloudClient.post(
            target.namedCredential,
            '/repos/' + target.owner + '/' + target.repo + '/git/commits',
            JSON.serialize(payload)
        );
        Map<String, Object> commitJson = (Map<String, Object>) JSON.deserializeUntyped(res.body);
        return String.valueOf(commitJson.get('sha'));
    }

    private static void updateRef(GitHubCloudConfig.RepoTarget target, String branch, String commitSha) {
        GitHubCloudClient.patch(
            target.namedCredential,
            '/repos/' + target.owner + '/' + target.repo + '/git/refs/heads/' + encodeBranch(branch),
            JSON.serialize(new Map<String, Object>{ 'sha' => commitSha, 'force' => false })
        );
    }

    private static String normalizeFolder(String folderPath) {
        if (String.isBlank(folderPath)) {
            return null;
        }
        String cleaned = folderPath.trim().replace('\\', '/');
        while (cleaned.startsWith('/')) {
            cleaned = cleaned.substring(1);
        }
        while (cleaned.endsWith('/')) {
            cleaned = cleaned.substring(0, cleaned.length() - 1);
        }
        return cleaned;
    }

    private class ResolvedSource {
        String branch;
        String sha;
        String note = '';
    }

    // Callers often say "main" for a repo whose default branch is "master" (or the reverse).
    // Fall back to the repository's real default branch instead of failing the whole request.
    private static ResolvedSource resolveSource(GitHubCloudConfig.RepoTarget target, String requestedBranch) {
        ResolvedSource source = new ResolvedSource();
        try {
            source.branch = requestedBranch;
            source.sha = getBranchSha(target, requestedBranch);
            return source;
        } catch (GitHubCloudClient.CalloutException ex) {
            if (!isNotFound(ex)) {
                throw ex;
            }
            String defaultBranch = getDefaultBranch(target);
            if (String.isBlank(defaultBranch) || defaultBranch == requestedBranch) {
                throw ex;
            }
            source.branch = defaultBranch;
            source.sha = getBranchSha(target, defaultBranch);
            source.note = 'Branch "' + requestedBranch + '" does not exist in this repository, so the default branch "' +
                defaultBranch + '" was used as the source. ';
            return source;
        }
    }

    private static Boolean isNotFound(GitHubCloudClient.CalloutException ex) {
        return ex.getMessage() != null && ex.getMessage().contains('(404)');
    }

    private static String getDefaultBranch(GitHubCloudConfig.RepoTarget target) {
        GitHubCloudClient.Response res = GitHubCloudClient.get(
            target.namedCredential,
            '/repos/' + target.owner + '/' + target.repo
        );
        Map<String, Object> repoJson = (Map<String, Object>) JSON.deserializeUntyped(res.body);
        return repoJson == null ? null : String.valueOf(repoJson.get('default_branch'));
    }

    private static String getBranchSha(GitHubCloudConfig.RepoTarget target, String branch) {
        GitHubCloudClient.Response res = GitHubCloudClient.get(
            target.namedCredential,
            '/repos/' + target.owner + '/' + target.repo + '/git/ref/heads/' + encodeBranch(branch)
        );
        Map<String, Object> parsed = (Map<String, Object>) JSON.deserializeUntyped(res.body);
        Map<String, Object> objectNode = (Map<String, Object>) parsed.get('object');
        if (objectNode == null || objectNode.get('sha') == null) {
            throw new GitHubCloudClient.CalloutException('GitHub did not return a SHA for branch ' + branch);
        }
        return String.valueOf(objectNode.get('sha'));
    }

    private static Map<String, Object> createRef(GitHubCloudConfig.RepoTarget target, String branch, String sha) {
        Map<String, String> payload = new Map<String, String>{
            'ref' => 'refs/heads/' + branch,
            'sha' => sha
        };
        GitHubCloudClient.Response res = GitHubCloudClient.post(
            target.namedCredential,
            '/repos/' + target.owner + '/' + target.repo + '/git/refs',
            JSON.serialize(payload)
        );
        return (Map<String, Object>) JSON.deserializeUntyped(res.body);
    }

    private static String encodeBranch(String branch) {
        return EncodingUtil.urlEncode(branch, 'UTF-8').replace('+', '%20').replace('%2F', '/');
    }

    private static String branchUrl(GitHubCloudConfig.RepoTarget target, String branch) {
        return 'https://github.com/' + target.owner + '/' + target.repo + '/tree/' + branch;
    }

    private static Result ok(String message, Object details) {
        Result result = new Result();
        result.success = true;
        result.message = message;
        result.detailsJson = JSON.serialize(details);
        return result;
    }

    private static Result fail(String message) {
        Result result = new Result();
        result.success = false;
        result.message = message;
        result.detailsJson = JSON.serialize(new Map<String, Object>{ 'success' => false, 'message' => message });
        return result;
    }
}