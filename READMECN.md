# MOCloner #

MOCloner 是一个很小的库，旨在实现对 NSManagedObject 的可定制深拷贝。支持 one-to-one、one-to-many、many-to-many 等关系方式。除了忠于原始数据的拷贝方式外，还提供了选择性拷贝、拷贝时生成新值等功能。

## 实现原理 ##

通过 NSAttributeDescription、NSRelationshipDescription 对 NSMangedObject 的属性和关系实现遍历，并通过 userinfo 实现深拷贝参数设置。

## 深拷贝规则 ##

复制 one-to-one、one-to-many 关系下的全部数据。

碰到逆向关系为 to-many 的 Entity，停止该 Enity 下分支的复制，并将新复制的对象添加到该 Entity 中。

![rules](https://raw.githubusercontent.com/fatbobman/MOCloner/master/Images/inverseToMany.png)

## 基础演示 ##

创建上图中 Note 的深拷贝

```swift
let cloneNote = try MOCloner().cloneNSMangedObject(note) as? Note
```

从关系链中间部分向下深拷贝（不拷贝关系链向上的部分）

```swift
// 在 excludedRelationshipNames 中添加忽略的关系名称
let cloneItem = try! MOCloner().cloneNSMangedObject(item, excludedRelationshipNames: ["note"]) as! Item
```

## 自定义 ##

MOCloner 采用在 Xcode 的 Data Model Editor 中对 User Info 添加键值的方式对深拷贝过程进行定制。目前支持如下命令：

* exclude

  该键可以设置在 Attribute 或 Relationship 中。只要出现 exclude 键，无论任何值都将启用排除逻辑。

  设置在 Attribute 的 userinfo 时，深拷贝将不复制原始对象属性的值（要求 Attribute 为 Optional 或已经设置了 Default value）。

  设置在 Relationship 的 userinfo 时，深拷贝将忽略此关系分支下的所有关系和数据。

  为了方便某些不适合在 userinfo 中设置的情况（比如从关系链中间进行深拷贝），也可以将需要排除的关系名称添加到 excludedRelationshipNames 参数中（如基础演示 2）。

![image-20211112200648882](https://raw.githubusercontent.com/fatbobman/MOCloner/master/Images/exclude.png)

* rebuild

  用于在深拷贝时动态生成新的数据。仅用于设置 Attribute。目前支持两个 value : uuid 和 now。

  uuid：类型为 UUID 的 Attribute，在深拷贝时为该属性创建新的 UUID

  now：类型为 Date 的 Attribute，在深拷贝时为该属性创建新的当前日期（Date.now）

![image-20211112201348978](https://raw.githubusercontent.com/fatbobman/MOCloner/master/Images/rebuild.png)

* followParent

  简化版的 Derived。仅用于设置 Attribute。可以指定关系链下层 Entity 的 Attribute 获取上层关系链对应的托管对象实例的指定 Attribute 值（要求两个 Attribute 类型一致）。下图中，Item 的 noteID 将获得 Note 的 id 值。

![image-20211112205856380](https://raw.githubusercontent.com/fatbobman/MOCloner/master/Images/followParent.png)

* withoutParent

  仅搭配 followParent 使用。处理当从关系链中部进行深拷贝时，设置了 followParent 但无法获取 ParentObject 的情况。

  当 withoutParent 为 keep 时，将保持被复制对象的原值

  当 withoutParent 为 blank 时，将不对其设置值（要求该 Attribute 为 Optional 或设有 Default value）

![image-20211112210330127](https://raw.githubusercontent.com/fatbobman/MOCloner/master/Images/withoutParent.png)

如果以上 userinfo 的键名称与你的项目中已经使用的键名称冲突，可以通过自定义 MOClonerUserInfoKeyConfig 重新设置。

```swift
let moConfig = MOCloner.MOClonerUserInfoKeyConfig(
    rebuild: "newRebuild", // new Key Name
    followParent: "followParent",
    withoutParent: "withoutParent",
    exclude: "exclude"
)

let cloneNote = try cloner.cloneNSMangedObject(note,config: moConfig) as! Note
```

## 系统需求 ##

MOCloner 最低需求为 macOS 10.13、iOS 11、tvOS 11、watchOS 4 以上的系统。

## 安装 ##

MOCloner 使用 Swift Package Manager 分发。要在另一个 Swift 包中使用它，请在你的 Package.swift 中将其作为一个依赖项添加。

```swift
let package = Package(
    ...
    dependencies: [
        .package(url: "https://github.com/fatbobman/MOCloner.git", from: "0.1.0")
    ],
    ...
)
```

如果想在应用程序中使用 MOCloner，请使用 Xcode 的 File > Add Packages... 将其添加到你的项目中。

```swift
import MOCloner
```

鉴于 MOCloner 只有几百行代码，可以将代码拷贝到你的项目中直接使用。

## 注意事项 ##

### 在私有上下文中进行 ###

当深拷贝涉及到大量数据时，请在私有上下文中进行操作，避免占用主线程。

最好在深拷贝操作前后使用 NSManagedObjectID 进行数据传递。

### 内存占用 ###

当深拷贝的托管对象牵涉大量的关系数据时，则可能会形成大量的内存占用。在包含二进制类型数据时会尤为明显（比如将大量图片数据保存在 SQLite 中）。可以考虑使用如下的方式控制内存的占用情况：

* 在深拷贝时，将内存占用较高的属性或关系暂时排除。深拷贝后，通过其它的代码再为其逐个添加。
* 深拷贝多个托管对象时，考虑通过 performBackgroundTask 逐个进行。

## 版权与支持 ##

MOCloner 采用 [MIT](https://github.com/fatbobman/MOCloner/blob/main/LICENSE) 协议，你可以自由地在项目中使用它。但请注意，MOCloner 不附带任何官方支持渠道。

Core Data 提供了丰富的功能和选项，开发者可以使用它创建大量不同组合的关系图。MOCloner 只对其中的部分情况做了测试。因此，在开始准备将 MOCloner 用于你的项目之前，强烈建议你花点时间熟悉其实现，并做更多的单元测试，以防遇到任何可能出现的数据错误问题。

如果你发现问题、错误，或者想提出改进建议，请创建 [Issues](https://github.com/fatbobman/MOCloner/issues) 或 [Pull Request](https://github.com/fatbobman/MOCloner/pulls)。
