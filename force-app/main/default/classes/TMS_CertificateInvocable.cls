/** Lets a flow start the certificate verification job. */
public with sharing class TMS_CertificateInvocable {
    @InvocableMethod(label='Enqueue certificate verification' description='Queues the QR verification callout for new certificates')
    public static void enqueue(List<Id> certificateIds) {
        if (certificateIds == null || certificateIds.isEmpty()) { return; }
        System.enqueueJob(new TMS_CertificateIssueQueueable(certificateIds));
    }
}