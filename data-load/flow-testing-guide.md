# NBFC Agentforce Flow Testing Guide

Test each Auto-Launched flow from **Setup → Flows → [Flow Name] → Debug**, or via **Developer Console → Debug → Open Execute Anonymous** using the patterns below. All flows use `apiVersion` 62.0, `processType` AutoLaunchedFlow, and `status` Active.

## Quick test pattern

1. Open the flow in Flow Builder and click **Debug**.
2. Enter the input variables listed for that flow.
3. Run and confirm output variables match **Expected outputs**.
4. Verify data in Salesforce using **Verify in org**.

---

## Loan Application Lookup sub-agent

### Get_Loan_Application_Details_Flow (Apex via NBFCFlowAction_GetLoanAppDetails)

| | |
|---|---|
| **Inputs** | `Loan_Application_Id` = valid 18-char Id **or** `LA-0000001` style Name |
| **Expected outputs** | `Record_Found` = true, populated financial/status fields, `Error_Message` blank |
| **Verify** | Compare outputs to `Loan_Application__c` record and related `Applicant__r`, `Loan_Product__r` |
| **Negative test** | Invalid Id → `Record_Found` = false, error message set |

### Search_Applications_By_Name_Flow (Apex)

| | |
|---|---|
| **Inputs** | `Applicant_Name_Search` = partial applicant name (e.g. `Test`) |
| **Expected outputs** | `Record_Found` = true, `Match_Count` > 0, `Matching_Applications` pipe-formatted list |
| **Verify** | SOQL: `Loan_Application__c` with `Applicant__r.Name LIKE '%Test%'` |

### Get_Application_Status_History_Flow (Apex)

| | |
|---|---|
| **Inputs** | `Loan_Application_Id`, optional `Compliance_Relevant_Only` = false, `Limit_Records` = 10 |
| **Expected outputs** | `History_Events_Text`, `Total_Events_Found`, `Record_Found` |
| **Verify** | `Loan_Application_History__c` records for the application |

---

## Document Verification Agent sub-agent

### Get_Required_Documents_Flow (Apex + product lookup in service)

| | |
|---|---|
| **Inputs** | `Loan_Application_Id` |
| **Expected outputs** | `Required_Documents_List`, `Required_Documents_Count`, `Product_Name`, `Product_Code` |
| **Verify** | `Loan_Product__c.Required_Documents__c` on linked product |

### Get_Uploaded_Documents_Flow (Apex)

| | |
|---|---|
| **Inputs** | `Loan_Application_Id` |
| **Expected outputs** | `Documents_Summary_Text`, counts, `Issues_Found_Text`, `Missing_Documents_Text` |
| **Verify** | `Applicant_Document__c` records for application |

### Update_Missing_Documents_Flow (Apex — fault path)

| | |
|---|---|
| **Inputs** | `Loan_Application_Id`, `Missing_Documents_List` = `PAN Card, Bank Statement` |
| **Expected outputs** | `Success` = true |
| **Verify** | `Loan_Application__c.Missing_Documents__c` updated |
| **Fault test** | Invalid Id → `Success` = false, `Error_Message` populated |

---

## Financial Health Agent sub-agent

### Get_Financial_Data_Flow (Apex)

| | |
|---|---|
| **Inputs** | `Loan_Application_Id` |
| **Expected outputs** | Income, EMI, FOIR, LTI, `Credit_Score`, product fields |
| **Verify** | Financial fields on `Loan_Application__c` |

### Get_FOIR_Policy_Flow (Apex — CMDT)

| | |
|---|---|
| **Inputs** | `Product_Code` from loan product (or `ALL`) |
| **Expected outputs** | `Max_FOIR_Threshold`, `Max_FOIR_Display`, `Rule_Name` |
| **Verify** | `Policy_Rule__mdt` where `DeveloperName` = `RULE_MAX_FOIR` |

---

## Credit Risk Agent sub-agent

### Get_Risk_Assessment_Flow (Apex)

| | |
|---|---|
| **Inputs** | `Loan_Application_Id` |
| **Expected outputs** | Bureau/fraud fields or fallback `Bureau_Score` from application |
| **Verify** | Latest `Risk_Assessment__c` for application |

### Get_Credit_Score_Policy_Flow (Apex — CMDT)

| | |
|---|---|
| **Inputs** | `Product_Code` |
| **Expected outputs** | `Min_Credit_Score` (default 650 if rule missing) |
| **Verify** | `Policy_Rule__mdt` `RULE_MIN_CREDIT_SCORE` |

### Flag_For_Fraud_Review_Flow (Apex — fault path)

| | |
|---|---|
| **Inputs** | `Loan_Application_Id`, `Fraud_Score` = 85, `Fraud_Threshold` = 50 |
| **Expected outputs** | `Success` = true, `Compliance_Check_Id` populated |
| **Verify** | New `Compliance_Check__c` with `Rule_Name__c` = `FRAUD_FLAG_REVIEW` |

### Update_Risk_Score_Flow (Apex — fault path)

| | |
|---|---|
| **Inputs** | `Loan_Application_Id`, `Score_To_Add` = 5 |
| **Expected outputs** | `New_Total_Score`, `New_Risk_Level`, `Success` = true |
| **Verify** | `Risk_Score__c` and `Risk_Level__c` on application (CMDT bands via `PolicyRuleService`) |

---

## Compliance Verification Agent sub-agent

### Get_All_Compliance_Rules_Flow (Apex)

| | |
|---|---|
| **Inputs** | None |
| **Expected outputs** | `Compliance_Rules_Text`, `Total_Rules_Count`, severity counts |
| **Verify** | Active `Compliance_Rule__mdt` records |

### Get_KYC_Status_Flow (Apex)

| | |
|---|---|
| **Inputs** | `Loan_Application_Id` |
| **Expected outputs** | `KYC_Status`, masked PAN/Aadhaar (`XXXXXX` + last 4) |
| **Verify** | Person Account fields on `Applicant__r` |

### Get_Existing_Compliance_Checks_Flow (Apex)

| | |
|---|---|
| **Inputs** | `Loan_Application_Id` |
| **Expected outputs** | `Existing_Rule_Names_Text`, violation flags |
| **Verify** | `Compliance_Check__c` for application |

---

## Decision Agent sub-agent

### Check_Agent_Completion_Flow (Apex)

| | |
|---|---|
| **Inputs** | `Loan_Application_Id` |
| **Expected outputs** | Per-agent status, `All_Prerequisites_Complete`, `Completion_Summary_Text` |
| **Verify** | Five `Agent_Check_Result__c` rows |

### Get_All_Agent_Results_Flow (Apex)

| | |
|---|---|
| **Inputs** | `Loan_Application_Id` |
| **Expected outputs** | `All_Agent_Results_Text`, `Total_Risk_Score` |
| **Verify** | Sum of `Score_Impact__c` on agent results |

### Update_Application_AI_Output_Flow (Apex — fault path)

| | |
|---|---|
| **Inputs** | `Loan_Application_Id`, `Final_Recommendation` = Approve, `AI_Confidence` = 85, `Decision_Reasons`, `All_Agents_Completed` = true, `Risk_Score` |
| **Expected outputs** | `New_Status` = Approved, `Success` = true |
| **Verify** | AI fields and `Status__c` on `Loan_Application__c` |

### Publish_Agent_Platform_Event_Flow (Apex — fault path)

| | |
|---|---|
| **Inputs** | `Loan_Application_Id`, `Event_Action` = `START_ALL_AGENTS` |
| **Expected outputs** | `Success` = true |
| **Verify** | Platform event subscriber / `NBFC_Agent_Trigger__e` published |

---

## Officer Review sub-agent

### Get_Loan_Decision_Flow (Apex)

| | |
|---|---|
| **Inputs** | `Loan_Application_Id` |
| **Expected outputs** | Decision fields or `Record_Found` = false with error |
| **Verify** | Latest `Loan_Decision__c` |

### Accept_AI_Recommendation_Flow (Apex — fault path)

| | |
|---|---|
| **Inputs** | `Loan_Decision_Id`, `Loan_Application_Id`, `AI_Recommendation` = Approve |
| **Expected outputs** | `New_Application_Status` = Approved, `Success` = true |
| **Verify** | `Officer_Decision__c`, application `Status__c` |

### Escalate_To_Underwriter_Flow (Apex — fault path)

| | |
|---|---|
| **Inputs** | `Loan_Application_Id`, `Underwriter_Name_Or_Id` |
| **Expected outputs** | `Underwriter_Id`, `Success` = true |
| **Verify** | `Underwriter__c`, `Sub_Status__c` = Approval Pending |

### Send_Escalation_Notification_Flow (Apex — fault path)

| | |
|---|---|
| **Inputs** | Application context + `Underwriter_Id` |
| **Expected outputs** | `Success` (email may be suppressed in sandbox) |
| **Verify** | Email log / debug output |

---

## Portfolio and Audit Reporting sub-agent

### Get_Portfolio_Summary_Flow (Apex)

| | |
|---|---|
| **Inputs** | Optional `Date_From`, `Date_To` |
| **Expected outputs** | Status counts, `Portfolio_Summary_Text` |
| **Verify** | Aggregate counts vs `Loan_Application__c` |

### Get_Risk_Distribution_Flow (Apex)

| | |
|---|---|
| **Inputs** | None |
| **Expected outputs** | Counts per `Risk_Level__c`, `Risk_Distribution_Text` |

### Get_Agent_Performance_Flow (Apex)

| | |
|---|---|
| **Inputs** | None |
| **Expected outputs** | `Performance_Summary_Text`, `Total_Agent_Runs` |

### Get_Missing_Documents_Report_Flow (Apex)

| | |
|---|---|
| **Inputs** | None |
| **Expected outputs** | `Missing_Docs_Report_Text`, `Applications_Count` |

### Get_Officer_Override_Report_Flow (Apex)

| | |
|---|---|
| **Inputs** | None |
| **Expected outputs** | `Override_Report_Text`, `Override_Count` |

### Get_Audit_Trail_Flow (Apex)

| | |
|---|---|
| **Inputs** | `Loan_Application_Id`, optional filters |
| **Expected outputs** | `Audit_Trail_Text`, `Has_Critical_Events` |

### Get_Compliance_Summary_Flow (Apex)

| | |
|---|---|
| **Inputs** | Optional `Loan_Application_Id` |
| **Expected outputs** | Status/severity counts, `Compliance_Summary_Text` |

### Get_Daily_Volume_Flow (Apex)

| | |
|---|---|
| **Inputs** | None |
| **Expected outputs** | `Daily_Volume_Text`, `Total_This_Month` |

---

## Regenerating flows

```powershell
.\scripts\Generate-NBFCFlows.ps1
```

## Deploy

```bash
sf project deploy start --source-dir force-app/main/default/flows --source-dir force-app/main/default/classes/NBFCAgentFlowService.cls --source-dir force-app/main/default/classes/NBFCAgentFlowServiceTest.cls
```

Or deploy via `manifest/package.xml` (includes all 31 Flow members and `NBFCAgentFlowService` classes).
