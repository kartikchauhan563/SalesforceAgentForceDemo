/**
 * @description Read-only access to a deliberately narrow summary of user-license
 *              capacity. The Agentforce action and the site's REST endpoint both
 *              read licenses through here, so a conversational answer and the
 *              license page can never disagree.
 *
 *              Global because Apex REST method signatures may only reference
 *              global types; see OrgLicenseResource.
 */
global with sharing class OrgLicenseService {
  private static final Set<String> SUPPORTED_LICENSE_NAMES = new Set<String>{
    'Customer Community',
    'Customer Community Plus',
    'Einstein Agent',
    'External Einstein Agent',
    'External Identity',
    'Salesforce',
    'Salesforce Platform'
  };

  /**
   * @description Returns seat counts for the approved license allowlist.
   *              The setup-object query intentionally runs in system mode after an
   *              explicit custom-permission check, so portal users don't need the
   *              broad View Setup and Configuration permission.
   * @return One row per approved active license type, ordered by name.
   * @throws OrgLicenseAccessException When the caller lacks View_Org_License_Summary.
   */
  public static List<LicenseCapacity> getLicenseCapacity() {
    if (!FeatureManagement.checkPermission('View_Org_License_Summary')) {
      throw new OrgLicenseAccessException(
        'You do not have permission to view organization license information.'
      );
    }

    List<LicenseCapacity> capacity = new List<LicenseCapacity>();
    for (UserLicense licenseRecord : [
      SELECT Name, TotalLicenses, UsedLicenses
      FROM UserLicense
      WHERE Name IN :SUPPORTED_LICENSE_NAMES AND Status = 'Active'
      WITH SYSTEM_MODE
      ORDER BY Name
      LIMIT 20
    ]) {
      capacity.add(new LicenseCapacity(licenseRecord));
    }
    return capacity;
  }

  /**
   * @description Seat counts for one approved license type.
   */
  global class LicenseCapacity {
    global String name;
    global Integer total;
    global Integer used;
    global Integer remaining;

    /**
     * @description Derives remaining capacity from a queried license row.
     * @param licenseRecord An approved active UserLicense.
     */
    private LicenseCapacity(UserLicense licenseRecord) {
      this.name = licenseRecord.Name;
      this.total = licenseRecord.TotalLicenses == null
        ? 0
        : licenseRecord.TotalLicenses;
      this.used = licenseRecord.UsedLicenses == null
        ? 0
        : licenseRecord.UsedLicenses;
      this.remaining = Math.max(0, this.total - this.used);
    }
  }

  /**
   * @description Raised when the caller lacks the required custom permission.
   */
  public class OrgLicenseAccessException extends Exception {
  }
}
