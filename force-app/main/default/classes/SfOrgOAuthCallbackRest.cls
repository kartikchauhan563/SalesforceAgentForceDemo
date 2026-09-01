@RestResource(urlMapping='/sforg/oauth/callback')
global without sharing class SfOrgOAuthCallbackRest {
    @HttpGet
    global static void doGet() {
        RestRequest req = RestContext.request;
        RestResponse res = RestContext.response;
        String code = req.params == null ? null : req.params.get('code');
        String state = req.params == null ? null : req.params.get('state');
        String errorParam = req.params == null ? null : req.params.get('error');
        SfOrgOAuthService.CallbackResult result = SfOrgOAuthService.completeAuthorization(code, state, errorParam);
        res.statusCode = result.success ? 200 : 400;
        res.addHeader('Content-Type', 'text/html; charset=UTF-8');
        String heading = result.success ? 'Connected' : 'Authorization did not complete';
        res.responseBody = Blob.valueOf(
            '<html><body style="font-family:Arial,sans-serif;max-width:560px;margin:48px auto;">' +
                '<h1>' +
                heading.escapeHtml4() +
                '</h1><p>' +
                String.valueOf(result.message).escapeHtml4() +
                '</p><p>You can close this tab and return to the agent.</p></body></html>'
        );
    }
}
