/** Counts seats, decides Approved or Waitlisted under a row lock, and writes Seats Taken. */
public without sharing class TMS_SeatAllocationService {

    // How many seats are in use per batch.
    private static Map<Id, Integer> countTaken(Set<Id> batchIds) {
        Set<String> holding = TMS_Constants.SEAT_HOLDING;
        Map<Id, Integer> taken = new Map<Id, Integer>();
        for (AggregateResult ar : [
            SELECT Course_Batch__c b, COUNT(Id) c
            FROM Enrollment__c
            WHERE Course_Batch__c IN :batchIds AND Status__c IN :holding
            GROUP BY Course_Batch__c
        ]) {
            taken.put((Id) ar.get('b'), (Integer) ar.get('c'));
        }
        return taken;
    }

    // BEFORE insert/update: decide Approved or Waitlisted while the batch row is locked.
    public static void decideSeats(List<Enrollment__c> newList, Map<Id, Enrollment__c> oldMap) {
        List<Enrollment__c> toDecide = new List<Enrollment__c>();
        Set<Id> batchIds = new Set<Id>();
        for (Enrollment__c e : newList) {
            Enrollment__c old = (oldMap == null) ? null : oldMap.get(e.Id);
            Boolean wasHolding = old != null && TMS_Constants.SEAT_HOLDING.contains(old.Status__c);
            if (e.Status__c == TMS_Constants.APPROVED && !wasHolding) {
                toDecide.add(e);
                batchIds.add(e.Course_Batch__c);
            }
        }
        if (toDecide.isEmpty()) { return; }

        // FOR UPDATE locks the batch rows, so a second approval of the same batch waits here.
        Map<Id, Course_Batch__c> batches = new Map<Id, Course_Batch__c>(
            [SELECT Id, Max_Seats__c FROM Course_Batch__c WHERE Id IN :batchIds FOR UPDATE]
        );
        Map<Id, Integer> taken = countTaken(batchIds);

        for (Enrollment__c e : toDecide) {
            Integer used = taken.containsKey(e.Course_Batch__c) ? taken.get(e.Course_Batch__c) : 0;
            if (used < batches.get(e.Course_Batch__c).Max_Seats__c) {
                taken.put(e.Course_Batch__c, used + 1);  // grant the seat in memory for later rows in this save
            } else {
                e.Status__c = TMS_Constants.WAITLISTED;
            }
        }
    }

    // AFTER events: write the true count to each batch.
    public static void recountSeats(Set<Id> batchIds) {
        if (batchIds.isEmpty()) { return; }
        Map<Id, Integer> taken = countTaken(batchIds);
        List<Course_Batch__c> upd = new List<Course_Batch__c>();
        for (Id b : batchIds) {
            upd.add(new Course_Batch__c(Id = b, Seats_Taken__c = taken.containsKey(b) ? taken.get(b) : 0));
        }
       Database.update(upd, true, AccessLevel.SYSTEM_MODE);
    }
}