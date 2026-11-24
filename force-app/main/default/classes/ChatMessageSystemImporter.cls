/**
 * Development-only bridge for trusted, one-time source imports when the REST
 * caller cannot see optional POC fields.  It is intentionally invoked from a
 * local anonymous-Apex script and is not part of the runtime analytics path.
 */
public without sharing class ChatMessageSystemImporter {
    private static final Set<String> TEXT_FIELDS = new Set<String>{
        'Source_Message_Id__c', 'Conversation_Identifier__c',
        'Participant_Display_Name__c', 'Participant_Role__c',
        'Client_Timestamp_Raw__c', 'Entry_Payload__c', 'Message_Type__c',
        'Format_Type__c', 'Speaker__c', 'Available_Options__c',
        'Message_Text__c', 'Message_Category__c', 'Import_Batch_Id__c'
    };

    public static ImportResult importJson(String payload) {
        List<Object> values = (List<Object>) JSON.deserializeUntyped(payload);
        List<Chat_Message__c> messages = new List<Chat_Message__c>();
        for (Object value : values) {
            Map<String, Object> source = (Map<String, Object>) value;
            Chat_Message__c message = new Chat_Message__c();
            for (String fieldName : TEXT_FIELDS) if (source.containsKey(fieldName) && source.get(fieldName) != null) message.put(fieldName, String.valueOf(source.get(fieldName)));
            if (source.containsKey('Client_Duration__c') && source.get('Client_Duration__c') != null && !String.isBlank(String.valueOf(source.get('Client_Duration__c')))) message.Client_Duration__c = Decimal.valueOf(String.valueOf(source.get('Client_Duration__c')));
            if (source.containsKey('Source_Row_Number__c') && source.get('Source_Row_Number__c') != null) message.Source_Row_Number__c = Decimal.valueOf(String.valueOf(source.get('Source_Row_Number__c')));
            if (source.containsKey('Conversation_Date__c') && source.get('Conversation_Date__c') != null) message.Conversation_Date__c = parseDate(String.valueOf(source.get('Conversation_Date__c')));
            message.Client_Timestamp__c = parseDateTime(message.Client_Timestamp_Raw__c);
            messages.add(message);
        }

        Set<String> sourceIds = new Set<String>();
        for (Chat_Message__c message : messages) sourceIds.add(message.Source_Message_Id__c);
        Map<String, Id> existingBySourceId = new Map<String, Id>();
        for (SObject record : Database.queryWithBinds('SELECT Id, Source_Message_Id__c FROM Chat_Message__c WHERE Source_Message_Id__c IN :sourceIds', new Map<String, Object>{'sourceIds' => sourceIds}, AccessLevel.SYSTEM_MODE)) {
            Chat_Message__c message = (Chat_Message__c) record;
            existingBySourceId.put(message.Source_Message_Id__c, message.Id);
        }
        List<Chat_Message__c> inserts = new List<Chat_Message__c>(), updates = new List<Chat_Message__c>();
        for (Chat_Message__c message : messages) {
            if (existingBySourceId.containsKey(message.Source_Message_Id__c)) { message.Id = existingBySourceId.get(message.Source_Message_Id__c); updates.add(message); }
            else inserts.add(message);
        }
        if (!inserts.isEmpty()) Database.insert(inserts, AccessLevel.SYSTEM_MODE);
        if (!updates.isEmpty()) Database.update(updates, AccessLevel.SYSTEM_MODE);
        ImportResult result = new ImportResult(); result.insertedCount = inserts.size(); result.updatedCount = updates.size(); result.totalCount = messages.size(); return result;
    }

    private static Date parseDate(String raw) {
        if (String.isBlank(raw)) return null;
        List<String> parts = raw.trim().split('/');
        return parts.size() == 3 ? Date.newInstance(Integer.valueOf(parts[2]), Integer.valueOf(parts[1]), Integer.valueOf(parts[0])) : null;
    }
    private static DateTime parseDateTime(String raw) {
        if (String.isBlank(raw)) return null;
        List<String> dateAndTime = raw.trim().split(' ');
        if (dateAndTime.size() != 2) return null;
        List<String> dateParts = dateAndTime[0].split('/'), timeParts = dateAndTime[1].split(':');
        if (dateParts.size() != 3 || timeParts.size() != 3) return null;
        return DateTime.newInstance(Integer.valueOf(dateParts[2]), Integer.valueOf(dateParts[1]), Integer.valueOf(dateParts[0]), Integer.valueOf(timeParts[0]), Integer.valueOf(timeParts[1]), Integer.valueOf(timeParts[2]));
    }
    public class ImportResult { public Integer insertedCount; public Integer updatedCount; public Integer totalCount; }
}