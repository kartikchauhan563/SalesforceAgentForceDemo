public without sharing class SfOrgOAuthCallbackController {
    public String heading { get; private set; }
    public String detail { get; private set; }

    public SfOrgOAuthCallbackController() {
        heading = 'Finishing the connection';
        detail = 'Please wait.';
    }

    /**
     * Runs from the page action attribute rather than the constructor, because Visualforce
     * blocks DML during construction and this has to store the returned tokens.
     */
    public PageReference complete() {
        Map<String, String> params = ApexPages.currentPage() == null
            ? new Map<String, String>()
            : ApexPages.currentPage().getParameters();
        SfOrgOAuthService.CallbackResult result = SfOrgOAuthService.completeAuthorization(
            params.get('code'),
            params.get('state'),
            params.get('error')
        );
        heading = result.success ? 'Connected' : 'Authorization did not complete';
        detail = result.message;
        return null;
    }
}
