@isTest
private class TMS_SeatAllocationService_Test {

    @isTest static void lastSeatGoesToWaitlist() {
        Course_Batch__c b = TMS_TestDataFactory.createBatch(2);
        List<Enrollment__c> es = TMS_TestDataFactory.createEnrollments(
            b.Id, TMS_TestDataFactory.createTrainees(3), 'Under Review');
        for (Enrollment__c e : es) { e.Status__c = 'Approved'; }
        Test.startTest();
        update es;
        Test.stopTest();
        Assert.areEqual(2, [SELECT COUNT() FROM Enrollment__c WHERE Status__c = 'Approved'], 'Only two seats exist');
        Assert.areEqual(1, [SELECT COUNT() FROM Enrollment__c WHERE Status__c = 'Waitlisted'], 'Third must be waitlisted');
        Assert.areEqual(2, [SELECT Seats_Taken__c FROM Course_Batch__c WHERE Id = :b.Id].Seats_Taken__c, 'Seats taken');
    }

    @isTest static void bulkApprovalNeverExceedsSeats() {
        Course_Batch__c b = TMS_TestDataFactory.createBatch(5);
        List<Enrollment__c> es = TMS_TestDataFactory.createEnrollments(
            b.Id, TMS_TestDataFactory.createTrainees(20), 'Under Review');
        for (Enrollment__c e : es) { e.Status__c = 'Approved'; }
        Test.startTest();
        update es;
        Test.stopTest();
        Assert.areEqual(5, [SELECT COUNT() FROM Enrollment__c WHERE Status__c = 'Approved'], 'Seats must not be exceeded');
        Assert.areEqual(15, [SELECT COUNT() FROM Enrollment__c WHERE Status__c = 'Waitlisted'], 'Rest waitlisted');
    }

    @isTest static void withdrawalReleasesSeat() {
        Course_Batch__c b = TMS_TestDataFactory.createBatch(2);
        List<Enrollment__c> es = TMS_TestDataFactory.createEnrollments(
            b.Id, TMS_TestDataFactory.createTrainees(2), 'Under Review');
        for (Enrollment__c e : es) { e.Status__c = 'Approved'; }
        update es;
        es[0].Status__c = 'Withdrawn';
        Test.startTest();
        update es[0];
        Test.stopTest();
        Assert.areEqual(1, [SELECT Seats_Taken__c FROM Course_Batch__c WHERE Id = :b.Id].Seats_Taken__c, 'Seat released');
    }

    @isTest static void directInsertAsApprovedRespectsSeats() {
        Course_Batch__c b = TMS_TestDataFactory.createBatch(1);
        List<Contact> trainees = TMS_TestDataFactory.createTrainees(2);
        Test.startTest();
        TMS_TestDataFactory.createEnrollments(b.Id, trainees, 'Approved');
        Test.stopTest();
        Assert.areEqual(1, [SELECT COUNT() FROM Enrollment__c WHERE Status__c = 'Approved'], 'One seat');
        Assert.areEqual(1, [SELECT COUNT() FROM Enrollment__c WHERE Status__c = 'Waitlisted'], 'One waitlisted');
    }
}