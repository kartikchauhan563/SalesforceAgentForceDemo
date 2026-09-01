public with sharing class SfOrgConnectService {
    private static final Integer MAX_JSON_CHARS = 20000;
    private static final Integer DEFAULT_LIMIT = 10;
    private static final Integer MAX_LIMIT = 50;

    public class Result {
        public Boolean success;
        public String message;
        public String detailsJson;
        public String organizationId;
        public String organizationName;
        public String userName;
        public String instanceUrl;
        public Integer recordCount;
        public String connectionId;
        public String authorizeUrl;
    }

    public static Result connect(
        String username,
        String password,
        String securityToken,
        String isSandbox,
        String loginUrl
    ) {
        try {
            SfOrgConnectClient.Session session = loginSession(username, password, securityToken, isSandbox, loginUrl);
            Result result = ok(
                'Connected to ' +
                nvl(session.organizationName, 'Salesforce org') +
                ' as ' +
                nvl(session.userName, username) +
                '. Instance: ' +
                session.instanceUrl +
                '. You can now ask for objects or records from this org.',
                new Map<String, Object>{
                    'organizationId' => session.organizationId,
                    'organizationName' => session.organizationName,
                    'userId' => session.userId,
                    'userName' => session.userName,
                    'instanceUrl' => session.instanceUrl
                }
            );
            result.organizationId = session.organizationId;
            result.organizationName = session.organizationName;
            result.userName = session.userName;
            result.instanceUrl = session.instanceUrl;
            return result;
        } catch (Exception ex) {
            return fail(friendlyError('Could not connect to the Salesforce org', ex));
        }
    }

    public static Result query(
        String username,
        String password,
        String securityToken,
        String isSandbox,
        String loginUrl,
        String soql,
        String connectionId
    ) {
        try {
            String safeSoql = sanitizeSoql(soql);
            if (safeSoql == null) {
                return fail(
                    'Provide a read-only SOQL SELECT statement. DML, multiple statements, and comments are not allowed. Example: SELECT Id, Name FROM Account LIMIT 10'
                );
            }
            SfOrgConnectClient.Session session = resolveSession(
                username,
                password,
                securityToken,
                isSandbox,
                loginUrl,
                connectionId
            );
            String path =
                '/services/data/v' +
                SfOrgConnectClient.apiVersion() +
                '/query?q=' +
                EncodingUtil.urlEncode(safeSoql, 'UTF-8');
            SfOrgConnectClient.Response res = SfOrgConnectClient.restGet(session, path);
            Map<String, Object> parsed = (Map<String, Object>) JSON.deserializeUntyped(res.body);
            Integer totalSize = parsed.containsKey('totalSize') ? Integer.valueOf(String.valueOf(parsed.get('totalSize'))) : 0;
            Result result = ok(
                'Query returned ' + totalSize + ' record(s) from ' + nvl(session.organizationName, session.instanceUrl) + '.',
                parsed
            );
            result.recordCount = totalSize;
            result.instanceUrl = session.instanceUrl;
            result.organizationName = session.organizationName;
            return result;
        } catch (Exception ex) {
            return fail(friendlyError('Query failed', ex));
        }
    }

    public static Result listObjects(
        String username,
        String password,
        String securityToken,
        String isSandbox,
        String loginUrl,
        String connectionId
    ) {
        try {
            SfOrgConnectClient.Session session = resolveSession(
                username,
                password,
                securityToken,
                isSandbox,
                loginUrl,
                connectionId
            );
            String path = '/services/data/v' + SfOrgConnectClient.apiVersion() + '/sobjects';
            SfOrgConnectClient.Response res = SfOrgConnectClient.restGet(session, path);
            Map<String, Object> parsed = (Map<String, Object>) JSON.deserializeUntyped(res.body);
            List<String> names = new List<String>();
            if (parsed.containsKey('sobjects') && parsed.get('sobjects') instanceof List<Object>) {
                for (Object item : (List<Object>) parsed.get('sobjects')) {
                    if (!(item instanceof Map<String, Object>)) {
                        continue;
                    }
                    Map<String, Object> sobj = (Map<String, Object>) item;
                    if (sobj.containsKey('name')) {
                        names.add(String.valueOf(sobj.get('name')));
                    }
                    if (names.size() >= 200) {
                        break;
                    }
                }
            }
            Result result = ok(
                'Found ' +
                names.size() +
                ' sObject(s) in ' +
                nvl(session.organizationName, session.instanceUrl) +
                '. Showing names in details JSON.',
                new Map<String, Object>{ 'sobjectNames' => names, 'count' => names.size() }
            );
            result.recordCount = names.size();
            result.organizationName = session.organizationName;
            result.instanceUrl = session.instanceUrl;
            return result;
        } catch (Exception ex) {
            return fail(friendlyError('Could not list objects', ex));
        }
    }

    public static Result getRecords(
        String username,
        String password,
        String securityToken,
        String isSandbox,
        String loginUrl,
        String objectApiName,
        String fields,
        String whereClause,
        String recordLimit,
        String connectionId
    ) {
        String objectName = sanitizeApiName(objectApiName);
        if (objectName == null) {
            return fail('Provide a valid Salesforce object API name such as Account, Contact, or Loan_Application__c.');
        }
        String fieldList = sanitizeFieldList(fields);
        String whereSafe = sanitizeWhere(whereClause);
        if (whereClause != null && whereClause.trim().length() > 0 && whereSafe == null) {
            return fail('The WHERE clause can only use letters, numbers, underscores, quotes, and comparison operators.');
        }
        Integer lim = parseLimit(recordLimit);
        String soql = 'SELECT ' + fieldList + ' FROM ' + objectName;
        if (!String.isBlank(whereSafe)) {
            soql += ' WHERE ' + whereSafe;
        }
        soql += ' LIMIT ' + String.valueOf(lim);
        return query(username, password, securityToken, isSandbox, loginUrl, soql, connectionId);
    }

    public static String resolveLoginHost(String loginUrl, String isSandbox) {
        if (!String.isBlank(loginUrl)) {
            String trimmed = loginUrl.trim();
            if (trimmed.startsWith('https://') || trimmed.startsWith('http://')) {
                Url parsed = new Url(trimmed);
                return parsed.getHost();
            }
            return trimmed.replace('https://', '').replace('http://', '').split('/')[0];
        }
        return isSandboxFlag(isSandbox) ? 'test.salesforce.com' : 'login.salesforce.com';
    }

    private static SfOrgConnectClient.Session resolveSession(
        String username,
        String password,
        String securityToken,
        String isSandbox,
        String loginUrl,
        String connectionId
    ) {
        if (!String.isBlank(connectionId)) {
            return SfOrgOAuthService.sessionFor(connectionId);
        }
        return loginSession(username, password, securityToken, isSandbox, loginUrl);
    }

    private static SfOrgConnectClient.Session loginSession(
        String username,
        String password,
        String securityToken,
        String isSandbox,
        String loginUrl
    ) {
        if (String.isBlank(username) || String.isBlank(password)) {
            throw new SfOrgConnectClient.CalloutException('Username and password are required.');
        }
        return SfOrgConnectClient.login(
            username.trim(),
            buildPassword(password, securityToken),
            resolveLoginHost(loginUrl, isSandbox)
        );
    }

    // Salesforce expects the security token concatenated onto the password with no separator.
    public static String buildPassword(String password, String securityToken) {
        String result = password == null ? '' : password.trim();
        if (!String.isBlank(securityToken)) {
            String token = securityToken.trim();
            if (!result.endsWith(token)) {
                result += token;
            }
        }
        return result;
    }

    private static Boolean isSandboxFlag(String isSandbox) {
        if (String.isBlank(isSandbox)) {
            return false;
        }
        String v = isSandbox.trim().toLowerCase();
        return v == 'true' || v == 'yes' || v == 'sandbox' || v == 'test' || v == '1';
    }

    public static String sanitizeSoql(String soql) {
        if (String.isBlank(soql)) {
            return null;
        }
        String compact = soql.trim().replaceAll('\\s+', ' ');
        String upper = compact.toUpperCase();
        if (!upper.startsWith('SELECT ')) {
            return null;
        }
        if (compact.contains(';') || compact.contains('--') || compact.contains('/*')) {
            return null;
        }
        List<String> blocked = new List<String>{
            ' INSERT ',
            ' UPDATE ',
            ' DELETE ',
            ' UPSERT ',
            ' MERGE ',
            ' UNDELETE ',
            ' UNDEPLOY '
        };
        for (String token : blocked) {
            if (upper.contains(token)) {
                return null;
            }
        }
        if (!upper.contains(' LIMIT ')) {
            compact += ' LIMIT ' + String.valueOf(DEFAULT_LIMIT);
        }
        return compact;
    }

    private static String sanitizeApiName(String value) {
        if (String.isBlank(value)) {
            return null;
        }
        String trimmed = value.trim();
        if (!Pattern.matches('^[A-Za-z][A-Za-z0-9_]{0,79}$', trimmed)) {
            return null;
        }
        return trimmed;
    }

    private static String sanitizeFieldList(String fields) {
        if (String.isBlank(fields)) {
            return 'FIELDS(STANDARD)';
        }
        List<String> parts = new List<String>();
        for (String raw : fields.split(',')) {
            String name = sanitizeApiName(raw);
            if (name == null) {
                continue;
            }
            parts.add(name);
        }
        return parts.isEmpty() ? 'FIELDS(STANDARD)' : String.join(parts, ',');
    }

    private static String sanitizeWhere(String whereClause) {
        if (String.isBlank(whereClause)) {
            return null;
        }
        String trimmed = whereClause.trim();
        String upper = trimmed.toUpperCase();
        if (upper.startsWith('WHERE ')) {
            trimmed = trimmed.substring(6).trim();
        }
        if (!Pattern.matches('^[A-Za-z0-9_\\.\\s=<>\'%()\\-,]+$', trimmed)) {
            return null;
        }
        return trimmed;
    }

    private static Integer parseLimit(String recordLimit) {
        if (String.isBlank(recordLimit)) {
            return DEFAULT_LIMIT;
        }
        try {
            Integer value = Integer.valueOf(recordLimit.trim());
            if (value < 1) {
                return DEFAULT_LIMIT;
            }
            return value > MAX_LIMIT ? MAX_LIMIT : value;
        } catch (Exception ignore) {
            return DEFAULT_LIMIT;
        }
    }

    public static Result okPublic(String message, Object details) {
        return ok(message, details);
    }

    public static Result failPublic(String message) {
        return fail(message);
    }

    private static Result ok(String message, Object details) {
        Result result = new Result();
        result.success = true;
        result.message = message;
        result.detailsJson = toJson(details);
        return result;
    }

    private static Result fail(String message) {
        Result result = new Result();
        result.success = false;
        result.message = message;
        result.detailsJson = JSON.serialize(new Map<String, Object>{ 'success' => false, 'message' => message });
        return result;
    }

    private static String toJson(Object details) {
        String jsonBody = JSON.serialize(details);
        if (jsonBody != null && jsonBody.length() > MAX_JSON_CHARS) {
            return jsonBody.substring(0, MAX_JSON_CHARS);
        }
        return jsonBody;
    }

    private static String nvl(String value, String fallback) {
        return String.isBlank(value) ? fallback : value;
    }

    private static String friendlyError(String prefix, Exception ex) {
        String detail = ex.getMessage();
        if (!String.isBlank(detail) && detail.contains('Unauthorized endpoint')) {
            return prefix +
                ': this Salesforce org cannot call the target org instance. Ask an admin to add a Remote Site Setting for the target My Domain (the instance URL from Connect to Salesforce Org), then try again.';
        }
        return String.isBlank(detail) ? prefix : prefix + ': ' + detail;
    }
}
