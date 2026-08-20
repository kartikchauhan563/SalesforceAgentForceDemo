/**
 * Account helpers for orgs with or without Person Accounts enabled.
 */
public with sharing class AccountFieldHelper {
    private static Boolean personAccountsEnabled;

    public static Boolean hasPersonAccounts() {
        if (personAccountsEnabled == null) {
            Schema.RecordTypeInfo personRt = Schema.SObjectType.Account.getRecordTypeInfosByDeveloperName()
                .get('PersonAccount');
            personAccountsEnabled = personRt != null && personRt.isAvailable();
        }
        return personAccountsEnabled;
    }

    public static Boolean hasField(String fieldName) {
        return Schema.SObjectType.Account.fields.getMap().containsKey(fieldName.toLowerCase());
    }

    public static Date getBirthdate(Account acc) {
        if (acc == null || !hasField('PersonBirthdate')) {
            return null;
        }
        return (Date) acc.get('PersonBirthdate');
    }

    public static String getEmail(Account acc) {
        if (acc == null) {
            return null;
        }
        if (hasField('PersonEmail')) {
            return (String) acc.get('PersonEmail');
        }
        return null;
    }
}
