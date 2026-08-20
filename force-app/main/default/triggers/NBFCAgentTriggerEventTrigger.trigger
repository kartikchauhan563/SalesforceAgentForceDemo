trigger NBFCAgentTriggerEventTrigger on NBFC_Agent_Trigger__e (after insert) {
    NBFCAgentTriggerEventHandler.handleEvents(Trigger.new);
}
