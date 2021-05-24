public class WarehouseCalloutService implements Queueable,Database.AllowsCallouts {
    // endpoint url for callout
    private static final String ENDPOINT_URL = 'https://th-superbadge-apex.herokuapp.com/equipment';
    
    // Execute method
    public void execute(QueueableContext context) {
        syncEquipmentFromWarehouse();
    }

    // Helper method to call warehouse and fetch equipment details
    public static void syncEquipmentFromWarehouse() {
        Http http = new Http();
        HttpRequest request = new HttpRequest();
        request.setMethod('GET');
        request.setEndpoint(ENDPOINT_URL);
        HttpResponse response = http.send(request);
        if (response.getStatusCode() == 200) {
            List<Object> responseBody = (List<Object>)JSON.deserializeUntyped(response.getBody());
            List<Product2> newEquipmentList = new List<Product2>();
            for (Object obj : responseBody) {
                Map<String, Object> resonseMap = (Map<String, Object>)obj;
                Product2 newEquipment = new Product2();
                newEquipment.Warehouse_SKU__c = (String)resonseMap.get('sku');
                newEquipment.Current_Inventory__c = (Decimal)resonseMap.get('quantity');
                newEquipment.Name = (String)resonseMap.get('name');
                newEquipment.Maintenance_Cycle__c = (Decimal)resonseMap.get('maintenanceperiod');
                newEquipment.Lifespan_Months__c = (Decimal)resonseMap.get('lifespan');
                newEquipment.Cost__c = (Decimal)resonseMap.get('cost');
                newEquipment.Replacement_Part__c = true;
                newEquipmentList.add(newEquipment);
            }
            if (newEquipmentList.size()>0) {
                upsert newEquipmentList;
            }
        }
    }
}