@isTest
private class TMS_CertificateExpiryBatch_Test {

    private static Certificate__c makeCert(Enrollment__c e, Id courseId, Date expiry) {
        // 'Skipped' keeps the certificate flow's queued job from calling out during the test.
        return new Certificate__c(Enrollment__c = e.Id, Trainee__c = e.Trainee__c, Course__c = courseId,
            Certificate_Key__c = e.Id, Status__c = 'Issued', Issue_Date__c = Date.today(),
            Expiry_Date__c = expiry, Verification_Status__c = 'Skipped');
    }

    @isTest static void onlyExpiredCertificatesChange() {
        Course_Batch__c b = TMS_TestDataFactory.createBatch(3);
        List<Enrollment__c> es = TMS_TestDataFactory.createEnrollments(
            b.Id, TMS_TestDataFactory.createTrainees(3), 'Under Review');
        List<Certificate__c> certs = new List<Certificate__c>{
            makeCert(es[0], b.Course__c, Date.today().addDays(-1)),
            makeCert(es[1], b.Course__c, Date.today().addDays(30)),
            makeCert(es[2], b.Course__c, null)
        };
        insert certs;

        Test.startTest();
        Database.executeBatch(new TMS_CertificateExpiryBatch(), 200);
        Test.stopTest();

        Map<Id, Certificate__c> after = new Map<Id, Certificate__c>(
            [SELECT Status__c FROM Certificate__c WHERE Id IN :certs]);
        Assert.areEqual('Expired', after.get(certs[0].Id).Status__c, 'Past expiry must become Expired');
        Assert.areEqual('Issued', after.get(certs[1].Id).Status__c, 'Future expiry stays Issued');
        Assert.areEqual('Issued', after.get(certs[2].Id).Status__c, 'No expiry stays Issued');
    }

    @isTest static void schedulerIsRegistered() {
        String cron = '0 0 1 * * ?';
        Test.startTest();
        Id jobId = System.schedule('TMS Cert Expiry Test', cron, new TMS_CertificateExpiryScheduler());
        CronTrigger ct = [SELECT CronExpression, TimesTriggered FROM CronTrigger WHERE Id = :jobId];
        Assert.areEqual(cron, ct.CronExpression, 'Schedule must use the nightly cron');
        Assert.areEqual(0, ct.TimesTriggered, 'Job has not run yet');
        Test.stopTest();
    }
}