/**
 * @description Read-only Agentforce action that returns a deliberately narrow
 *              summary of user-license capacity. Access requires the
 *              View_Org_License_Summary custom permission.
 */
public with sharing class OrgLicenseAgentAction {
  /**
   * @description Returns active license totals for the approved license allowlist.
   * @param requests Agentforce invocation requests. Each request receives the same
   *                 current org-level summary.
   * @return One response per request containing a plain-text license summary.
   */
  @InvocableMethod(
    label='Get Basic Org License Information'
    description='Returns read-only totals, used counts, and remaining counts for approved Salesforce user-license types.'
  )
  public static List<Response> getBasicLicenseInformation(
    List<Request> requests
  ) {
    List<Request> safeRequests = (requests == null || requests.isEmpty())
      ? new List<Request>{ new Request() }
      : requests;

    List<OrgLicenseService.LicenseCapacity> licenses = OrgLicenseService.getLicenseCapacity();

    String summary = buildSummary(licenses);
    List<Response> responses = new List<Response>();
    for (Integer i = 0; i < safeRequests.size(); i++) {
      responses.add(new Response(summary, licenses.size()));
    }
    return responses;
  }

  /**
   * @description Formats allowlisted license rows for reliable Agentforce grounding.
   * @param licenses License capacity returned from the shared service.
   * @return A compact, deterministic plain-text summary.
   */
  @TestVisible
  private static String buildSummary(
    List<OrgLicenseService.LicenseCapacity> licenses
  ) {
    if (licenses.isEmpty()) {
      return 'No supported active user licenses were found.';
    }

    List<String> lines = new List<String>();
    for (OrgLicenseService.LicenseCapacity licenseRecord : licenses) {
      lines.add(
        licenseRecord.name +
          ': total ' +
          licenseRecord.total +
          ', used ' +
          licenseRecord.used +
          ', remaining ' +
          licenseRecord.remaining +
          '.'
      );
    }
    return String.join(lines, '\n');
  }

  /**
   * @description Input contract reserved for future non-sensitive filters.
   */
  public class Request {
    @InvocableVariable(
      label='Request License Summary'
      description='Set to true to request the approved basic organization license summary.'
    )
    public Boolean requestSummary;
  }

  /**
   * @description Output returned to Agentforce for response generation.
   */
  public class Response {
    @InvocableVariable(
      label='License Summary'
      description='Approved user-license totals, usage, and remaining capacity.'
    )
    public String licenseSummary;

    @InvocableVariable(
      label='License Type Count'
      description='Number of approved active license types included in the summary.'
    )
    public Integer licenseTypeCount;

    /**
     * @description Creates an Agentforce response.
     * @param licenseSummary Approved formatted license information.
     * @param licenseTypeCount Number of license types represented.
     */
    public Response(String licenseSummary, Integer licenseTypeCount) {
      this.licenseSummary = licenseSummary;
      this.licenseTypeCount = licenseTypeCount;
    }
  }
}
