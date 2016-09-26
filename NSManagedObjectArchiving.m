#import "NSManagedObjectArchiving.h"

#if TARGET_OS_IPHONE
#import <objc/runtime.h>
#endif

@interface NSObject (LM_AttributeKeys)

@property (nonatomic, copy, readonly) NSArray<NSString*>* LM_attributeKeys;

@end

@interface NSManagedObjectArchiver()

@property (nonatomic, strong) NSMutableDictionary *objects;
@property (nonatomic, strong) NSString *rootObjectIdentifier;

- (id)identifierForObject:(NSManagedObject *)pObject;
- (id)propertyListForObject:(NSManagedObject *)pObject block:(NSManagedObjectArchivingBlock)block;
- (id)propertyListForRelationshipWithName:(NSString *)pRelationshipName inObject:(NSManagedObject *)pObject block:(NSManagedObjectArchivingBlock)block;

@end

@implementation NSManagedObjectArchiver

#pragma mark - Properties

@synthesize objects;
@synthesize rootObjectIdentifier;

#pragma mark - Initialization

+ (NSData *)archivedDataWithRootObject:(NSManagedObject *)pObject
{
	return [self archivedDataWithRootObject:pObject block:NULL];
}

+ (NSData *)archivedDataWithRootObject:(NSManagedObject *)pRootObject block:(NSManagedObjectArchivingBlock)block {
	NSManagedObjectArchiver *archiver = [[self alloc] init];
	archiver.rootObjectIdentifier = [archiver identifierForObject:pRootObject];
	[archiver propertyListForObject:pRootObject block:block];
	return [NSKeyedArchiver archivedDataWithRootObject:[NSDictionary dictionaryWithObjectsAndKeys:
														archiver.objects, @"objects",
														archiver.rootObjectIdentifier, @"rootObjectIdentifier",
														nil]];
}
- (id)init {
	if((self = [super init])) {
		objects = [NSMutableDictionary dictionary];
	}
	return self;
}

#pragma mark - Actions

- (id)identifierForObject:(NSManagedObject *)pObject {
	if(pObject == nil) {
		return [NSNull null];
	}
	return pObject.objectID.URIRepresentation.absoluteString;
}
- (id)propertyListForObject:(NSManagedObject *)pObject block:(NSManagedObjectArchivingBlock)block {
	if(pObject == nil) {
		return [NSNull null];
	}
	NSString *identifier = [self identifierForObject:pObject];
	id existingPropertyList = [self.objects objectForKey:identifier];
	if(existingPropertyList != nil) {
		return existingPropertyList;
	}
	NSEntityDescription *entityDescription = pObject.entity;
	
	NSMutableDictionary *propertyList = [NSMutableDictionary dictionary];
	[propertyList setObject:entityDescription.name forKey:@"entityName"];
	[propertyList setObject:entityDescription.versionHash forKey:@"entityVersionHash"];
	[propertyList setObject:identifier forKey:@"identifier"];
	
	NSDictionary* attributesOriginal = [pObject dictionaryWithValuesForKeys:entityDescription.LM_attributeKeys];
	NSMutableDictionary* attributes = [NSMutableDictionary dictionaryWithCapacity:[attributesOriginal count]];
	[attributesOriginal enumerateKeysAndObjectsUsingBlock:^(id key, id obj, BOOL *stop) {
		if (!block || block(pObject, key)) {
			[attributes setObject:obj forKey:key];
		}
	}];
	[propertyList setObject:attributes forKey:@"attributes"];
	
	[self.objects setObject:propertyList forKey:identifier];
	
	NSMutableDictionary *propertyListRelationships = [NSMutableDictionary dictionary];
	[propertyList setObject:propertyListRelationships forKey:@"relationships"];
	
	for(NSString *relationshipName in entityDescription.relationshipsByName) {
		if (!block || block(pObject, relationshipName)) {
			[propertyListRelationships setObject:[self propertyListForRelationshipWithName:relationshipName inObject:pObject block:block]
										  forKey:relationshipName];
		}
	}
	
	return propertyList;
}
- (id)propertyListForRelationshipWithName:(NSString *)pRelationshipName inObject:(NSManagedObject *)pObject block:(NSManagedObjectArchivingBlock)block {
	NSRelationshipDescription *relationshipDescription = [pObject.entity.relationshipsByName objectForKey:pRelationshipName];
	
	if(relationshipDescription.isToMany) {
		id src = [pObject valueForKey:pRelationshipName];
		id dst = nil;
		if(relationshipDescription.isOrdered) {
			dst = [NSMutableOrderedSet orderedSet];
		} else {
			dst = [NSMutableSet set];
		}
		for(NSManagedObject *object in src) {
			NSString *identifier = [self identifierForObject:object];
			[self propertyListForObject:object block:block];
			[dst addObject:identifier];
		}
		return ([dst count] > 0) ? dst : [NSNull null];
	} else {
		NSString *identifier = [self identifierForObject:[pObject valueForKey:pRelationshipName]];
		[self propertyListForObject:[pObject valueForKey:pRelationshipName] block:block];
		return identifier;
	}
}

@end


@interface NSManagedObjectUnarchiver()

@property (nonatomic, strong) NSManagedObjectContext *context;
@property (nonatomic, assign) BOOL insert;
@property (nonatomic, strong) NSMutableDictionary *entities;
@property (nonatomic, strong) NSDictionary *archivedObjects;
@property (nonatomic, strong) NSMutableDictionary *unarchivedObjects;

- (NSManagedObject *)objectForIdentifier:(NSString *)pIdentifier;
- (id)objectsForIdentifiers:(id)pIdentifiers;

@end
@implementation NSManagedObjectUnarchiver

#pragma mark - Properties

@synthesize context;
@synthesize insert;
@synthesize entities;
@synthesize archivedObjects;
@synthesize unarchivedObjects;

#pragma mark - Initialization

+ (NSManagedObject *)unarchiveObjectWithData:(NSData *)pData context:(NSManagedObjectContext *)pContext insert:(BOOL)pInsert {
	NSManagedObjectUnarchiver *unarchiver = [[NSManagedObjectUnarchiver alloc] init];
	NSDictionary *dictionary = [NSKeyedUnarchiver unarchiveObjectWithData:pData];
	if(dictionary != nil && [dictionary isKindOfClass:[NSDictionary class]]) {
		unarchiver.context = pContext;
		unarchiver.insert = pInsert;
		unarchiver.archivedObjects = [dictionary objectForKey:@"objects"];
		return [unarchiver objectForIdentifier:[dictionary objectForKey:@"rootObjectIdentifier"]];
	}
	return nil;
}
- (id)init {
	if((self = [super init])) {
		unarchivedObjects = [NSMutableDictionary dictionary];
	}
	return self;
}

#pragma mark - Actions

- (NSManagedObject *)objectForIdentifier:(NSString *)pIdentifier {
	if(pIdentifier == nil || ![pIdentifier isKindOfClass:[NSString class]]) {
		return nil;
	}
	NSManagedObject *unarchivedObject = [self.unarchivedObjects objectForKey:pIdentifier];
	if(unarchivedObject != nil) {
		return unarchivedObject;
	}
	
	NSDictionary *archivedObject = [self.archivedObjects objectForKey:pIdentifier];
	NSEntityDescription *entityDescription = [NSEntityDescription entityForName:[archivedObject objectForKey:@"entityName"] inManagedObjectContext:self.context];
	if(![entityDescription.versionHash isEqualToData:[archivedObject objectForKey:@"entityVersionHash"]]) {
		[NSException raise:@"Invalid archived data" format:@"Mismatching version hashes, archived managed object's entity version hash differs from version hash in the provided context."];
		return nil;
	}
	
	
	Class entityClass = NSClassFromString([entityDescription managedObjectClassName]);
	if(entityClass == nil) {
		[NSException raise:@"Invalid archived data" format:@"Cannot find custom class with name %@ for managed object with entity name %@", entityDescription.managedObjectClassName, entityDescription.name];
		return nil;
	}
	
	NSManagedObject *object = [[entityClass alloc] initWithEntity:entityDescription insertIntoManagedObjectContext:(self.insert) ? self.context : nil];
	[object setValuesForKeysWithDictionary:[archivedObject objectForKey:@"attributes"]];
	
	[self.unarchivedObjects setObject:object forKey:pIdentifier];
	
	NSDictionary *relationships = [archivedObject objectForKey:@"relationships"];
	for(NSString *relationshipName in relationships) {
		id relationshipValue = [relationships objectForKey:relationshipName];
		if([relationshipValue isKindOfClass:[NSString class]]) {
			relationshipValue = [self objectForIdentifier:relationshipValue];
		} else if([relationshipValue isKindOfClass:[NSOrderedSet class]] ||
				  [relationshipValue isKindOfClass:[NSSet class]]) {
			relationshipValue = [self objectsForIdentifiers:relationshipValue];
		} else if([relationshipValue isKindOfClass:[NSNull class]]) {
			relationshipValue = nil;
		}
		[object setValue:relationshipValue forKey:relationshipName];
	}
	
	return object;
}
- (id)objectsForIdentifiers:(id)pIdentifiers {
	if(pIdentifiers == nil) {
		return nil;
	}
	id collection = nil;
	if([pIdentifiers isKindOfClass:[NSOrderedSet class]]) {
		collection = [NSMutableOrderedSet orderedSetWithCapacity:[pIdentifiers count]];
	} else if([pIdentifiers isKindOfClass:[NSSet class]]) {
		collection = [NSMutableSet setWithCapacity:[pIdentifiers count]];
	} else {
		return nil;
	}
	for(id identifier in pIdentifiers) {
		NSManagedObject *object = [self objectForIdentifier:identifier];
		if(object != nil) {
			[collection addObject:object];
		}
	}
	return ([collection count] > 0) ? collection : nil;
}

@end

@implementation NSManagedObject (NSManagedObjectCopying)

- (id)copyUsingContext:(NSManagedObjectContext *)pContext insert:(BOOL)pInsert {
	NSEntityDescription *entity = [NSEntityDescription entityForName:self.entity.name inManagedObjectContext:pContext];
	Class entityClass = NSClassFromString(entity.managedObjectClassName);
	NSManagedObject *copy = [[entityClass alloc] initWithEntity:entity insertIntoManagedObjectContext:((pInsert) ? pContext : nil)];
	[copy setValuesForKeysWithDictionary:[self dictionaryWithValuesForKeys:self.entity.LM_attributeKeys]];
	return copy;
}
- (id)copyIncludingRelationshipsUsingContext:(NSManagedObjectContext *)pContext insert:(BOOL)pInsert block:(NSManagedObjectArchivingBlock)block {
	NSData *d = [NSManagedObjectArchiver archivedDataWithRootObject:self block:block];
	return [NSManagedObjectUnarchiver unarchiveObjectWithData:d context:pContext insert:pInsert];
}

@end

#pragma mark - LM_AttributeKeys

@implementation NSObject (LM_AttributeKeys)

#if TARGET_OS_OSX
- (NSArray<NSString *> *)LM_attributeKeys
{
    return self.attributeKeys;
}
#elif TARGET_OS_IPHONE
- (NSArray<NSString *> *)LM_attributeKeys
{
    unsigned count;
    objc_property_t *properties = class_copyPropertyList([self class], &count);
    NSMutableArray *rv = [NSMutableArray array];
    unsigned i;
    for (i = 0; i < count; i++) {
        objc_property_t property = properties[i];
        NSString *name = [NSString stringWithUTF8String:property_getName(property)];
        [rv addObject:name];
    }
    free(properties);
    return [rv copy];
}
#endif

@end
