@isTest
private class NBFCSeedDataLoaderTest {
    @isTest
    static void testMinimalLoad() {
        Test.startTest();
        NBFCSeedDataLoader.LoadResult result = NBFCSeedDataLoader.load('minimal');
        Test.stopTest();
        System.assertNotEquals(null, result);
        System.assert(result.applicantsCreated >= 0);
        System.assert(result.productsCreated >= 0);
    }

    @isTest
    static void testInvocableLoad() {
        NBFCSeedDataLoader.LoadRequest req = new NBFCSeedDataLoader.LoadRequest();
        req.scenario = 'standard';
        req.applicantCount = 2;
        req.applicationsPerApplicant = 1;
        Test.startTest();
        List<NBFCSeedDataLoader.LoadResult> results = NBFCSeedDataLoader.loadInvocable(
            new List<NBFCSeedDataLoader.LoadRequest>{ req }
        );
        Test.stopTest();
        System.assertEquals(1, results.size());
        System.assert(results[0].applicationsCreated >= 0);
    }

    @isTest
    static void testDemoLoad() {
        Test.startTest();
        NBFCSeedDataLoader.LoadResult result = NBFCSeedDataLoader.load('demo');
        Test.stopTest();
        System.assertNotEquals(null, result.message);
    }
}
