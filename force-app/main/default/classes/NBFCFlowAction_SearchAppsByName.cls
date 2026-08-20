public with sharing class NBFCFlowAction_SearchAppsByName {
    public class Request {
        @InvocableVariable(label='Applicant Name Search' required=true)
        public String applicantNameSearch;
    }
    public class Response {
        @InvocableVariable public String matchingApplications;
        @InvocableVariable public Integer matchCount;
        @InvocableVariable public Boolean recordFound;
        @InvocableVariable public String errorMessage;
    }

    @InvocableMethod(label='Search Applications By Name' description='NBFC Agentforce flow action wrapper')
    public static List<Response> run(List<Request> requests) {
        List<NBFCAgentFlowService.SearchApplicationsByNameRequest> svcReqs =
            new List<NBFCAgentFlowService.SearchApplicationsByNameRequest>();
        for (Request req : requests) {
            NBFCAgentFlowService.SearchApplicationsByNameRequest svcReq =
                new NBFCAgentFlowService.SearchApplicationsByNameRequest();
            svcReq.applicantNameSearch = req.applicantNameSearch;
            svcReqs.add(svcReq);
        }
        List<NBFCAgentFlowService.SearchApplicationsByNameResponse> svcRes =
            NBFCAgentFlowService.searchApplicationsByName(svcReqs);
        List<Response> results = new List<Response>();
        for (NBFCAgentFlowService.SearchApplicationsByNameResponse res : svcRes) {
            Response out = new Response();
            out.matchingApplications = res.matchingApplications;
            out.matchCount = res.matchCount;
            out.recordFound = res.recordFound;
            out.errorMessage = res.errorMessage;
            results.add(out);
        }
        return results;
    }
}
