/** Routes Enrollment trigger events to the seat service. */
public without sharing class TMS_EnrollmentTriggerHandler {
    public static void run() {
        if (Trigger.isBefore) {
            // before insert and before update
            TMS_SeatAllocationService.decideSeats(
                (List<Enrollment__c>) Trigger.new, (Map<Id, Enrollment__c>) Trigger.oldMap);
        } else if (Trigger.isAfter) {
            Set<Id> batchIds = new Set<Id>();
            if (Trigger.isDelete) {
                for (Enrollment__c e : (List<Enrollment__c>) Trigger.old) {
                    batchIds.add(e.Course_Batch__c);
                }
            } else if (Trigger.isUpdate) {
                Map<Id, Enrollment__c> oldMap = (Map<Id, Enrollment__c>) Trigger.oldMap;
                for (Enrollment__c e : (List<Enrollment__c>) Trigger.new) {
                    Enrollment__c old = oldMap.get(e.Id);
                    // only a status or batch change can change a seat count
                    if (e.Status__c != old.Status__c || e.Course_Batch__c != old.Course_Batch__c) {
                        batchIds.add(e.Course_Batch__c);
                        batchIds.add(old.Course_Batch__c);
                    }
                }
            } else {
                // after insert, after undelete
                for (Enrollment__c e : (List<Enrollment__c>) Trigger.new) {
                    batchIds.add(e.Course_Batch__c);
                }
            }
            TMS_SeatAllocationService.recountSeats(batchIds);
        }
    }
}