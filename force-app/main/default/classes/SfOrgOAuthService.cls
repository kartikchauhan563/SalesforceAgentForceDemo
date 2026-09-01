public without sharing class SfOrgOAuthService {
    public class CallbackResult {
        public Boolean success;
        public String message;
    }

    public static SfOrgConnectService.Result startAuthorization(String isSandbox, String loginUrl) {
        Sf_Org_OAuth_Secret__c cfg = config();
        if (String.isBlank(cfg.Consumer_Key__c)) {
            return SfOrgConnectService.failPublic(
                'OAuth is not configured yet. The Consumer Key of the Connect With Salesforce Org OAuth connected app is missing from the Sf Org OAuth Secret custom setting.'
            );
        }
        String host = SfOrgConnectService.resolveLoginHost(loginUrl, isSandbox);
        String connectionKey = EncodingUtil.convertToHex(Crypto.generateAesKey(128));
        String codeVerifier = EncodingUtil.convertToHex(Crypto.generateAesKey(256));
        Sf_Org_Connection__c row = new Sf_Org_Connection__c();
        row.Connection_Key__c = connectionKey;
        row.Status__c = 'Pending';
        row.Login_Host__c = host;
        row.Code_Verifier__c = codeVerifier;
        insert row;

        String authorizeUrl =
            'https://' +
            host +
            '/services/oauth2/authorize?response_type=code' +
            '&client_id=' +
            EncodingUtil.urlEncode(cfg.Consumer_Key__c, 'UTF-8') +
            '&redirect_uri=' +
            EncodingUtil.urlEncode(callbackUrl(cfg), 'UTF-8') +
            '&scope=' +
            EncodingUtil.urlEncode('api refresh_token openid', 'UTF-8') +
            '&state=' +
            EncodingUtil.urlEncode(connectionKey, 'UTF-8') +
            '&code_challenge=' +
            EncodingUtil.urlEncode(codeChallenge(codeVerifier), 'UTF-8') +
            '&code_challenge_method=S256' +
            '&prompt=login';

        SfOrgConnectService.Result result = SfOrgConnectService.okPublic(
            'Open this Salesforce login link, sign in to the org you want to read, and click Allow. Then come back here and say "I authorized it".\n\n' +
                '[' +
                authorizeUrl +
                '](' +
                authorizeUrl +
                ')',
            new Map<String, Object>{
                'connectionId' => connectionKey,
                'authorizeUrl' => authorizeUrl,
                'status' => 'Pending'
            }
        );
        result.connectionId = connectionKey;
        result.authorizeUrl = authorizeUrl;
        return result;
    }

    public static SfOrgConnectService.Result checkAuthorization(String connectionId) {
        Sf_Org_Connection__c row = find(connectionId);
        if (row == null) {
            return SfOrgConnectService.failPublic('No OAuth connection was found for that id. Ask me for a new authorize link.');
        }
        if (row.Status__c == 'Authorized') {
            SfOrgConnectService.Result result = SfOrgConnectService.okPublic(
                'Connected to ' +
                    nvl(row.Organization_Name__c, 'the Salesforce org') +
                    ' as ' +
                    nvl(row.Org_User_Name__c, 'the authorized user') +
                    '. Instance: ' +
                    nvl(row.Instance_Url__c, '') +
                    '. You can now ask for objects or records.',
                new Map<String, Object>{
                    'connectionId' => row.Connection_Key__c,
                    'status' => row.Status__c,
                    'organizationId' => row.Organization_Id__c,
                    'organizationName' => row.Organization_Name__c,
                    'userName' => row.Org_User_Name__c,
                    'instanceUrl' => row.Instance_Url__c
                }
            );
            result.connectionId = row.Connection_Key__c;
            result.organizationId = row.Organization_Id__c;
            result.organizationName = row.Organization_Name__c;
            result.userName = row.Org_User_Name__c;
            result.instanceUrl = row.Instance_Url__c;
            return result;
        }
        if (row.Status__c == 'Failed') {
            return SfOrgConnectService.failPublic(
                'Authorization failed: ' + nvl(row.Error_Message__c, 'the user denied access or the callback could not complete.')
            );
        }
        return SfOrgConnectService.failPublic(
            'Authorization is still pending. Open the authorize link, click Allow, then tell me when you are done.'
        );
    }

    public static CallbackResult completeAuthorization(String code, String state, String errorParam) {
        CallbackResult out = new CallbackResult();
        Sf_Org_Connection__c row = find(state);
        if (row == null) {
            out.success = false;
            out.message = 'This authorize link is invalid or has expired. Ask the agent for a new link.';
            return out;
        }
        if (!String.isBlank(errorParam)) {
            row.Status__c = 'Failed';
            row.Error_Message__c = errorParam;
            update row;
            out.success = false;
            out.message = 'Access was not granted (' + errorParam + '). Return to the agent and ask for a new link if you want to try again.';
            return out;
        }
        if (String.isBlank(code)) {
            out.success = false;
            out.message = 'Salesforce did not return an authorization code.';
            return out;
        }
        try {
            Sf_Org_OAuth_Secret__c cfg = config();
            String body =
                'grant_type=authorization_code' +
                '&code=' +
                EncodingUtil.urlEncode(code, 'UTF-8') +
                '&client_id=' +
                EncodingUtil.urlEncode(cfg.Consumer_Key__c, 'UTF-8') +
                clientSecretParam(cfg) +
                '&redirect_uri=' +
                EncodingUtil.urlEncode(callbackUrl(cfg), 'UTF-8');
            if (!String.isBlank(row.Code_Verifier__c)) {
                body += '&code_verifier=' + EncodingUtil.urlEncode(row.Code_Verifier__c, 'UTF-8');
            }
            Map<String, Object> token = SfOrgConnectClient.postForm(
                'https://' + nvl(row.Login_Host__c, 'login.salesforce.com') + '/services/oauth2/token',
                body
            );
            applyToken(row, token);
            row.Status__c = 'Authorized';
            row.Error_Message__c = null;
            row.Code_Verifier__c = null;
            update row;
            out.success = true;
            out.message =
                'You are connected to ' +
                nvl(row.Organization_Name__c, 'the Salesforce org') +
                '. Return to the agent and say "I authorized it".';
            return out;
        } catch (Exception ex) {
            row.Status__c = 'Failed';
            row.Error_Message__c = ex.getMessage();
            update row;
            out.success = false;
            out.message = 'Authorization callback failed: ' + ex.getMessage();
            return out;
        }
    }

    public static SfOrgConnectClient.Session sessionFor(String connectionId) {
        Sf_Org_Connection__c row = find(connectionId);
        if (row == null) {
            throw new SfOrgConnectClient.CalloutException(
                'No OAuth connection was found. Ask the agent for an authorize link first.'
            );
        }
        if (row.Status__c != 'Authorized') {
            throw new SfOrgConnectClient.CalloutException(
                'The Salesforce org is not authorized yet. Open the authorize link and click Allow.'
            );
        }
        if (row.Token_Issued_At__c != null && row.Token_Issued_At__c.addHours(1) < System.now()) {
            row = refresh(row);
        }
        SfOrgConnectClient.Session session = new SfOrgConnectClient.Session();
        session.sessionId = decryptValue(row.Access_Token_Enc__c);
        session.instanceUrl = row.Instance_Url__c;
        session.organizationId = row.Organization_Id__c;
        session.organizationName = row.Organization_Name__c;
        session.userName = row.Org_User_Name__c;
        return session;
    }

    private static Sf_Org_Connection__c refresh(Sf_Org_Connection__c row) {
        if (String.isBlank(row.Refresh_Token_Enc__c)) {
            return row;
        }
        Sf_Org_OAuth_Secret__c cfg = config();
        String body =
            'grant_type=refresh_token' +
            '&refresh_token=' +
            EncodingUtil.urlEncode(decryptValue(row.Refresh_Token_Enc__c), 'UTF-8') +
            '&client_id=' +
            EncodingUtil.urlEncode(cfg.Consumer_Key__c, 'UTF-8') +
            clientSecretParam(cfg);
        Map<String, Object> token = SfOrgConnectClient.postForm(
            'https://' + nvl(row.Login_Host__c, 'login.salesforce.com') + '/services/oauth2/token',
            body
        );
        applyToken(row, token);
        update row;
        return row;
    }

    private static void applyToken(Sf_Org_Connection__c row, Map<String, Object> token) {
        SfOrgConnectClient.Session session = SfOrgConnectClient.sessionFromOAuth(token);
        row.Access_Token_Enc__c = encryptValue(session.sessionId);
        String refreshToken = token.containsKey('refresh_token') ? String.valueOf(token.get('refresh_token')) : null;
        if (!String.isBlank(refreshToken)) {
            row.Refresh_Token_Enc__c = encryptValue(refreshToken);
        }
        row.Instance_Url__c = session.instanceUrl;
        row.Organization_Id__c = session.organizationId;
        row.Token_Issued_At__c = System.now();
        if (!String.isBlank(session.instanceUrl) && !String.isBlank(session.sessionId)) {
            try {
                SfOrgConnectClient.Response idRes = SfOrgConnectClient.restGet(session, '/services/oauth2/userinfo');
                Map<String, Object> info = (Map<String, Object>) JSON.deserializeUntyped(idRes.body);
                if (info.containsKey('preferred_username')) {
                    row.Org_User_Name__c = String.valueOf(info.get('preferred_username'));
                    session.userName = row.Org_User_Name__c;
                }
                if (info.containsKey('organization_id')) {
                    row.Organization_Id__c = String.valueOf(info.get('organization_id'));
                }
            } catch (Exception ignore) {
            }
            try {
                String query = EncodingUtil.urlEncode('SELECT IsSandbox FROM Organization LIMIT 1', 'UTF-8');
                SfOrgConnectClient.Response orgRes = SfOrgConnectClient.restGet(
                    session,
                    '/services/data/v' + SfOrgConnectClient.apiVersion() + '/query?q=' + query
                );
                Map<String, Object> payload = (Map<String, Object>) JSON.deserializeUntyped(orgRes.body);
                List<Object> records = (List<Object>) payload.get('records');
                if (records != null && !records.isEmpty()) {
                    Map<String, Object> orgRow = (Map<String, Object>) records[0];
                    row.Is_Sandbox__c = Boolean.valueOf(String.valueOf(orgRow.get('IsSandbox')));
                }
            } catch (Exception ignore) {
                // Unknown is deliberately treated as production by the deployment gate.
            }
        }
        if (String.isBlank(row.Organization_Name__c) && !String.isBlank(row.Instance_Url__c)) {
            row.Organization_Name__c = row.Instance_Url__c.replace('https://', '').replace('.my.salesforce.com', '');
        }
    }

    private static Sf_Org_Connection__c find(String connectionId) {
        if (String.isBlank(connectionId)) {
            return null;
        }
        List<Sf_Org_Connection__c> rows = [
            SELECT
                Id,
                Connection_Key__c,
                Status__c,
                Instance_Url__c,
                Access_Token_Enc__c,
                Refresh_Token_Enc__c,
                Token_Issued_At__c,
                Organization_Id__c,
                Organization_Name__c,
                Org_User_Name__c,
                Is_Sandbox__c,
                Login_Host__c,
                Code_Verifier__c,
                Error_Message__c
            FROM Sf_Org_Connection__c
            WHERE Connection_Key__c = :connectionId.trim()
            LIMIT 1
        ];
        return rows.isEmpty() ? null : rows[0];
    }

    private static String callbackUrl(Sf_Org_OAuth_Secret__c cfg) {
        if (!String.isBlank(cfg.Callback_URL__c)) {
            return cfg.Callback_URL__c.trim();
        }
        return URL.getOrgDomainUrl().toExternalForm() + '/apex/SfOrgOAuthCallback';
    }

    private static String clientSecretParam(Sf_Org_OAuth_Secret__c cfg) {
        if (String.isBlank(cfg.Consumer_Secret__c)) {
            return '';
        }
        return '&client_secret=' + EncodingUtil.urlEncode(cfg.Consumer_Secret__c, 'UTF-8');
    }

    private static String codeChallenge(String codeVerifier) {
        Blob digest = Crypto.generateDigest('SHA-256', Blob.valueOf(codeVerifier));
        return EncodingUtil.base64Encode(digest).replace('+', '-').replace('/', '_').replace('=', '');
    }

    private static Sf_Org_OAuth_Secret__c config() {
        Sf_Org_OAuth_Secret__c cfg = Sf_Org_OAuth_Secret__c.getOrgDefaults();
        if (cfg == null) {
            cfg = new Sf_Org_OAuth_Secret__c();
        }
        if (String.isBlank(cfg.Aes_Key__c)) {
            cfg.Aes_Key__c = EncodingUtil.base64Encode(Crypto.generateAesKey(256));
            if (cfg.Id == null) {
                cfg.SetupOwnerId = UserInfo.getOrganizationId();
            }
            upsert cfg;
        }
        return cfg;
    }

    @TestVisible
    private static String encryptValue(String value) {
        if (String.isBlank(value)) {
            return null;
        }
        Blob encrypted = Crypto.encryptWithManagedIV('AES256', aesKey(), Blob.valueOf(value));
        return EncodingUtil.base64Encode(encrypted);
    }

    private static String decryptValue(String value) {
        if (String.isBlank(value)) {
            return null;
        }
        Blob decrypted = Crypto.decryptWithManagedIV('AES256', aesKey(), EncodingUtil.base64Decode(value));
        return decrypted.toString();
    }

    private static Blob aesKey() {
        return EncodingUtil.base64Decode(config().Aes_Key__c);
    }

    private static String nvl(String value, String fallback) {
        return String.isBlank(value) ? fallback : value;
    }
}
