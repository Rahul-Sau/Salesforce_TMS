// Thin trigger: all logic lives in TMS_EnrollmentTriggerHandler.
trigger TMS_EnrollmentTrigger on Enrollment__c (before insert, before update, after insert, after update, after delete, after undelete) {
    TMS_EnrollmentTriggerHandler.run();
}