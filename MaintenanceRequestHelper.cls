public class MaintenanceRequestHelper {
    static String STATUS_CLOSED = 'Closed';
    static String TYPE_REPAIR = 'Repair';
    static String TYPE_ROUTINE_MAINTENANCE = 'Routine Maintenance';

    /** 
     * Handler method to handle after update logic on Maintenance Request records
    */
    public static void handleAfterUpdate(List<Case> newCases){
        List<Case> closedCases = new List<Case>();
        for (Case caseRec : newCases) {
            if (caseRec.Status == STATUS_CLOSED && (caseRec.Type == TYPE_REPAIR || caseRec.Type == TYPE_ROUTINE_MAINTENANCE)) {
                closedCases.add(caseRec);
            }
        }
        if (closedCases.size()>0) {
            updateWorkOrder(closedCases);
        }
    }

    /** 
     * Helper method to create follow up routine maintenance request when a maintenance request is closed.
     * New request is created for the same vehicle and equiptment
    */
    public static void updateWorkOrder(List<Case> caseList){
        List<Case> followUpCaseList = new List<Case>();
        List<Equipment_Maintenance_Item__c> itemListToInsert = new List<Equipment_Maintenance_Item__c>();
        // fetch days to be added to current date to calculate Due Date of new request
        Map<String, Integer> dueDateMap = getDueDate(caseList);
        // fetch all maintenance items to be cloned for new request.
        Map<String, List<Equipment_Maintenance_Item__c>> maintenanceItemMap = getMaintenanceItems(caseList);
        for (Case existingCase : caseList) {
            Case newCase = new Case();
            newCase.Vehicle__c = existingCase.Vehicle__c;
            newCase.Subject = TYPE_ROUTINE_MAINTENANCE;
            newCase.Type = TYPE_ROUTINE_MAINTENANCE;
            newCase.Date_Reported__c = Date.today();
            newCase.Cloned_Case_Id__c = existingCase.Id;
            if (dueDateMap.get(existingCase.Id) != null) {
                newCase.Date_Due__c = Date.today().addDays(dueDateMap.get(existingcase.Id));
            }else {
                newCase.Date_Due__c = Date.today();
            }
            followUpCaseList.add(newCase);
        }
        if (followUpCaseList.size()>0) {
            insert followUpCaseList;

            for (Case insertedCase : followUpCaseList) {
                List<Equipment_Maintenance_Item__c> itemList = maintenanceItemMap.get(insertedCase.Cloned_Case_Id__c);
                if (itemList.size()>0) {
                    for (Equipment_Maintenance_Item__c item : itemList) {
                        Equipment_Maintenance_Item__c newItem = new Equipment_Maintenance_Item__c();
                        newItem.Maintenance_Request__c = insertedCase.Id;
                        newItem.Equipment__c = item.Equipment__c;
                        newItem.Quantity__c = item.Quantity__c;
                        itemListToInsert.add(newItem);
                    }
                }
            }
            if (itemListToInsert.size()>0) {
                insert itemListToInsert;
            }
        }
    }

    /** 
     * Helper method to fetch days to be added to follow up routine maintence request due date created in updateWorkOrder.
     * Day is calculated by using the maintenance cycle defined on the related equipment records.
    */
    public static Map<String,Integer> getDueDate(List<Case> caseList){
        Map<String, Integer> result = new Map<String, Integer>();
        Map<Id, Case> caseKeys = new Map<Id, Case>(caseList);
        List<AggregateResult> aggResult = [SELECT  Maintenance_Request__c cId, min(Equipment__r.Maintenance_Cycle__c) cycle 
                                            FROM Equipment_Maintenance_Item__c WHERE Maintenance_Request__c IN: caseKeys.keySet() 
                                            AND Equipment__r.Maintenance_Cycle__c != null GROUP BY Maintenance_Request__c];
        for (AggregateResult res : aggResult) {
            Integer addDays = 0;
            String caseId = String.valueOf(res.get('cId'));
            if (res.get('cycle') != null) {
                addDays+= Integer.valueOf(res.get('cycle'));
            }
            result.put(caseId, addDays);
        }
        return result;
    }

    /** 
     * Helper method to get all maintenance items related to closed requests.
    */
    public static Map<String, List<Equipment_Maintenance_Item__c>> getMaintenanceItems(List<Case> caseList){
        Map<String, List<Equipment_Maintenance_Item__c>> result = new Map<String, List<Equipment_Maintenance_Item__c>>();
        Map<Id, Case> caseKeys = new Map<Id, Case>(caseList);
        List<Equipment_Maintenance_Item__c> itemList = [SELECT  Id, Maintenance_Request__c, Equipment__c, Quantity__c 
                                                        FROM Equipment_Maintenance_Item__c WHERE Maintenance_Request__c 
                                                        IN: caseKeys.keySet()];
        for (Equipment_Maintenance_Item__c item : itemList) {
            if (result.containsKey(item.Maintenance_Request__c)) {
                List<Equipment_Maintenance_Item__c> temp = result.get(item.Maintenance_Request__c);
                temp.add(item);
                result.put(item.Maintenance_Request__c, temp);
            }else {
                result.put(item.Maintenance_Request__c, new List<Equipment_Maintenance_Item__c>{item});
            }
        }
        return result;
    }
}