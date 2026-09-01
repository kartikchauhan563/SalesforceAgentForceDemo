/**
 * @description Shared setup for the org-license tests: standard users with and
 *              without the View_Org_License_Summary custom permission.
 */
@IsTest
public class OrgLicenseTestData {
  /**
   * @description Creates a standard user holding the least-privilege license
   *              permission set.
   * @param aliasPrefix Short unique prefix for username and alias generation.
   * @return Inserted user that may read the license summary.
   */
  public static User createAuthorizedUser(String aliasPrefix) {
    User testUser = createUser(aliasPrefix);
    PermissionSet accessPermissionSet = [
      SELECT Id
      FROM PermissionSet
      WHERE Name = 'Org_License_Agent_User'
      LIMIT 1
    ];
    insert new PermissionSetAssignment(
      AssigneeId = testUser.Id,
      PermissionSetId = accessPermissionSet.Id
    );
    return testUser;
  }

  /**
   * @description Creates a standard user with no license access.
   * @param aliasPrefix Short unique prefix for username and alias generation.
   * @return Inserted test user.
   */
  public static User createUser(String aliasPrefix) {
    Profile standardProfile = [
      SELECT Id
      FROM Profile
      WHERE Name = 'Standard User'
      LIMIT 1
    ];
    String uniqueValue =
      aliasPrefix +
      String.valueOf(DateTime.now().getTime()) +
      String.valueOf(Crypto.getRandomInteger()).replace('-', '');
    User testUser = new User(
      Alias = aliasPrefix.left(8),
      Email = uniqueValue + '@example.com',
      EmailEncodingKey = 'UTF-8',
      LastName = 'License Tester',
      LanguageLocaleKey = 'en_US',
      LocaleSidKey = 'en_US',
      ProfileId = standardProfile.Id,
      TimeZoneSidKey = 'America/Los_Angeles',
      Username = uniqueValue + '@example.com'
    );
    insert testUser;
    return testUser;
  }
}
