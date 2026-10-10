public with sharing class TMS_Constants {
    public static final String APPROVED = 'Approved';
    public static final String WAITLISTED = 'Waitlisted';
    // Statuses that occupy a seat. Applied, Under Review, Waitlisted, Rejected and Withdrawn do not.
    public static final Set<String> SEAT_HOLDING = new Set<String>{ 'Approved', 'Completed', 'Failed' };
}