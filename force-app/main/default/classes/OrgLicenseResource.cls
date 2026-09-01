/**
 * @description REST endpoint backing the site's license page.
 *
 *              Endpoint: GET /services/apexrest/org/licenses
 *
 *              UserLicense is a setup object that requires View Setup and
 *              Configuration to query, which site users must never hold. The
 *              service reads it in system mode behind a custom-permission check
 *              instead, so this endpoint stays safe to expose to the site.
 */
@RestResource(urlMapping='/org/licenses')
global with sharing class OrgLicenseResource {
  /**
   * @description Returns seat counts for the approved license allowlist.
   * @return One row per approved active license type; null with a 403 when the
   *         caller lacks View_Org_License_Summary.
   */
  @HttpGet
  global static List<OrgLicenseService.LicenseCapacity> getLicenses() {
    try {
      return OrgLicenseService.getLicenseCapacity();
    } catch (OrgLicenseService.OrgLicenseAccessException ex) {
      RestContext.response.statusCode = 403;
      return null;
    }
  }
}
