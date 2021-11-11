import CoreData
import Foundation

public struct MOCloner {
    public init() {}

    /// 可以定制userInfo的Key，防止冲突
    public struct MOClonerUserInfoKeyConfig {
        public init(rebuild: String = "rebuild",
                    followParent: String = "followParent",
                    strict: String = "strict",
                    exclude: String = "exclude") {
            self.rebuild = rebuild
            self.followParent = followParent
            self.strict = strict
            self.exclude = exclude
        }

        // 添加在Attribut的userinfo中

        /// 表示该属性内容不复制，使用指定rebuild命令生成。
        /// 值目前支持 ：
        ///            uuid 重新生成uuid 要求属性类型为UUID
        ///            now 生成当时的日期 要求属性类型为Date
        var rebuild: String

        /// 改属性不复制，使用parent Entity的指定attribute
        /// 值为Entity的attribute Name，要求类型一致
        var followParent: String

        /// 表示该属性或关系将不被复制
        /// 对于属性来说，要求该属性为optional，或有Default Value
        /// 对于关系来说，要求该关系为optional
        var exclude: String

        /// strict = false 时，在followParent无法获取到对应值的时候，仍可继续执行。
        var strict: String
    }

    public func cloneNSMangedObject(
        _ originalObject: NSManagedObject,
        parentObject: NSManagedObject? = nil,
        excludingRelationShipNames: [String] = [],
        saveBeforeReturn: Bool = true,
        root: Bool = true,
        config: MOClonerUserInfoKeyConfig = MOClonerUserInfoKeyConfig()
    ) throws -> NSManagedObject {
        guard let context = originalObject.managedObjectContext else {
            throw CloneNSManagedObjectError.contextError
        }

        // 新建NSManagedObject
        guard let entityName = originalObject.entity.name else {
            throw CloneNSManagedObjectError.entityNameError
        }
        let cloneObject = NSEntityDescription.insertNewObject(
            forEntityName: entityName,
            into: context
        )

        // 处理 Attributes
        let attributes = originalObject.entity.attributesByName
        for (attributeName, attributeDescription) in attributes {
            var newValue = originalObject.primitiveValue(forKey: attributeName)
            if let userInfo = attributeDescription.userInfo {
                // 检查是否被排除
                if userInfo[config.exclude] != nil {
                    if attributeDescription.isOptional || attributeDescription.defaultValue != nil {
                        continue
                    } else {
                        throw CloneNSManagedObjectError.attributeExcludeError
                    }
                }

                // 检查是否需要rebuild
                if let action = userInfo[config.rebuild] as? String {
                    switch action {
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

                // 检查是否需要followParent
                if let parentAttributeName = userInfo[config.followParent] as? String {
                    if let parentObject = parentObject,
                       let parentAttributeDescription = parentObject.entity.attributesByName[parentAttributeName],
                       parentAttributeDescription.attributeType == attributeDescription.attributeType {
                        newValue = parentObject.primitiveValue(forKey: parentAttributeName)
                    } else {
                        // strict = false 是，运行跳过followParent，保留原值
                        guard let strict = userInfo[config.strict] as? String, strict == "false" else {
                            throw CloneNSManagedObjectError.followParentError
                        }
                    }
                }
            }

            cloneObject.setPrimitiveValue(newValue, forKey: attributeName)
        }

        // 处理 relationship
        let relationships = originalObject.entity.relationshipsByName

        for (relationshipName, relationshipDescription) in relationships {
            // 处理 exclude
            if excludingRelationShipNames.contains(relationshipName) {
                continue
            }

            if let userInfo = relationshipDescription.userInfo,
               userInfo[config.exclude] != nil {
                continue
            }

            // 不处理 Parent Relationship, inverseEntity为另一侧的Entity
            if let parentObject = parentObject,
               let inverseEntity = relationshipDescription.inverseRelationship?.entity,
               inverseEntity == parentObject.entity {
                continue
            }

            // 关系的另一侧是ToMany，不复制对侧，将oriangelObject添加到对侧的关系中
            if let inverseRelDesc = relationshipDescription.inverseRelationship, inverseRelDesc.isToMany {
                // 关系本侧为 ToOne
                if !relationshipDescription.isToMany,
                   let origainlToOneObject = originalObject.primitiveValue(forKey: relationshipName) {
                    // 将对侧关系的Entity实例直接添加给cloneObject
                    // 设置关系不可以设置原始值
                    cloneObject.setValue(origainlToOneObject, forKey: relationshipName)
                } else {
                    // ToMany
                    let originalToManyObjects = originalObject.primitiveValue(forKey: relationshipName)
                    cloneObject.setValue(originalToManyObjects, forKey: relationshipName)
                }
                continue
            }

            // 关系的另一侧是ToOne
            // ToOne
            if !relationshipDescription.isToMany,
               let originalToOneObject = originalObject.primitiveValue(forKey: relationshipName) as? NSManagedObject {
                let newToOneObject = try cloneNSMangedObject(
                    originalToOneObject,
                    parentObject: nil,
                    excludingRelationShipNames: [],
                    saveBeforeReturn: false,
                    root: false,
                    config: config
                )
                cloneObject.setPrimitiveValue(newToOneObject, forKey: relationshipName)
            } else {
                // ToMany
                var newToManyObjects = [NSManagedObject]()
                // clone 对侧的所有托管对象
                if relationshipDescription.isOrdered {
                    if let originalToManyObjects = (originalObject.primitiveValue(forKey: relationshipName) as? NSOrderedSet) {
                        for needToCloneObject in originalToManyObjects {
                            if let object = needToCloneObject as? NSManagedObject {
                                let newObject = try cloneNSMangedObject(
                                    object,
                                    parentObject: originalObject,
                                    excludingRelationShipNames: [],
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
                                    excludingRelationShipNames: [],
                                    saveBeforeReturn: false,
                                    root: false,
                                    config: config
                                )
                                newToManyObjects.append(newObject)
                            }
                        }
                    }
                }

                // 将clone后的对侧对象序列赋值给cloneObject
                if !newToManyObjects.isEmpty {
                    if relationshipDescription.isOrdered {
                        let objects = NSOrderedSet(array: newToManyObjects)
                        cloneObject.setPrimitiveValue(objects, forKey: relationshipName)
                    } else {
                        let objects = NSSet(array: newToManyObjects)
                        cloneObject.setPrimitiveValue(objects, forKey: relationshipName)
                    }
                }
            }
        }

        // 持久化
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
