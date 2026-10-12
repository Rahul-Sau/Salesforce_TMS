/** Starts the certificate expiry batch. Scheduled nightly at 1:00 AM. */
public with sharing class TMS_CertificateExpiryScheduler implements Schedulable {
    public void execute(SchedulableContext sc) {
        Database.executeBatch(new TMS_CertificateExpiryBatch(), 200);
    }
}