/**
 * Invocable orchestrator that creates agent stubs and kicks off the agent pipeline.
 */
public with sharing class AgentOrchestrator {
    private static final List<String> AGENT_NAMES = new List<String>{
        'Document Verification Agent',
        'Financial Health Agent',
        'Credit Risk Agent',
        'Compliance Agent',
        'Decision Agent'
    };

    @InvocableMethod(label='Run All NBFC Agents' description='Starts the full AI agent pipeline for loan applications')
    public static void runAllAgents(List<Id> loanAppIds) {
        if (loanAppIds == null || loanAppIds.isEmpty()) {
            return;
        }
        List<Agent_Check_Result__c> stubs = new List<Agent_Check_Result__c>();
        Integer order = 1;
        for (Id loanAppId : loanAppIds) {
            for (String agentName : AGENT_NAMES) {
                stubs.add(new Agent_Check_Result__c(
                    Loan_Application__c = loanAppId,
                    Agent_Name__c = agentName,
                    Agent_Run_Order__c = order,
                    Status__c = 'Pending'
                ));
                order++;
            }
        }
        if (!stubs.isEmpty()) {
            Database.insert(stubs, false);
        }
        for (Id loanAppId : loanAppIds) {
            if (!System.isFuture() && !System.isBatch()) {
                System.enqueueJob(new DocumentAgentQueueable(loanAppId));
            }
        }
    }
}
