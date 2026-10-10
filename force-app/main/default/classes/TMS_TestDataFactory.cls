@isTest
public class TMS_TestDataFactory {
    private static Integer seq = 0;

    public static Id rt(String devName) {
        return Schema.SObjectType.Contact.getRecordTypeInfosByDeveloperName().get(devName).getRecordTypeId();
    }

    public static Course_Batch__c createBatch(Integer seats) {
        seq++;
        Account a = new Account(Name = 'TMS Test Account ' + seq);
        insert a;
        Contact trainer = new Contact(LastName = 'Trainer' + seq, AccountId = a.Id,
            RecordTypeId = rt('Trainer'), Email = 'trainer' + seq + '@example.com');
        insert trainer;
        Course__c c = new Course__c(Name = 'Test Course ' + seq, Course_Code__c = 'TST-' + seq,
            Level__c = 'Beginner', Pass_Mark__c = 60, Duration_Hours__c = 10, Status__c = 'Published');
        insert c;
        Course_Batch__c b = new Course_Batch__c(Name = 'Test Batch ' + seq, Course__c = c.Id,
            Trainer__c = trainer.Id, Batch_Code__c = 'TB-' + seq, Status__c = 'Open for Enrollment',
            Start_Date__c = Date.today().addDays(10), End_Date__c = Date.today().addDays(40),
            Enrollment_Close_Date__c = Date.today().addDays(5), Max_Seats__c = seats);
        insert b;
        return b;
    }

    public static List<Contact> createTrainees(Integer n) {
        Account a = [SELECT Id FROM Account WHERE Name LIKE 'TMS Test Account%' LIMIT 1];
        List<Contact> cs = new List<Contact>();
        for (Integer i = 0; i < n; i++) {
            cs.add(new Contact(LastName = 'Trainee' + i, AccountId = a.Id, RecordTypeId = rt('Trainee'),
                Email = 'trainee' + i + '@example.com'));
        }
        insert cs;
        return cs;
    }

    public static List<Enrollment__c> createEnrollments(Id batchId, List<Contact> trainees, String status) {
        List<Enrollment__c> es = new List<Enrollment__c>();
        for (Contact c : trainees) {
            es.add(new Enrollment__c(Course_Batch__c = batchId, Trainee__c = c.Id, Status__c = status));
        }
        insert es;
        return es;
    }
}