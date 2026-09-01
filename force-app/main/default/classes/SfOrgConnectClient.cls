public with sharing class SfOrgConnectClient {
    public class CalloutException extends Exception {
    }

    public class Session {
        public String sessionId;
        public String instanceUrl;
        public String userId;
        public String userName;
        public String organizationId;
        public String organizationName;
    }

    public class Response {
        public Integer statusCode;
        public String body;
        public Boolean isSuccess;
    }

    private static final String API_VERSION = '62.0';

    public static Session login(String username, String password, String loginHost) {
        String host = String.isBlank(loginHost) ? 'login.salesforce.com' : loginHost.trim();
        String envelope =
            '<?xml version="1.0" encoding="utf-8"?>' +
            '<env:Envelope xmlns:xsd="http://www.w3.org/2001/XMLSchema" ' +
            'xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" ' +
            'xmlns:env="http://schemas.xmlsoap.org/soap/envelope/">' +
            '<env:Body><n1:login xmlns:n1="urn:partner.soap.sforce.com">' +
            '<n1:username>' +
            xmlEscape(username) +
            '</n1:username><n1:password>' +
            xmlEscape(password) +
            '</n1:password></n1:login></env:Body></env:Envelope>';

        HttpRequest req = new HttpRequest();
        req.setMethod('POST');
        req.setEndpoint('https://' + host + '/services/Soap/u/' + API_VERSION);
        req.setHeader('Content-Type', 'text/xml; charset=UTF-8');
        req.setHeader('SOAPAction', 'login');
        req.setTimeout(120000);
        req.setBody(envelope);

        HttpResponse httpRes;
        try {
            httpRes = new Http().send(req);
        } catch (System.CalloutException ex) {
            throw new CalloutException(blockedEndpoint('https://' + host, ex));
        }
        if (httpRes.getStatusCode() < 200 || httpRes.getStatusCode() >= 300) {
            throw new CalloutException(soapFault(httpRes.getBody(), httpRes.getStatusCode()));
        }
        Session session = parseLogin(httpRes.getBody());
        if (session == null || String.isBlank(session.sessionId) || String.isBlank(session.instanceUrl)) {
            throw new CalloutException(soapFault(httpRes.getBody(), httpRes.getStatusCode()));
        }
        return session;
    }

    public static Response restGet(Session session, String pathAndQuery) {
        if (session == null || String.isBlank(session.sessionId) || String.isBlank(session.instanceUrl)) {
            throw new CalloutException('Not connected to a Salesforce org.');
        }
        String path = pathAndQuery.startsWith('/') ? pathAndQuery : '/' + pathAndQuery;
        HttpRequest req = new HttpRequest();
        req.setMethod('GET');
        req.setEndpoint(session.instanceUrl + path);
        req.setHeader('Authorization', 'Bearer ' + session.sessionId);
        req.setHeader('Accept', 'application/json');
        req.setTimeout(120000);

        HttpResponse httpRes;
        try {
            httpRes = new Http().send(req);
        } catch (System.CalloutException ex) {
            throw new CalloutException(blockedEndpoint(session.instanceUrl, ex));
        }
        Response res = new Response();
        res.statusCode = httpRes.getStatusCode();
        res.body = httpRes.getBody();
        res.isSuccess = res.statusCode >= 200 && res.statusCode < 300;
        if (!res.isSuccess) {
            throw new CalloutException(formatRestError(path, res));
        }
        return res;
    }

    public static String apiVersion() {
        return API_VERSION;
    }

    public static Map<String, Object> postForm(String endpoint, String body) {
        HttpRequest req = new HttpRequest();
        req.setMethod('POST');
        req.setEndpoint(endpoint);
        req.setHeader('Content-Type', 'application/x-www-form-urlencoded');
        req.setHeader('Accept', 'application/json');
        req.setTimeout(120000);
        req.setBody(body);
        HttpResponse httpRes;
        try {
            httpRes = new Http().send(req);
        } catch (System.CalloutException ex) {
            throw new CalloutException(blockedEndpoint(endpoint, ex));
        }
        if (httpRes.getStatusCode() < 200 || httpRes.getStatusCode() >= 300) {
            throw new CalloutException(formatRestError(endpoint, toResponse(httpRes)));
        }
        if (String.isBlank(httpRes.getBody())) {
            throw new CalloutException('OAuth token response was empty.');
        }
        Object parsed = JSON.deserializeUntyped(httpRes.getBody());
        if (!(parsed instanceof Map<String, Object>)) {
            throw new CalloutException('OAuth token response was not JSON.');
        }
        return (Map<String, Object>) parsed;
    }

    public static Session sessionFromOAuth(Map<String, Object> token) {
        Session session = new Session();
        session.sessionId = stringVal(token, 'access_token');
        session.instanceUrl = stringVal(token, 'instance_url');
        String idUrl = stringVal(token, 'id');
        if (!String.isBlank(idUrl) && idUrl.contains('/id/')) {
            List<String> parts = idUrl.substringAfter('/id/').split('/');
            if (!parts.isEmpty()) {
                session.organizationId = parts[0];
            }
            if (parts.size() > 1) {
                session.userId = parts[1];
            }
        }
        return session;
    }

    private static Response toResponse(HttpResponse httpRes) {
        Response res = new Response();
        res.statusCode = httpRes.getStatusCode();
        res.body = httpRes.getBody();
        res.isSuccess = res.statusCode >= 200 && res.statusCode < 300;
        return res;
    }

    private static String stringVal(Map<String, Object> values, String key) {
        if (values == null || !values.containsKey(key) || values.get(key) == null) {
            return null;
        }
        return String.valueOf(values.get(key));
    }

    private static Session parseLogin(String body) {
        if (String.isBlank(body) || body.contains('<faultstring>') || body.contains('<soapenv:Fault')) {
            return null;
        }
        Session session = new Session();
        session.sessionId = xmlTag(body, 'sessionId');
        session.userId = xmlTag(body, 'userId');
        session.userName = xmlTag(body, 'userName');
        session.organizationId = xmlTag(body, 'organizationId');
        session.organizationName = xmlTag(body, 'organizationName');
        String serverUrl = xmlTag(body, 'serverUrl');
        session.instanceUrl = instanceFromServerUrl(serverUrl);
        return session;
    }

    public static String instanceFromServerUrl(String serverUrl) {
        if (String.isBlank(serverUrl)) {
            return null;
        }
        Integer servicesAt = serverUrl.indexOf('/services/');
        if (servicesAt > 0) {
            return serverUrl.substring(0, servicesAt);
        }
        try {
            Url parsed = new Url(serverUrl);
            return parsed.getProtocol() + '://' + parsed.getHost();
        } catch (Exception ignore) {
            return serverUrl;
        }
    }

    private static String xmlTag(String xml, String tag) {
        String needle = tag + '>';
        Integer start = xml.indexOf(needle);
        if (start < 0) {
            return null;
        }
        start += needle.length();
        Integer finish = xml.indexOf('<', start);
        if (finish < 0) {
            return null;
        }
        return xml.substring(start, finish).trim();
    }

    private static String blockedEndpoint(String endpoint, System.CalloutException ex) {
        String detail = ex.getMessage() == null ? '' : ex.getMessage();
        if (detail.contains('Unauthorized endpoint')) {
            return 'This org is not allowed to call ' +
                endpoint +
                '. In Setup > Security > Remote Site Settings, add a remote site with URL ' +
                endpoint +
                ', then try again.';
        }
        return 'Callout to ' + endpoint + ' failed: ' + detail;
    }

    private static String soapFault(String body, Integer statusCode) {
        String fault = xmlTag(body, 'faultstring');
        if (String.isBlank(fault)) {
            fault = xmlTag(body, 'exceptionMessage');
        }
        if (String.isBlank(fault)) {
            fault = String.isBlank(body) ? 'No response body' : (body.length() > 400 ? body.substring(0, 400) : body);
        }
        return 'Salesforce login failed (' + statusCode + '): ' + fault;
    }

    private static String formatRestError(String path, Response res) {
        String detail = res.body;
        if (!String.isBlank(detail)) {
            try {
                Object parsed = JSON.deserializeUntyped(detail);
                if (parsed instanceof List<Object>) {
                    List<Object> items = (List<Object>) parsed;
                    if (!items.isEmpty() && items[0] instanceof Map<String, Object>) {
                        Map<String, Object> first = (Map<String, Object>) items[0];
                        if (first.containsKey('message')) {
                            detail = String.valueOf(first.get('message'));
                        }
                    }
                } else if (parsed instanceof Map<String, Object>) {
                    Map<String, Object> mapBody = (Map<String, Object>) parsed;
                    if (mapBody.containsKey('message')) {
                        detail = String.valueOf(mapBody.get('message'));
                    }
                }
            } catch (Exception ignore) {
            }
            if (detail.length() > 400) {
                detail = detail.substring(0, 400);
            }
        } else {
            detail = 'No response body';
        }
        if (res.statusCode == 401 || (detail != null && detail.contains('Unauthorized endpoint'))) {
            return 'The target org instance is not allowed for callouts. Ask an admin to add a Remote Site Setting for the org My Domain, then try again. ' +
                detail;
        }
        return 'Salesforce GET ' + path + ' failed (' + res.statusCode + '): ' + detail;
    }

    private static String xmlEscape(String value) {
        if (value == null) {
            return '';
        }
        return value.replace('&', '&amp;')
            .replace('<', '&lt;')
            .replace('>', '&gt;')
            .replace('"', '&quot;')
            .replace('\'', '&apos;');
    }
}
