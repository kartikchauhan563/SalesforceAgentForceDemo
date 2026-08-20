public with sharing class NBFCFlowAction_GetMissingDocsReport {
    @InvocableMethod(label='Get Missing Documents Report' description='NBFC Agentforce flow action wrapper')
    public static List<NBFCAgentFlowService.GetMissingDocumentsReportResponse> run(
        List<NBFCAgentFlowService.GetMissingDocumentsReportRequest> requests
    ) {
        return NBFCAgentFlowService.getMissingDocumentsReport(requests);
    }
}