//
//  MOClone.swift
//  MOCloner
//
//  Created by Yang Xu on 2021/11/11
//  Copyright © 2021 Yang Xu. All rights reserved.
//
//  Follow me on Twitter: @fatbobman
//  My Blog: https://www.fatbobman.com
//  微信公共号: 肘子的Swift记事本
//

import CoreData
import Foundation

/// MOCloner can help to implement deep copy of NSManagedObject.
/// By adding flags to the userinfo of Attribute or Relationships in the Data Model Editor, MOCloner provides partial control during deep copy.
/// For objects with complex relationships, it is better to create a private context for the clone operation
public struct MOCloner {
    public init() {}

    /// To prevent conflicts with your previously used Key  in userinfo, you can customize the Key name by MOClonerUserInfoKeyConfig.
    public struct MOClonerUserInfoKeyConfig {
        public init(rebuild: String = "rebuild",
                    followParent: String = "followParent",
                    withoutParent: String = "withoutParent",
                    exclude: String = "exclude") {
            self.rebuild = rebuild
            self.followParent = followParent
            self.withoutParent = withoutParent
            self.exclude = exclude
        }

        /// Don't copy the original value , rebuild a new value for attribute
        var rebuild: String

        /// Using parentObject-specific property values in a relational chain
        var followParent: String

        /// All data under the tagged attribute or relationship will be ignored when clone
        var exclude: String

        /// If withoutParent is "keep" or "blank", the execution will continue if followParent cannot get the corresponding value.
        var withoutParent: String
    }

    /// cloneNSMangedObject Initialization
    ///
    /// example:
    ///
    ///         let cloner = MOCloner()
    ///         let cloneNote = try cloner.cloneNSMangedObject(note) as? Note
    ///
    /// - Parameters:
    ///   - originalObject: Cloned objects
    ///   - parentObject: For use inside methods, keep it in nil
    ///   - excludingRelationShipNames: You can set the name of the relationship to be ignored by the root object during the clone process
    ///   - passingExclusionList: Whether to pass the exclusion list along the relationship chain,It must be ensured that the ignored relationship name is unique throughout the relationship chain. Otherwise it is better to set the exclude in the userinfo of the relationship
    ///   - saveBeforeReturn: Whether to complete persistence before returning the cloned object
    ///   - root: For use inside methods, keep it in tru
    ///   - config: MOCloner
    /// - Returns: If you need to customize the name of the Key in userinfo, you can create your own MOClonerUserInfoKeyConfig
    public func cloneNSMangedObject(
        _ originalObject: NSManagedObject,
        parentObject: NSManagedObject? = nil,
        excludedRelationshipNames: [String] = [],
        passingExclusionList: Bool = false,
        saveBeforeReturn: Bool = true,
        root: Bool = true,
        config: MOClonerUserInfoKeyConfig = MOClonerUserInfoKeyConfig()
    ) throws -> NSManagedObject {
        guard let context = originalObject.managedObjectContext else {
            throw CloneNSManagedObjectError.contextError
        }

        // create clone NSManagedObject
        guard let entityName = originalObject.entity.name else {
            throw CloneNSManagedObjectError.entityNameError
        }
        let cloneObject = NSEntityDescription.insertNewObject(
            forEntityName: entityName,
            into: context
        )

        // MARK: - Attributes

        let attributes = originalObject.entity.attributesByName
        for (attributeName, attributeDescription) in attributes {
            var skip = false
            var newValue = originalObject.primitiveValue(forKey: attributeName)
            if let userInfo = attributeDescription.userInfo {
                // Check if the "exclude" flag is added to this attribute
                // Only detemine whether the Key is "exclude" or note, do not care about the Vlaue
                if userInfo[config.exclude] != nil {
                    if attributeDescription.isOptional || attributeDescription.defaultValue != nil {
                        continue
                    } else {
                        throw CloneNSManagedObjectError.attributeExcludeError
                    }
                }

                // check if the attribute need to "rebuild" , for example: "rebuild:uuid"
                // "uuid"  -> make a new UUID
                // "now"   -> Date.now
                if let action = userInfo[config.rebuild] as? String {
                    switch action.lowercased() {
                    case "uuid":
                        if attributeDescription.attributeType == NSAttributeType.UUIDAttributeType {
                            newValue = UUID()
                        } else {
                            throw CloneNSManagedObjectError.uuidTypeError
                        }
                    case "now":
                        if attributeDescription.attributeType == NSAttributeType.dateAttributeType {
                            newValue = Date()
                        } else {
                            throw CloneNSManagedObjectError.dateTypeError
                        }
                    default:
                        break
                    }
                }

                // Check if the "followParent" flag is added to thie attribut
                // Value is the name of the attribute of the object at the upper end of the corresponding
                // relationship chain. The corresponding attribute type need to be excactly the same.
                // For example, for the attribute "noteID", set flag "followParent:id"
                // then the "noteID" will get the value of the proerty of the object on the corresponding relationship
                // chain when it is clone.
                if let parentAttributeName = userInfo[config.followParent] as? String {
                    if let parentObject = parentObject,
                       let parentAttributeDescription = parentObject.entity.attributesByName[parentAttributeName],
                       parentAttributeDescription.attributeType == attributeDescription.attributeType {
                        newValue = parentObject.primitiveValue(forKey: parentAttributeName)
                    } else {
                        /*
                         in some cases, the user may clone object starting from the middle of a complete chain
                         of relations. The original "followParent" flag can be ignored by setting "withoutParent" to "keep" or "blank"
                         */
                        if let withoutParent = userInfo[config.withoutParent] as? String {
                            switch withoutParent.lowercased() {
                            case "keep": // keep the original value
                                break
                            case "blank": // use optional or default value
                                guard attributeDescription.isOptional || attributeDescription.defaultValue != nil else {
                                    throw CloneNSManagedObjectError.followParentError
                                }
                                skip = true
                            default:
                                throw CloneNSManagedObjectError.followParentError
                            }
                        } else {
                            throw CloneNSManagedObjectError.followParentError
                        }
                    }
                }
            }

            if !skip {
                cloneObject.setPrimitiveValue(newValue, forKey: attributeName)
            }
        }

        // MARK: - Relationships

        let relationships = originalObject.entity.relationshipsByName

        for (relationshipName, relationshipDescription) in relationships {
            // In some cases, the user does note need to set "exclude" in relationship userinfo,
            // but adds the relations to be ignored in the "excludingRelationShipName" pareameter of this method.
            // Use the passingExclusionList to set whether to pass down the exclusion list
            if excludedRelationshipNames.contains(relationshipName) {
                continue
            }

            // You can set "exclude" in the userinfo of a relationship to compltely ignore
            // the data in a relationship chain when clone
            if let userInfo = relationshipDescription.userInfo,
               userInfo[config.exclude] != nil {
                continue
            }

            // Ignore the relationship between the incoming direction
            if let parentObject = parentObject,
               let inverseEntity = relationshipDescription.inverseRelationship?.entity,
               inverseEntity == parentObject.entity {
                continue
            }

            // MARK: inverse relationship is To-Many

            // When To-Many is below the relationship chain, the data below is not cloned.
            // only the new object of the cureent clone is added to the objects below the relationship chain
            if let inverseRelDesc = relationshipDescription.inverseRelationship, inverseRelDesc.isToMany {
                let relationshipObjects = originalObject.primitiveValue(forKey: relationshipName)
                cloneObject.setValue(relationshipObjects, forKey: relationshipName)
                continue
            }

            // inverse relationship is To-One

            // TO-One
            if !relationshipDescription.isToMany,
               let originalToOneObject = originalObject.primitiveValue(forKey: relationshipName) as? NSManagedObject {
                let newToOneObject = try cloneNSMangedObject(
                    originalToOneObject,
                    parentObject: nil,
                    excludedRelationshipNames: passingExclusionList ? excludedRelationshipNames : [],
                    saveBeforeReturn: false,
                    root: false,
                    config: config
                )
                cloneObject.setValue(newToOneObject, forKey: relationshipName)
            } else {
                // ToMany
                var newToManyObjects = [NSManagedObject]()
                // check whether the relationship is be marked ordered. NSOrderSet
                if relationshipDescription.isOrdered {
                    if let originalToManyObjects = (originalObject.primitiveValue(forKey: relationshipName) as? NSOrderedSet) {
                        for needToCloneObject in originalToManyObjects {
                            if let object = needToCloneObject as? NSManagedObject {
                                let newObject = try cloneNSMangedObject(
                                    object,
                                    parentObject: originalObject,
                                    excludedRelationshipNames: passingExclusionList ? excludedRelationshipNames : [],
                                    saveBeforeReturn: false,
                                    root: false,
                                    config: config
                                )
                                newToManyObjects.append(newObject)
                            }
                        }
                    }
                } else {
                    if let originalToManyObjects = (originalObject.primitiveValue(forKey: relationshipName) as? NSSet) {
                        for needToCloneObject in originalToManyObjects {
                            if let object = needToCloneObject as? NSManagedObject {
                                let newObject = try cloneNSMangedObject(
                                    object,
                                    parentObject: originalObject,
                                    excludedRelationshipNames: passingExclusionList ? excludedRelationshipNames : [],
                                    saveBeforeReturn: false,
                                    root: false,
                                    config: config
                                )
                                newToManyObjects.append(newObject)
                            }
                        }
                    }
                }

                if !newToManyObjects.isEmpty {
                    if relationshipDescription.isOrdered {
                        let objects = NSOrderedSet(array: newToManyObjects)
                        cloneObject.setValue(objects, forKey: relationshipName)
                    } else {
                        let objects = NSSet(array: newToManyObjects)
                        cloneObject.setValue(objects, forKey: relationshipName)
                    }
                }
            }
        }

        // persistent
        if root, saveBeforeReturn, context.hasChanges {
            try context.save()
        }

        return cloneObject
    }

    public enum CloneNSManagedObjectError: Error {
        case contextError
        case entityNameError
        case uuidTypeError
        case dateTypeError
        case attributeExcludeError
        case followParentError
    }
}

extension NSManagedObject {
    static var name: String {
        entity().name ?? ""
    }
}
