@isTest
private class SfOrgConnectTest {
    private static final String LOGIN_OK =
        '<?xml version="1.0"?><soapenv:Envelope xmlns:soapenv="http://schemas.xmlsoap.org/soap/envelope/">' +
        '<soapenv:Body><loginResponse><result>' +
        '<sessionId>00DxxSESSION</sessionId>' +
        '<serverUrl>https://example.my.salesforce.com/services/Soap/u/62.0/00Dxx</serverUrl>' +
        '<userId>005xxUSER</userId>' +
        '<userName>user@example.com</userName>' +
        '<organizationId>00DxxORG</organizationId>' +
        '<organizationName>Demo Org</organizationName>' +
        '</result></loginResponse></soapenv:Body></soapenv:Envelope>';

    private static final String LOGIN_FAULT =
        '<?xml version="1.0"?><soapenv:Envelope xmlns:soapenv="http://schemas.xmlsoap.org/soap/envelope/">' +
        '<soapenv:Body><soapenv:Fault><faultstring>INVALID_LOGIN: Invalid username, password, security token; or user locked out.</faultstring>' +
        '</soapenv:Fault></soapenv:Body></soapenv:Envelope>';

    private static final String QUERY_OK =
        '{"totalSize":1,"done":true,"records":[{"Id":"001xx000001","Name":"Acme"}]}';

    private static final String SOBJECTS_OK =
        '{"sobjects":[{"name":"Account"},{"name":"Contact"},{"name":"Opportunity"}]}';

    @isTest
    static void resolveLoginHostProductionSandboxAndMyDomain() {
        System.assertEquals('login.salesforce.com', SfOrgConnectService.resolveLoginHost(null, null));
        System.assertEquals('test.salesforce.com', SfOrgConnectService.resolveLoginHost(null, 'sandbox'));
        System.assertEquals(
            'acme.my.salesforce.com',
            SfOrgConnectService.resolveLoginHost('https://acme.my.salesforce.com', null)
        );
    }

    @isTest
    static void sanitizeSoqlAllowsSelectAndRejectsDml() {
        System.assertEquals(
            'SELECT Id FROM Account LIMIT 10',
            SfOrgConnectService.sanitizeSoql('SELECT Id FROM Account')
        );
        System.assertEquals(null, SfOrgConnectService.sanitizeSoql('DELETE FROM Account'));
        System.assertEquals(null, SfOrgConnectService.sanitizeSoql('SELECT Id FROM Account; DROP TABLE'));
    }

    @isTest
    static void connectSuccess() {
        Test.setMock(HttpCalloutMock.class, new SfOrgConnectMock().add(200, LOGIN_OK));
        Test.startTest();
        SfOrgAction_Connect.Request req = new SfOrgAction_Connect.Request();
        req.username = 'user@example.com';
        req.password = 'secret';
        List<SfOrgAction_Connect.Response> res = SfOrgAction_Connect.run(
            new List<SfOrgAction_Connect.Request>{ req }
        );
        Test.stopTest();
        System.assertEquals(true, res[0].success);
        System.assertEquals('Demo Org', res[0].organizationName);
        System.assertEquals('https://example.my.salesforce.com', res[0].instanceUrl);
        System.assert(res[0].message.contains('Connected'));
    }

    @isTest
    static void connectMissingCredentials() {
        Test.startTest();
        List<SfOrgAction_Connect.Response> res = SfOrgAction_Connect.run(
            new List<SfOrgAction_Connect.Request>{ new SfOrgAction_Connect.Request() }
        );
        Test.stopTest();
        System.assertEquals(false, res[0].success);
        System.assert(res[0].message.contains('Username and password'));
    }

    @isTest
    static void connectInvalidLogin() {
        Test.setMock(HttpCalloutMock.class, new SfOrgConnectMock().add(500, LOGIN_FAULT));
        SfOrgAction_Connect.Request req = new SfOrgAction_Connect.Request();
        req.username = 'user@example.com';
        req.password = 'wrong';
        Test.startTest();
        List<SfOrgAction_Connect.Response> res = SfOrgAction_Connect.run(
            new List<SfOrgAction_Connect.Request>{ req }
        );
        Test.stopTest();
        System.assertEquals(false, res[0].success);
        System.assert(res[0].message.contains('INVALID_LOGIN'));
    }

    @isTest
    static void querySuccess() {
        Test.setMock(HttpCalloutMock.class, new SfOrgConnectMock().add(200, LOGIN_OK).add(200, QUERY_OK));
        SfOrgAction_Query.Request req = new SfOrgAction_Query.Request();
        req.username = 'user@example.com';
        req.password = 'secret';
        req.isSandbox = 'true';
        req.soql = 'SELECT Id, Name FROM Account LIMIT 10';
        Test.startTest();
        List<SfOrgAction_Query.Response> res = SfOrgAction_Query.run(new List<SfOrgAction_Query.Request>{ req });
        Test.stopTest();
        System.assertEquals(true, res[0].success);
        System.assertEquals(1, res[0].recordCount);
        System.assert(res[0].detailsJson.contains('Acme'));
    }

    @isTest
    static void queryRejectsUnsafeSoql() {
        SfOrgAction_Query.Request req = new SfOrgAction_Query.Request();
        req.username = 'user@example.com';
        req.password = 'secret';
        req.soql = 'DELETE FROM Account';
        Test.startTest();
        List<SfOrgAction_Query.Response> res = SfOrgAction_Query.run(new List<SfOrgAction_Query.Request>{ req });
        Test.stopTest();
        System.assertEquals(false, res[0].success);
        System.assert(res[0].message.contains('read-only'));
    }

    @isTest
    static void listObjectsSuccess() {
        Test.setMock(HttpCalloutMock.class, new SfOrgConnectMock().add(200, LOGIN_OK).add(200, SOBJECTS_OK));
        SfOrgAction_ListObjects.Request req = new SfOrgAction_ListObjects.Request();
        req.username = 'user@example.com';
        req.password = 'secret';
        Test.startTest();
        List<SfOrgAction_ListObjects.Response> res = SfOrgAction_ListObjects.run(
            new List<SfOrgAction_ListObjects.Request>{ req }
        );
        Test.stopTest();
        System.assertEquals(true, res[0].success);
        System.assertEquals(3, res[0].recordCount);
        System.assert(res[0].detailsJson.contains('Account'));
    }

    @isTest
    static void getRecordsSuccess() {
        Test.setMock(HttpCalloutMock.class, new SfOrgConnectMock().add(200, LOGIN_OK).add(200, QUERY_OK));
        SfOrgAction_GetRecords.Request req = new SfOrgAction_GetRecords.Request();
        req.username = 'user@example.com';
        req.password = 'secret';
        req.objectApiName = 'Account';
        req.fields = 'Id, Name';
        req.recordLimit = '5';
        Test.startTest();
        List<SfOrgAction_GetRecords.Response> res = SfOrgAction_GetRecords.run(
            new List<SfOrgAction_GetRecords.Request>{ req }
        );
        Test.stopTest();
        System.assertEquals(true, res[0].success);
        System.assertEquals(1, res[0].recordCount);
    }

    @isTest
    static void getRecordsInvalidObject() {
        SfOrgAction_GetRecords.Request req = new SfOrgAction_GetRecords.Request();
        req.username = 'user@example.com';
        req.password = 'secret';
        req.objectApiName = 'Account WHERE Id != null';
        Test.startTest();
        List<SfOrgAction_GetRecords.Response> res = SfOrgAction_GetRecords.run(
            new List<SfOrgAction_GetRecords.Request>{ req }
        );
        Test.stopTest();
        System.assertEquals(false, res[0].success);
        System.assert(res[0].message.contains('object API name'));
    }

    @isTest
    static void instanceFromServerUrl() {
        System.assertEquals(
            'https://example.my.salesforce.com',
            SfOrgConnectClient.instanceFromServerUrl(
                'https://example.my.salesforce.com/services/Soap/u/62.0/00Dxx'
            )
        );
        System.assertEquals(null, SfOrgConnectClient.instanceFromServerUrl(null));
        System.assertEquals(
            'https://example.my.salesforce.com',
            SfOrgConnectClient.instanceFromServerUrl('https://example.my.salesforce.com')
        );
        System.assertEquals('not-a-url', SfOrgConnectClient.instanceFromServerUrl('not-a-url'));
    }

    @isTest
    static void restGetRequiresSession() {
        Boolean threw = false;
        try {
            SfOrgConnectClient.restGet(null, '/services/data/v62.0/sobjects');
        } catch (SfOrgConnectClient.CalloutException ex) {
            threw = true;
            System.assert(ex.getMessage().contains('Not connected'));
        }
        System.assertEquals(true, threw);
    }

    @isTest
    static void restGetParsesListAndMapErrors() {
        Test.setMock(
            HttpCalloutMock.class,
            new SfOrgConnectMock()
                .add(400, '[{"message":"MALFORMED_QUERY"}]')
                .add(401, '{"message":"Unauthorized endpoint"}')
                .add(500, '')
                .add(400, '{"message":"' + longText(410) + '"}')
                .add(400, 'not-json')
                .add(200, '{"ok":true}')
        );
        SfOrgConnectClient.Session session = new SfOrgConnectClient.Session();
        session.sessionId = '00DxxSESSION';
        session.instanceUrl = 'https://example.my.salesforce.com';

        Boolean malformed = false;
        try {
            SfOrgConnectClient.restGet(session, 'services/data/v62.0/query');
        } catch (SfOrgConnectClient.CalloutException ex) {
            malformed = ex.getMessage().contains('MALFORMED_QUERY');
        }
        System.assertEquals(true, malformed);

        Boolean unauthorized = false;
        try {
            SfOrgConnectClient.restGet(session, '/services/data/v62.0/query');
        } catch (SfOrgConnectClient.CalloutException ex) {
            unauthorized = ex.getMessage().contains('Remote Site Setting');
        }
        System.assertEquals(true, unauthorized);

        Boolean emptyBody = false;
        try {
            SfOrgConnectClient.restGet(session, '/services/data/v62.0/query');
        } catch (SfOrgConnectClient.CalloutException ex) {
            emptyBody = ex.getMessage().contains('No response body');
        }
        System.assertEquals(true, emptyBody);

        Boolean truncated = false;
        try {
            SfOrgConnectClient.restGet(session, '/services/data/v62.0/query');
        } catch (SfOrgConnectClient.CalloutException ex) {
            truncated = true;
        }
        System.assertEquals(true, truncated);

        Boolean notJson = false;
        try {
            SfOrgConnectClient.restGet(session, '/services/data/v62.0/query');
        } catch (SfOrgConnectClient.CalloutException ex) {
            notJson = ex.getMessage().contains('not-json');
        }
        System.assertEquals(true, notJson);

        SfOrgConnectClient.Response ok = SfOrgConnectClient.restGet(session, '/services/data/v62.0/sobjects');
        System.assertEquals(true, ok.isSuccess);
    }

    @isTest
    static void loginFaultOnSuccessStatusAndEmptyBody() {
        Test.setMock(HttpCalloutMock.class, new SfOrgConnectMock().add(200, LOGIN_FAULT));
        Boolean faultOn200 = false;
        try {
            SfOrgConnectClient.login('user@example.com', 'secret', 'login.salesforce.com');
        } catch (SfOrgConnectClient.CalloutException ex) {
            faultOn200 = ex.getMessage().contains('INVALID_LOGIN');
        }
        System.assertEquals(true, faultOn200);

        Test.setMock(HttpCalloutMock.class, new SfOrgConnectMock().add(500, ''));
        Boolean empty = false;
        try {
            SfOrgConnectClient.login('a&b<c>', 'p"q\'r', null);
        } catch (SfOrgConnectClient.CalloutException ex) {
            empty = ex.getMessage().contains('No response body');
        }
        System.assertEquals(true, empty);

        Test.setMock(
            HttpCalloutMock.class,
            new SfOrgConnectMock().add(500, '<exceptionMessage>' + longText(410) + '</exceptionMessage>')
        );
        Boolean longFault = false;
        try {
            SfOrgConnectClient.login('user@example.com', 'secret', 'test.salesforce.com');
        } catch (SfOrgConnectClient.CalloutException ex) {
            longFault = ex.getMessage().contains('Salesforce login failed');
        }
        System.assertEquals(true, longFault);
    }

    @isTest
    static void queryReportsUnauthorizedEndpoint() {
        Test.setMock(
            HttpCalloutMock.class,
            new SfOrgConnectMock().add(200, LOGIN_OK).add(401, '{"message":"Unauthorized endpoint"}')
        );
        SfOrgAction_Query.Request req = new SfOrgAction_Query.Request();
        req.username = 'user@example.com';
        req.password = 'secret';
        req.soql = 'SELECT Id FROM Account LIMIT 1';
        Test.startTest();
        List<SfOrgAction_Query.Response> res = SfOrgAction_Query.run(new List<SfOrgAction_Query.Request>{ req });
        Test.stopTest();
        System.assertEquals(false, res[0].success);
        System.assert(res[0].message.contains('Remote Site Setting') || res[0].message.contains('Query failed'));
    }

    @isTest
    static void apiVersionIsSet() {
        System.assertEquals('62.0', SfOrgConnectClient.apiVersion());
    }

    @isTest
    static void buildPasswordAppendsTokenOnlyOnce() {
        System.assertEquals('pass', SfOrgConnectService.buildPassword('pass', null));
        System.assertEquals('pass', SfOrgConnectService.buildPassword('  pass  ', '   '));
        System.assertEquals('passTOKEN', SfOrgConnectService.buildPassword('pass', 'TOKEN'));
        System.assertEquals('passTOKEN', SfOrgConnectService.buildPassword('pass', '  TOKEN  '));
        System.assertEquals('passTOKEN', SfOrgConnectService.buildPassword('passTOKEN', 'TOKEN'));
        System.assertEquals('TOKEN', SfOrgConnectService.buildPassword(null, 'TOKEN'));
    }

    @isTest
    static void connectAcceptsSeparateSecurityToken() {
        Test.setMock(HttpCalloutMock.class, new SfOrgConnectMock().add(200, LOGIN_OK));
        SfOrgAction_Connect.Request req = new SfOrgAction_Connect.Request();
        req.username = 'user@example.com';
        req.password = 'secret';
        req.securityToken = 'TOKEN123';
        Test.startTest();
        List<SfOrgAction_Connect.Response> res = SfOrgAction_Connect.run(
            new List<SfOrgAction_Connect.Request>{ req }
        );
        Test.stopTest();
        System.assertEquals(true, res[0].success);
        System.assertEquals('Demo Org', res[0].organizationName);
    }

    @isTest
    static void getRecordsPassesSecurityToken() {
        Test.setMock(HttpCalloutMock.class, new SfOrgConnectMock().add(200, LOGIN_OK).add(200, QUERY_OK));
        SfOrgAction_GetRecords.Request req = new SfOrgAction_GetRecords.Request();
        req.username = 'user@example.com';
        req.password = 'secret';
        req.securityToken = 'TOKEN123';
        req.objectApiName = 'Account';
        Test.startTest();
        List<SfOrgAction_GetRecords.Response> res = SfOrgAction_GetRecords.run(
            new List<SfOrgAction_GetRecords.Request>{ req }
        );
        Test.stopTest();
        System.assertEquals(true, res[0].success);
        System.assertEquals(1, res[0].recordCount);
    }

    @isTest
    static void listObjectsPassesSecurityToken() {
        Test.setMock(HttpCalloutMock.class, new SfOrgConnectMock().add(200, LOGIN_OK).add(200, SOBJECTS_OK));
        SfOrgAction_ListObjects.Request req = new SfOrgAction_ListObjects.Request();
        req.username = 'user@example.com';
        req.password = 'secret';
        req.securityToken = 'TOKEN123';
        Test.startTest();
        List<SfOrgAction_ListObjects.Response> res = SfOrgAction_ListObjects.run(
            new List<SfOrgAction_ListObjects.Request>{ req }
        );
        Test.stopTest();
        System.assertEquals(true, res[0].success);
        System.assertEquals(3, res[0].recordCount);
    }

    @isTest
    static void startOAuthRequiresConfig() {
        Test.startTest();
        List<SfOrgAction_StartOAuth.Response> res = SfOrgAction_StartOAuth.run(
            new List<SfOrgAction_StartOAuth.Request>{ new SfOrgAction_StartOAuth.Request() }
        );
        Test.stopTest();
        System.assertEquals(false, res[0].success);
        System.assert(res[0].message.contains('OAuth is not configured'));
    }

    @isTest
    static void startAndCompleteOAuthThenQuery() {
        upsertOAuthConfig();
        List<SfOrgAction_StartOAuth.Response> started = SfOrgAction_StartOAuth.run(
            new List<SfOrgAction_StartOAuth.Request>{ new SfOrgAction_StartOAuth.Request() }
        );
        System.assertEquals(true, started[0].success);
        System.assertNotEquals(null, started[0].connectionId);
        System.assert(started[0].authorizeUrl.contains('login.salesforce.com/services/oauth2/authorize'));
        System.assert(started[0].authorizeUrl.contains('CLIENTKEY'));
        System.assert(started[0].authorizeUrl.contains('code_challenge_method=S256'));
        System.assert(started[0].authorizeUrl.contains(EncodingUtil.urlEncode('/apex/SfOrgOAuthCallback', 'UTF-8')));

        SfOrgAction_CheckOAuth.Request pendingReq = new SfOrgAction_CheckOAuth.Request();
        pendingReq.connectionId = started[0].connectionId;
        List<SfOrgAction_CheckOAuth.Response> pending = SfOrgAction_CheckOAuth.run(
            new List<SfOrgAction_CheckOAuth.Request>{ pendingReq }
        );
        System.assertEquals(false, pending[0].success);
        System.assert(pending[0].message.contains('pending'));

        Test.setMock(
            HttpCalloutMock.class,
            new SfOrgConnectMock()
                .add(
                    200,
                    '{"access_token":"ATOKEN","refresh_token":"RTOKEN","instance_url":"https://example.my.salesforce.com","id":"https://login.salesforce.com/id/00DxxORG/005xxUSER"}'
                )
                .add(200, '{"preferred_username":"user@example.com","organization_id":"00DxxORG"}')
        );
        PageReference callbackPage = Page.SfOrgOAuthCallback;
        callbackPage.getParameters().put('code', 'AUTHCODE');
        callbackPage.getParameters().put('state', started[0].connectionId);
        Test.setCurrentPage(callbackPage);
        Test.startTest();
        SfOrgOAuthCallbackController ctrl = new SfOrgOAuthCallbackController();
        ctrl.complete();
        Test.stopTest();
        System.assertEquals('Connected', ctrl.heading);

        SfOrgAction_CheckOAuth.Request checkReq = new SfOrgAction_CheckOAuth.Request();
        checkReq.connectionId = started[0].connectionId;
        List<SfOrgAction_CheckOAuth.Response> authorized = SfOrgAction_CheckOAuth.run(
            new List<SfOrgAction_CheckOAuth.Request>{ checkReq }
        );
        System.assertEquals(true, authorized[0].success);
        System.assertEquals('user@example.com', authorized[0].userName);
    }

    @isTest
    static void queryUsesStoredOAuthConnection() {
        upsertOAuthConfig();
        Sf_Org_Connection__c row = new Sf_Org_Connection__c();
        row.Connection_Key__c = 'oauthconn1';
        row.Status__c = 'Authorized';
        row.Login_Host__c = 'login.salesforce.com';
        row.Instance_Url__c = 'https://example.my.salesforce.com';
        row.Access_Token_Enc__c = SfOrgOAuthService.encryptValue('ATOKEN');
        row.Org_User_Name__c = 'user@example.com';
        insert row;

        Test.setMock(HttpCalloutMock.class, new SfOrgConnectMock().add(200, QUERY_OK));
        SfOrgAction_Query.Request queryReq = new SfOrgAction_Query.Request();
        queryReq.connectionId = 'oauthconn1';
        queryReq.soql = 'SELECT Id, Name FROM Account LIMIT 10';
        Test.startTest();
        List<SfOrgAction_Query.Response> queried = SfOrgAction_Query.run(
            new List<SfOrgAction_Query.Request>{ queryReq }
        );
        Test.stopTest();
        System.assertEquals(true, queried[0].success);
        System.assertEquals(1, queried[0].recordCount);
    }

    @isTest
    static void oauthRestCallbackDenied() {
        upsertOAuthConfig();
        Sf_Org_Connection__c row = new Sf_Org_Connection__c();
        row.Connection_Key__c = 'statekey2';
        row.Status__c = 'Pending';
        row.Login_Host__c = 'login.salesforce.com';
        insert row;

        RestRequest req = new RestRequest();
        req.requestURI = '/services/apexrest/sforg/oauth/callback';
        req.httpMethod = 'GET';
        req.addParameter('state', 'statekey2');
        req.addParameter('error', 'access_denied');
        RestContext.request = req;
        RestContext.response = new RestResponse();
        SfOrgOAuthCallbackRest.doGet();
        System.assertEquals(400, RestContext.response.statusCode);
    }

    @isTest
    static void oauthCallbackDenied() {
        upsertOAuthConfig();
        Sf_Org_Connection__c row = new Sf_Org_Connection__c();
        row.Connection_Key__c = 'statekey1';
        row.Status__c = 'Pending';
        row.Login_Host__c = 'login.salesforce.com';
        insert row;
        SfOrgOAuthService.CallbackResult result = SfOrgOAuthService.completeAuthorization(
            null,
            'statekey1',
            'access_denied'
        );
        System.assertEquals(false, result.success);
        System.assert(result.message.contains('access_denied'));
    }

    private static void upsertOAuthConfig() {
        Sf_Org_OAuth_Secret__c cfg = Sf_Org_OAuth_Secret__c.getOrgDefaults();
        if (cfg == null) {
            cfg = new Sf_Org_OAuth_Secret__c();
        }
        cfg.SetupOwnerId = UserInfo.getOrganizationId();
        cfg.Consumer_Key__c = 'CLIENTKEY';
        cfg.Consumer_Secret__c = null;
        cfg.Callback_URL__c = null;
        upsert cfg;
    }

    private static String longText(Integer length) {
        String value = 'xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx';
        while (value.length() < length) {
            value += value;
        }
        return value.substring(0, length);
    }
}
