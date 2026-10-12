// Nightly job: marks Issued certificates past their expiry date as Expired
public without sharing class TMS_CertificateExpiryBatch implements Database.Batchable<SObject>, Database.Stateful {

    // Stateful keeps these values between execute() chunks.
    private Integer expiredCount = 0;
    private Integer failedCount = 0;

    public Database.QueryLocator start(Database.BatchableContext bc) {
        return Database.getQueryLocator([
            SELECT Id FROM Certificate__c
            WHERE Status__c = 'Issued' AND Expiry_Date__c != null AND Expiry_Date__c < TODAY
        ]);
    }

    public void execute(Database.BatchableContext bc, List<Certificate__c> scope) {
        for (Certificate__c c : scope) { c.Status__c = 'Expired'; }
        // allOrNone false: one bad record never blocks the rest of the chunk.
        List<Database.SaveResult> results = Database.update(scope, false, AccessLevel.SYSTEM_MODE);
        for (Database.SaveResult sr : results) {
            if (sr.isSuccess()) { expiredCount++; } else { failedCount++; }
        }
    }

    public void finish(Database.BatchableContext bc) {
        // Quiet nights send nothing (Developer Edition has a low daily email limit).
        if (expiredCount == 0 && failedCount == 0) { return; }
        String adminEmail = System.Label.TMS_Admin_Email;
        if (String.isBlank(adminEmail)) { return; }

        Messaging.SingleEmailMessage mail = new Messaging.SingleEmailMessage();
        mail.setToAddresses(new List<String>{ adminEmail });
        // Use the verified org-wide address if there is one (the same issue as the Day 3 flow emails).
        List<OrgWideEmailAddress> owa = [SELECT Id FROM OrgWideEmailAddress LIMIT 1];
        if (!owa.isEmpty()) { mail.setOrgWideEmailAddressId(owa[0].Id); }
        mail.setSubject('TMS nightly certificate expiry: ' + expiredCount + ' expired');
        mail.setPlainTextBody('The nightly expiry job finished.\n'
            + 'Certificates marked Expired: ' + expiredCount + '\n'
            + 'Certificates that failed to update: ' + failedCount);
        // allOrNothing false: an email problem must never fail the job.
        Messaging.sendEmail(new List<Messaging.SingleEmailMessage>{ mail }, false);
    }
}