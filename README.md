# MOCloner #

[中文版说明](READMECN.md)

MOCloner is a tiny library designed to implement a customizable deep copy of NSManagedObject. Support one-to-one, one-to-many, many-to-many. In addition to copying methods loyal to the original data, it also provides functions such as selective copying and generating new values during copying.

## Principle of implementation ##

Iterate over the attributes and relationships of NSMangedObject through NSAttributeDescription, NSRelationshipDescription, and set deep copy parameters through userinfo.

## Deep Copy Rules ##

Copy all data under one-to-one and one-to-many relations.

When encountering an Entity whose reverse relationship is to-many, stop the replication of the branch under that Enity, and add the newly copied object to the Entity.

![rules](https://raw.githubusercontent.com/fatbobman/MOCloner/master/Images/inverseToMany.png)

## Basic Example ##

Create a deep copy of Note in the image above

```swift
let cloneNote = try! MOCloner().clone(object: note) as! Note
```

Deep copy down from the middle part of the relationship chain (do not copy the upward part of the relationship chain)

```swift
// Add the exclude relationship names to the excludedRelationshipNames
let cloneItem = try! MOCloner().clone(object: item, excludedRelationshipNames: ["note"]) as! Item
```

## Customize ##

MOCloner customizes the deep copy process by adding keys to User Info in Xcode's Data Model Editor. The following commands are currently supported:

* exclude

  This key can be set in Attribute or Relationship. As long as the exclude key appears, the exclude logic will be enabled regardless of any value.

  When set in userinfo of Attribute, deep copy will not copy the value of the original object attribute (it is required that Attribute is Optional or the Default value has been set).

  When set in userinfo of Relationship, deep copy will ignore all relationships and data under this relationship branch.

  In order to facilitate certain situations that are not suitable for setting in userinfo (such as deep copying from the middle of the relationship chain), you can also add the name of the relationship that needs to be excluded to the excludedRelationshipNames parameter (such as basic demo 2).

![image-20211112200648882](https://raw.githubusercontent.com/fatbobman/MOCloner/master/Images/exclude.png)

* rebuild

  Used to dynamically generate new data during deep copy. Currently supports two values: uuid and now.

  uuid: Attribute of type UUID, which creates a new UUID for the attribute on deep copy

  now: Attribute of type Date, which creates a new current date (Date.now) for the attribute on deep copy

![image-20211112201348978](https://raw.githubusercontent.com/fatbobman/MOCloner/master/Images/rebuild.png)

* followParent

  A simplified version of Derived, used only for setting Attribute, can specify that the Attribute of the lower-level Entity of the relationship chain gets the value of the specified Attribute of the corresponding managed object instance of the upper-level relationship chain (requiring the same type of both Attributes). In the following figure, the noteID of Item will get the id value of Note.

![image-20211112205856380](https://raw.githubusercontent.com/fatbobman/MOCloner/master/Images/followParent.png)

* withoutParent

  Only used with followParent. Deal with the situation where followParent is set but ParentObject cannot be obtained when deep copying from the middle of the relationship chain.

  When withoutParent is keep, the original value of the copied object will be kept

  When withoutParent is blank, no value will be set for it (the Attribute is required to be Optional or set with a Default value)

![image-20211112210330127](https://raw.githubusercontent.com/fatbobman/MOCloner/master/Images/withoutParent.png)

If the above userinfo key name conflicts with the key name already used in your project, you can reset it by customizing MOClonerUserInfoKeyConfig.

```swift
let moConfig = MOCloner.MOClonerUserInfoKeyConfig(
    rebuild: "newRebuild", // new Key Name
    followParent: "followParent",
    withoutParent: "withoutParent",
    exclude: "exclude"
)

let cloneNote = try cloner.cloneNSMangedObject(note,config: moConfig) as! Note
```

## System requirement ##

The minimum requirement for MOCloner is macOS 10.13, iOS 11, tvOS 11, watchOS 4 and above.

## Installation ##

MOCloner is distributed using the Swift Package Manager. To use it in another Swift package, add it as a dependency in your Package.swift.

```swift
let package = Package(
    ...
    dependencies: [
        .package(url: "https://github.com/fatbobman/MOCloner.git", from: "0.1.0")
    ],
    ...
)
```

If you want to use MOCloner in your application, use Xcode's File > Add Packages... to add it to your project.

```swift
import MOCloner
```

Since MOCloner only has a few hundred lines of code, you can copy the code to your project and use it directly.

## Notes ##

### Deep copy in private context ###

When deep copying involves a large amount of data, please operate in a private context to avoid occupying the main thread.

It is best to use NSManagedObjectID for data transfer before and after the deep copy operation.

### Memory ###

When a deep copy of the managed object involves a large amount of relational data, it may cause a large amount of memory usage. This is especially obvious when it contains binary data (such as storing a large amount of image data in SQLite). You can consider the following methods to control memory usage:

* During deep copy, attributes or relationships with high memory usage are temporarily excluded. After deep copying, add them one by one through other codes.

* When deep copying multiple NSManagedObjects, consider performing them one by one through performBackgroundTask.

## License and support ##

MOCloner uses the [MIT](https://github.com/fatbobman/MOCloner/blob/main/LICENSE) license, and you are free to use it in your projects. Please note, however, that MOCloner does not come with any official support channels.

Core Data provides a rich set of features and options that developers can use to create a large number of different combinations of relationship graphs. MOCloner has only been tested for some of these cases. Therefore, before you start preparing MOCloner for use in your project, it is highly recommended that you take some time to familiarize yourself with its implementation and do more unit testing in case you encounter any possible data error issues.

If you find problems, bugs, or want to suggest improvements, create [Issues](https://github.com/fatbobman/MOCloner/issues) or [Pull Request](https://github.com/fatbobman/MOCloner/pulls).
