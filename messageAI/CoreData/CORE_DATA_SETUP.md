# Core Data Model Setup Instructions

## Creating the Core Data Model in Xcode

Since Core Data models must be created through Xcode's UI, follow these steps:

### Step 1: Create the Data Model File

1. In Xcode, go to **File → New → File**
2. Select **Data Model** under Core Data
3. Name it: `MessageAI`
4. Save location: `messageAI/CoreData/` folder

### Step 2: Define MessageEntity

1. Click the `+` button at the bottom to add a new entity
2. Name it: `MessageEntity`
3. Add the following attributes:

| Attribute | Type | Optional |
|-----------|------|----------|
| id | String | No |
| conversationId | String | No |
| senderId | String | No |
| senderName | String | No |
| senderPhotoURL | String | Yes |
| type | String | No |
| text | String | No |
| imageURL | String | Yes |
| createdAt | Date | No |
| status | String | No |
| deliveredTo | String | Yes |
| readBy | String | Yes |
| localId | String | Yes |
| isSynced | Boolean | No |
| priority | Boolean | No |

4. Set **id** as a **unique constraint** (under Entity inspector → Constraints)
5. Set **Default value** for:
   - `isSynced`: NO
   - `priority`: NO

### Step 3: Define ConversationEntity

1. Add another entity named `ConversationEntity`
2. Add the following attributes:

| Attribute | Type | Optional |
|-----------|------|----------|
| id | String | No |
| type | String | No |
| participantIds | String | No |
| participantDetailsJSON | String | Yes |
| lastMessageText | String | Yes |
| lastMessageTimestamp | Date | Yes |
| unreadCount | Int32 | No |
| updatedAt | Date | No |
| groupName | String | Yes |

3. Set **id** as a **unique constraint**
4. Set **Default value** for:
   - `unreadCount`: 0

### Step 4: Create Relationship

1. Select **MessageEntity**
2. In the **Relationships** section, add a relationship:
   - Name: `conversation`
   - Destination: `ConversationEntity`
   - Inverse: `messages`
   - Delete Rule: Nullify

3. Select **ConversationEntity**
4. The inverse relationship `messages` should auto-create:
   - Type: To Many
   - Destination: MessageEntity
   - Delete Rule: Cascade

### Step 5: Generate NSManagedObject Subclasses

1. Select both entities (Cmd+Click)
2. Go to **Editor → Create NSManagedObject Subclass**
3. Choose your target
4. Generate classes

**IMPORTANT:** After generating, you may need to:
- Set **Codegen** to **Manual/None** in entity inspector
- Or delete the generated files and use the extensions in CoreDataExtensions.swift

### Step 6: Verify

- Build the project (Cmd+B)
- Check for any Core Data errors
- The model should now be ready to use

## Alternative: Import Pre-configured Model

If you have the `.xcdatamodeld` file from another project, you can:
1. Drag it into the `CoreData/` folder in Xcode
2. Make sure **Copy items if needed** is checked
3. Select your target

