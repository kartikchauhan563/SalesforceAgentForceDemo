/**
 * @description Tests the license REST endpoint's authorization boundary and the
 *              seat counts it reports.
 */
@IsTest
private class OrgLicenseResourceTest {
  @IsTest
  static void getLicensesReturnsAllowlistedCapacity() {
    User authorizedUser = OrgLicenseTestData.createAuthorizedUser('licrest');

    System.runAs(authorizedUser) {
      RestContext.response = new RestResponse();

      Test.startTest();
      List<OrgLicenseService.LicenseCapacity> licenses = OrgLicenseResource.getLicenses();
      Test.stopTest();

      System.assertNotEquals(
        null,
        licenses,
        'An authorized caller must receive license data'
      );
      System.assert(
        !licenses.isEmpty(),
        'At least one approved active license type should exist'
      );
      for (OrgLicenseService.LicenseCapacity licenseRow : licenses) {
        System.assertEquals(
          Math.max(0, licenseRow.total - licenseRow.used),
          licenseRow.remaining,
          'Remaining capacity must be derived from total and used seats'
        );
        System.assertNotEquals(
          'Analytics Cloud Integration User',
          licenseRow.name,
          'Non-approved license types must never be exposed'
        );
      }
    }
  }

  @IsTest
  static void getLicensesRejectsUnauthorizedCaller() {
    User unauthorizedUser = OrgLicenseTestData.createUser('licrdny');

    System.runAs(unauthorizedUser) {
      RestContext.response = new RestResponse();

      Test.startTest();
      List<OrgLicenseService.LicenseCapacity> licenses = OrgLicenseResource.getLicenses();
      Test.stopTest();

      System.assertEquals(
        null,
        licenses,
        'Callers without the custom permission must receive no data'
      );
      System.assertEquals(
        403,
        RestContext.response.statusCode,
        'A missing custom permission must surface as forbidden, not as an error'
      );
    }
  }
}
