/**
 * @description Tests the OrgLicenseAgentAction authorization boundary, response
 *              shape, bulk contract, and empty-summary formatting.
 */
@IsTest
private class OrgLicenseAgentActionTest {
  @IsTest
  static void getBasicLicenseInformationReturnsAllowlistedSummary() {
    User authorizedUser = OrgLicenseTestData.createAuthorizedUser('licauth');

    System.runAs(authorizedUser) {
      Test.startTest();
      List<OrgLicenseAgentAction.Response> responses = OrgLicenseAgentAction.getBasicLicenseInformation(
        new List<OrgLicenseAgentAction.Request>{
          new OrgLicenseAgentAction.Request()
        }
      );
      Test.stopTest();

      System.assertEquals(
        1,
        responses.size(),
        'One request must produce one response'
      );
      System.assertNotEquals(
        null,
        responses[0].licenseSummary,
        'Summary must be populated'
      );
      System.assert(
        responses[0].licenseSummary.contains('total'),
        'The agent needs a deterministic total count'
      );
      System.assert(
        responses[0].licenseTypeCount > 0,
        'At least one approved active license type should exist'
      );
      System.assert(
        !responses[0]
          .licenseSummary.contains('Analytics Cloud Integration User'),
        'Non-approved license types must never be exposed'
      );
    }
  }

  @IsTest
  static void getBasicLicenseInformationPreservesBulkContract() {
    User authorizedUser = OrgLicenseTestData.createAuthorizedUser('licbulk');

    System.runAs(authorizedUser) {
      List<OrgLicenseAgentAction.Request> requests = new List<OrgLicenseAgentAction.Request>();
      for (Integer i = 0; i < 200; i++) {
        requests.add(new OrgLicenseAgentAction.Request());
      }

      Test.startTest();
      List<OrgLicenseAgentAction.Response> responses = OrgLicenseAgentAction.getBasicLicenseInformation(
        requests
      );
      Test.stopTest();

      System.assertEquals(
        200,
        responses.size(),
        'Every request must receive a response'
      );
    }
  }

  @IsTest
  static void getBasicLicenseInformationRejectsUnauthorizedUser() {
    User unauthorizedUser = OrgLicenseTestData.createUser('licdeny');

    System.runAs(unauthorizedUser) {
      Boolean wasRejected = false;
      Test.startTest();
      try {
        OrgLicenseAgentAction.getBasicLicenseInformation(
          new List<OrgLicenseAgentAction.Request>{
            new OrgLicenseAgentAction.Request()
          }
        );
      } catch (OrgLicenseService.OrgLicenseAccessException ex) {
        wasRejected = true;
        System.assert(
          ex.getMessage().contains('do not have permission'),
          'The rejection should explain the missing access'
        );
      }
      Test.stopTest();

      System.assert(
        wasRejected,
        'Users without the custom permission must be rejected'
      );
    }
  }

  @IsTest
  static void buildSummaryHandlesNoSupportedLicenses() {
    System.assertEquals(
      'No supported active user licenses were found.',
      OrgLicenseAgentAction.buildSummary(
        new List<OrgLicenseService.LicenseCapacity>()
      ),
      'An empty result must be explicit so the agent does not invent values'
    );
  }

}
