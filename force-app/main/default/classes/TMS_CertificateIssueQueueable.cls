/** Background job: calls the QR service for up to 10 certificates, saves the result, logs each call, then hands the rest to one child job. */
public without sharing class TMS_CertificateIssueQueueable implements Queueable, Database.AllowsCallouts {
    private static final String QR_PATH = '/v1/create-qr-code/?size=200x200&data=';
    // 10 per job: 10 callouts x 10 s worst case stays under the 120 s callout limit.
    @TestVisible private static final Integer CHUNK_SIZE = 10;
    private List<Id> certIds;

    public TMS_CertificateIssueQueueable(List<Id> ids) { this.certIds = ids; }

    public void execute(QueueableContext ctx) {
        TMS_Config__mdt cfg = TMS_Config__mdt.getInstance('Default');
        Boolean enabled = (cfg == null) || (cfg.QR_Enabled__c == true);

        List<Certificate__c> eligible = [
            SELECT Id FROM Certificate__c
            WHERE Id IN :certIds AND Status__c = 'Issued'
              AND (Verification_Status__c = 'Not Verified' OR Verification_Status__c = null)
            WITH SYSTEM_MODE
        ];
        List<Certificate__c> certs = new List<Certificate__c>();
        List<Id> rest = new List<Id>();
        for (Integer i = 0; i < eligible.size(); i++) {
            if (i < CHUNK_SIZE) { certs.add(eligible[i]); } else { rest.add(eligible[i].Id); }
        }

        List<Certificate__c> upd = new List<Certificate__c>();
        List<Integration_Log__c> logs = new List<Integration_Log__c>();

        // All callouts first, all DML after. A callout after uncommitted DML is an error.
        for (Certificate__c c : certs) {
            if (!enabled) {
                upd.add(new Certificate__c(Id = c.Id, Verification_Status__c = 'Skipped'));
                continue;
            }
            String code = EncodingUtil.convertToHex(Crypto.generateAesKey(128)).substring(0, 12).toUpperCase();
            String verifyUrl = System.Label.TMS_Verify_Base_Url + code;
            String path = QR_PATH + EncodingUtil.urlEncode(verifyUrl, 'UTF-8');

            HttpRequest req = new HttpRequest();
            req.setEndpoint('callout:TMS_QR_Service' + path);
            req.setMethod('GET');
            req.setTimeout(10000);

            Integer status = 0;
            String err = null;
            try {
                status = new Http().send(req).getStatusCode();
            } catch (Exception e) {
                err = e.getMessage().left(250);
            }
            Boolean ok = status >= 200 && status < 300;

            upd.add(new Certificate__c(Id = c.Id, Verification_Code__c = code, Verification_Url__c = verifyUrl,
                QR_Image_Url__c = ok ? 'https://api.qrserver.com' + path : null,
                Verification_Status__c = ok ? 'Verified' : 'Failed',
                Verified_On__c = ok ? System.now() : null));
            logs.add(new Integration_Log__c(Certificate__c = c.Id, Endpoint__c = 'TMS_QR_Service',
                HTTP_Status__c = status, Is_Success__c = ok, Attempt__c = 1, Error_Message__c = err));
        }
        if (!upd.isEmpty()) { Database.update(upd, true, AccessLevel.SYSTEM_MODE); }
        if (!logs.isEmpty()) { Database.insert(logs, true, AccessLevel.SYSTEM_MODE); }

        // A Queueable may enqueue only one child. It carries the remainder.
        // Chaining is not allowed inside tests, so it is skipped there.
        if (!rest.isEmpty() && !Test.isRunningTest()) {
            System.enqueueJob(new TMS_CertificateIssueQueueable(rest));
        }
    }
}