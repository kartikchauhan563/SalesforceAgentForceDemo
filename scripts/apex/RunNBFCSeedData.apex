// Run via: sf apex run --file scripts/apex/RunNBFCSeedData.apex
NBFCSeedDataLoader.LoadRequest req = new NBFCSeedDataLoader.LoadRequest();
req.scenario = 'standard';
req.applicantCount = 5;
req.applicationsPerApplicant = 1;

NBFCSeedDataLoader.LoadResult result = NBFCSeedDataLoader.load(req);
System.debug('NBFC Seed Load: ' + result.message);
System.debug('Applicants: ' + result.applicantsCreated);
System.debug('Products: ' + result.productsCreated);
System.debug('Applications: ' + result.applicationsCreated);
System.debug('Child records: ' + result.childRecordsCreated);
