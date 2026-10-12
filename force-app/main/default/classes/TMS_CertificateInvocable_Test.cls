@isTest
private class TMS_CertificateInvocable_Test {
    private class Mock implements HttpCalloutMock {
        public HttpResponse respond(HttpRequest req) {
            HttpResponse res = new HttpResponse();
            res.setStatusCode(200);
            res.setBody('png');
            return res;
        }
    }

    @isTest static void emptyListDoesNothing() {
        Test.startTest();
        TMS_CertificateInvocable.enqueue(new List<Id>());
        Test.stopTest();
        Assert.areEqual(0, [SELECT COUNT() FROM Integration_Log__c], 'No job, no log');
    }

    @isTest static void enqueueVerifiesCertificate() {
        Test.setMock(HttpCalloutMock.class, new Mock());
        Course_Batch__c b = TMS_TestDataFactory.createBatch(2);
        List<Contact> trainees = TMS_TestDataFactory.createTrainees(1);
        Enrollment__c e = TMS_TestDataFactory.createEnrollments(b.Id, trainees, 'Under Review')[0];
        Certificate__c c = new Certificate__c(Enrollment__c = e.Id, Trainee__c = trainees[0].Id,
            Course__c = b.Course__c, Certificate_Key__c = e.Id, Status__c = 'Issued',
            Issue_Date__c = Date.today(), Verification_Status__c = 'Not Verified');
        insert c;
        Test.startTest();
        TMS_CertificateInvocable.enqueue(new List<Id>{ c.Id });
        Test.stopTest();
        Assert.areEqual('Verified',
            [SELECT Verification_Status__c FROM Certificate__c WHERE Id = :c.Id].Verification_Status__c,
            'The queued job must verify the certificate');
    }
}