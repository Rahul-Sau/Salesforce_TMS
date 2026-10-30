/** Nightly: starts the expiry batch, then sweeps any certificates still Not Verified. */
public with sharing class TMS_CertificateExpiryScheduler implements Schedulable {
    public void execute(SchedulableContext sc) {
        Database.executeBatch(new TMS_CertificateExpiryBatch(), 200);
        // Safety net: certificates still Not Verified (service down, or a chain was cut short).
        List<Id> pending = new List<Id>(new Map<Id, Certificate__c>([
            SELECT Id FROM Certificate__c
            WHERE Status__c = 'Issued' AND Verification_Status__c = 'Not Verified' LIMIT 200
        ]).keySet());
        if (!pending.isEmpty()) { System.enqueueJob(new TMS_CertificateIssueQueueable(pending)); }
    }
}