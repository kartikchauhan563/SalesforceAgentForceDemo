@isTest
private class ApplicantDocumentTriggerHandlerTest {
    @TestSetup
    static void setupData() {
        Account applicant = NBFC_TestDataFactory.createPersonAccount();
        Loan_Product__c product = NBFC_TestDataFactory.createLoanProduct();
        NBFC_TestDataFactory.createLoanApplications(applicant, product, 3);
    }

    private static Id getLoanAppId() {
        return [SELECT Id FROM Loan_Application__c LIMIT 1].Id;
    }

    @isTest
    static void testDocumentUploadedCreatesHistory() {
        Id loanAppId = getLoanAppId();
        Applicant_Document__c doc = NBFC_TestDataFactory.createDocument(loanAppId, 'PAN Card', true);
        Test.startTest();
        ApplicantDocumentTriggerHandler.createHistoryRecord_DocUploaded(new List<Applicant_Document__c>{ doc });
        Test.stopTest();
        Integer count = [
            SELECT COUNT()
            FROM Loan_Application_History__c
            WHERE Loan_Application__c = :loanAppId
            AND Event_Type__c = 'Document Uploaded'
        ];
        System.assert(count > 0, 'Document upload history expected');
    }

    @isTest
    static void testExpiryDateFlagsIssue() {
        Id loanAppId = getLoanAppId();
        Applicant_Document__c doc = NBFC_TestDataFactory.createDocument(loanAppId, 'Aadhaar Card', false);
        doc.Expiry_Date__c = Date.today().addDays(-30);
        ApplicantDocumentTriggerHandler.validateExpiryDate(new List<Applicant_Document__c>{ doc });
        System.assertEquals('Expired', doc.Issue_Found__c);
        System.assertEquals(false, doc.Verified__c);
    }

    @isTest
    static void testAllDocsVerifiedUpdatesParent() {
        Id loanAppId = getLoanAppId();
        List<Applicant_Document__c> docs = [
            SELECT Id, Verified__c, Loan_Application__c
            FROM Applicant_Document__c
            WHERE Loan_Application__c = :loanAppId
            AND Is_Mandatory__c = TRUE
        ];
        if (docs.isEmpty()) {
            docs.add(NBFC_TestDataFactory.createDocument(loanAppId, 'PAN Card', true));
        }
        for (Applicant_Document__c doc : docs) {
            doc.Uploaded__c = true;
            doc.Verified__c = true;
            doc.Verification_Status__c = 'Verified';
        }
        Test.startTest();
        update docs;
        Test.stopTest();
        Loan_Application__c parent = [
            SELECT Sub_Status__c FROM Loan_Application__c WHERE Id = :loanAppId
        ];
        System.assertEquals(null, parent.Sub_Status__c);
    }

    @isTest
    static void testMissingDocsListUpdated() {
        Id loanAppId = getLoanAppId();
        Applicant_Document__c doc = NBFC_TestDataFactory.createDocument(loanAppId, 'Bank Statement', false);
        Test.startTest();
        ApplicantDocumentTriggerHandler.updateParentMissingDocsList(
            new List<Applicant_Document__c>{ doc }
        );
        Test.stopTest();
        Loan_Application__c parent = [
            SELECT Missing_Documents__c FROM Loan_Application__c WHERE Id = :loanAppId
        ];
        System.assertNotEquals(null, parent.Missing_Documents__c);
    }

    @isTest
    static void testBulkDocumentUpload() {
        Id loanAppId = getLoanAppId();
        List<Applicant_Document__c> docs = new List<Applicant_Document__c>();
        for (Integer i = 0; i < 50; i++) {
            docs.add(new Applicant_Document__c(
                Loan_Application__c = loanAppId,
                Document_Type__c = 'Bulk Doc ' + i,
                Is_Mandatory__c = false,
                Uploaded__c = false,
                Verified__c = false
            ));
        }
        insert docs;
        for (Applicant_Document__c doc : docs) {
            doc.Uploaded__c = true;
        }
        Test.startTest();
        update docs;
        Test.stopTest();
        System.assertEquals(50, [
            SELECT COUNT() FROM Applicant_Document__c
            WHERE Loan_Application__c = :loanAppId AND Uploaded__c = TRUE AND Document_Type__c LIKE 'Bulk Doc%'
        ]);
    }
}
