#import <Foundation/Foundation.h>
#import <CoreData/CoreData.h>

typedef BOOL (^NSManagedObjectArchivingBlock)(NSManagedObject* object, NSString* key);

@interface NSManagedObjectArchiver : NSObject

/*
 * Takes a NSManagedObject and converts it to a NSData archive - it traverses all relationships ( including circular ) and archives it
 */
+ (NSData *)archivedDataWithRootObject:(NSManagedObject *)pObject;

+ (NSData *)archivedDataWithRootObject:(NSManagedObject *)pObject block:(NSManagedObjectArchivingBlock)block;

@end

@interface NSManagedObjectUnarchiver : NSObject

/*
 * Takes a NSData object from NSManagedObjectArchiver and re-creates the NSManagedObject
 * @param NSManagedObjectContext *context - required - provided context is used to obtain NSEntityDescriptions from. The entityName and entityVersionHash is checked to restore the correct entity.
 * @param BOOL insert - whether or not objects should be inserted into the provided context when created, if choose not to insert them you would need to insert them manually ( including relationships ) before they can be saved
 */
+ (NSManagedObject *)unarchiveObjectWithData:(NSData *)pData context:(NSManagedObjectContext *)pContext insert:(BOOL)pInsert;

@end


@interface NSManagedObject (NSManagedObjectCopying)

/*
 * Makes a copy of an NSManagedObject - this is a shallow copy and does not traverse relationships
 * @param NSManagedObjectContext *context - required - provided context is used to obtain NSEntityDescriptions from.
 * @param BOOL insert - whether or not objects should be inserted into the provided context when created, if choose not to insert them you would need to insert them manually ( including relationships ) before they can be saved
 */
- (id)copyUsingContext:(NSManagedObjectContext *)pContext insert:(BOOL)pInsert;

/*
 * Makes a copy of an NSManagedObject - this is a deep copy and does traverse relationships ( including circular )
 * @param NSManagedObjectContext *context - required - provided context is used to obtain NSEntityDescriptions from.
 * @param BOOL insert - whether or not objects should be inserted into the provided context when created, if choose not to insert them you would need to insert them manually ( including relationships ) before they can be saved
 */
- (id)copyIncludingRelationshipsUsingContext:(NSManagedObjectContext *)pContext insert:(BOOL)pInsert block:(NSManagedObjectArchivingBlock)block;

@end
