@RestResource(urlMapping='/oauth-deploy/v1/*')
global without sharing class SfOrgDeployRest {
    @HttpGet
    global static void claimSession() {
        RestResponse response = RestContext.response;
        response.addHeader('Content-Type', 'application/json');
        try {
            requireAuthenticatedIntegrationUser();
            if (!Schema.sObjectType.Sf_Org_Deployment__c.isUpdateable()) {
                deny(403, 'The authenticated user cannot claim deployment requests.');
                return;
            }
            String rawId = RestContext.request.params.get('requestId');
            SfOrgDeployService.ClaimResult result = SfOrgDeployService.claim((Id) rawId);
            response.statusCode = 200;
            response.responseBody = Blob.valueOf(JSON.serialize(result));
        } catch (SfOrgDeployService.DeployException ex) {
            deny(409, ex.getMessage());
        } catch (Exception ex) {
            deny(400, 'Deployment session could not be claimed.');
        }
    }

    @HttpPost
    global static void updateStatus() {
        RestResponse response = RestContext.response;
        response.addHeader('Content-Type', 'application/json');
        try {
            requireAuthenticatedIntegrationUser();
            if (!Schema.sObjectType.Sf_Org_Deployment__c.isUpdateable()) {
                deny(403, 'The authenticated user cannot update deployment requests.');
                return;
            }
            String body = RestContext.request.requestBody == null
                ? ''
                : RestContext.request.requestBody.toString();
            SfOrgDeployService.StatusPayload payload = (SfOrgDeployService.StatusPayload) JSON.deserialize(
                body,
                SfOrgDeployService.StatusPayload.class
            );
            Sf_Org_Deployment__c result = SfOrgDeployService.applyStatus(payload);
            response.statusCode = 200;
            response.responseBody = Blob.valueOf(JSON.serialize(new Map<String, Object>{
                'success' => true,
                'referenceId' => result.Name,
                'status' => result.Status__c
            }));
        } catch (SfOrgDeployService.DeployException ex) {
            deny(400, ex.getMessage());
        } catch (Exception ex) {
            deny(400, 'Deployment status could not be updated.');
        }
    }

    private static void requireAuthenticatedIntegrationUser() {
        if (UserInfo.getUserType() == 'Guest') {
            throw new SfOrgDeployService.DeployException('Authentication required.');
        }
    }

    private static void deny(Integer statusCode, String message) {
        RestContext.response.statusCode = statusCode;
        RestContext.response.responseBody = Blob.valueOf(JSON.serialize(new Map<String, Object>{
            'success' => false,
            'message' => message
        }));
    }
}
