@isTest
private class TMS_CertificateIssueQueueable_Test {

    private class Mock implements HttpCalloutMock {
        private Integer statusCode;
        Mock(Integer sc) { statusCode = sc; }
        public HttpResponse respond(HttpRequest req) {
            HttpResponse res = new HttpResponse();
            res.setStatusCode(statusCode);
            res.setBody('png');
            return res;
        }
    }

    private static Certificate__c makeCertificate() {
        Course_Batch__c b = TMS_TestDataFactory.createBatch(2);
        List<Contact> trainees = TMS_TestDataFactory.createTrainees(1);
        List<Enrollment__c> es = TMS_TestDataFactory.createEnrollments(b.Id, trainees, 'Under Review');
        Certificate__c c = new Certificate__c(Enrollment__c = es[0].Id, Trainee__c = trainees[0].Id,
            Course__c = b.Course__c, Certificate_Key__c = es[0].Id, Status__c = 'Issued',
            Issue_Date__c = Date.today(), Verification_Status__c = 'Not Verified');
        insert c;
        return c;
    }

    @isTest static void successMarksVerifiedAndLogs() {
        Test.setMock(HttpCalloutMock.class, new Mock(200));
        Certificate__c c = makeCertificate();
        Test.startTest();
        System.enqueueJob(new TMS_CertificateIssueQueueable(new List<Id>{ c.Id }));
        Test.stopTest();
        Certificate__c r = [SELECT Verification_Status__c, Verification_Code__c, QR_Image_Url__c
                            FROM Certificate__c WHERE Id = :c.Id];
        Assert.areEqual('Verified', r.Verification_Status__c, 'Certificate must be verified');
        Assert.isNotNull(r.Verification_Code__c, 'Code must be generated');
        Assert.isNotNull(r.QR_Image_Url__c, 'QR link must be stored');
        Assert.areEqual(1, [SELECT COUNT() FROM Integration_Log__c WHERE Certificate__c = :c.Id AND Is_Success__c = true],
            'Exactly one successful log row');
    }

    @isTest static void serverErrorMarksFailedAndLogs() {
        Test.setMock(HttpCalloutMock.class, new Mock(500));
        Certificate__c c = makeCertificate();
        Test.startTest();
        System.enqueueJob(new TMS_CertificateIssueQueueable(new List<Id>{ c.Id }));
        Test.stopTest();
        Certificate__c r = [SELECT Verification_Status__c, QR_Image_Url__c FROM Certificate__c WHERE Id = :c.Id];
        Assert.areEqual('Failed', r.Verification_Status__c, 'A 500 must mark the certificate Failed');
        Assert.isNull(r.QR_Image_Url__c, 'No QR link on failure');
        Assert.areEqual(1, [SELECT COUNT() FROM Integration_Log__c WHERE Certificate__c = :c.Id AND Is_Success__c = false],
            'Exactly one failed log row');
    }
    @isTest static void secondJobForSameCertificateDoesNothing() {
    Test.setMock(HttpCalloutMock.class, new Mock(200));
    Certificate__c c = makeCertificate();
    Test.startTest();
    System.enqueueJob(new TMS_CertificateIssueQueueable(new List<Id>{ c.Id }));
    System.enqueueJob(new TMS_CertificateIssueQueueable(new List<Id>{ c.Id }));
    Test.stopTest();
    Assert.areEqual(1, [SELECT COUNT() FROM Integration_Log__c WHERE Certificate__c = :c.Id],
        'Two jobs for the same certificate must still produce one log row');
    Assert.areEqual('Verified', [SELECT Verification_Status__c FROM Certificate__c WHERE Id = :c.Id].Verification_Status__c,
        'Certificate stays Verified');
}
    @isTest static void oneJobHandlesOnlyTheChunkSize() {
    Test.setMock(HttpCalloutMock.class, new Mock(200));
    Course_Batch__c b = TMS_TestDataFactory.createBatch(20);
    List<Contact> trainees = TMS_TestDataFactory.createTrainees(12);
    List<Enrollment__c> es = TMS_TestDataFactory.createEnrollments(b.Id, trainees, 'Under Review');
    List<Certificate__c> certs = new List<Certificate__c>();
    for (Integer i = 0; i < 12; i++) {
        // 'Skipped' first, so the certificate flow's own job does nothing.
        certs.add(new Certificate__c(Enrollment__c = es[i].Id, Trainee__c = trainees[i].Id, Course__c = b.Course__c,
            Certificate_Key__c = es[i].Id, Status__c = 'Issued', Issue_Date__c = Date.today(),
            Verification_Status__c = 'Skipped'));
    }
    insert certs;
    for (Certificate__c c : certs) { c.Verification_Status__c = 'Not Verified'; }
    update certs;
    List<Id> ids = new List<Id>(new Map<Id, Certificate__c>(certs).keySet());
    Test.startTest();
    System.enqueueJob(new TMS_CertificateIssueQueueable(ids));
    Test.stopTest();
    Assert.areEqual(10, [SELECT COUNT() FROM Certificate__c WHERE Id IN :ids AND Verification_Status__c = 'Verified'],
        'One job verifies exactly the chunk size');
    Assert.areEqual(2, [SELECT COUNT() FROM Certificate__c WHERE Id IN :ids AND Verification_Status__c = 'Not Verified'],
        'The remainder waits for the next job');
}
}